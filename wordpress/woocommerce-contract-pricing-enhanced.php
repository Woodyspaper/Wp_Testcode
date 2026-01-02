<?php
/**
 * Plugin Name: WooCommerce Contract Pricing (Enhanced)
 * Description: Applies NCR contract pricing from CounterPoint to WooCommerce products
 * Version: 2.0.0
 * Author: Woody's Paper Integration
 * 
 * ENHANCEMENTS:
 * - WordPress-side caching (transients) to reduce API calls
 * - Batch pricing support for cart items
 * - Better error handling and fallback
 * - Admin settings for API key and cache TTL
 */

if (!defined('ABSPATH')) {
    exit;
}

// Cache TTL (5 minutes default)
define('WP_CONTRACT_PRICING_CACHE_TTL', 300);

/**
 * Get customer's NCR BID # from user meta
 * 
 * @param int $user_id WordPress user ID
 * @return string|null NCR BID # or null if not found
 */
function wp_get_customer_ncr_bid($user_id) {
    return get_user_meta($user_id, 'ncr_bid_no', true);
}

/**
 * Get contract price with WordPress caching
 */
function wp_get_contract_price_cached($ncr_bid_no, $item_no, $quantity = 1.0) {
    // Generate cache key
    $cache_key = 'wp_contract_price_' . md5($ncr_bid_no . ':' . $item_no . ':' . $quantity);
    
    // Try cache first (valid cache)
    $cached = get_transient($cache_key);
    if ($cached !== false) {
        return $cached;
    }
    
    // Cache miss - call API
    $api_url = get_option('wp_contract_pricing_api_url', 'http://localhost:5000/api/contract-price');
    $api_key = get_option('wp_contract_pricing_api_key', '');
    
    $response = wp_remote_post($api_url, array(
        'body' => json_encode(array(
            'ncr_bid_no' => $ncr_bid_no,
            'item_no' => $item_no,
            'quantity' => $quantity
        )),
        'headers' => array(
            'Content-Type' => 'application/json',
            'X-API-Key' => $api_key
        ),
        'timeout' => 5
    ));
    
    if (is_wp_error($response)) {
        error_log('Contract pricing API error: ' . $response->get_error_message());
        
        // FAILOVER: Try expired cache (within last hour) as fallback
        $expired_cache_key = '_transient_' . $cache_key;
        $expired_timeout_key = '_transient_timeout_' . $cache_key;
        $expired_timeout = get_option($expired_timeout_key);
        
        if ($expired_timeout && (time() - $expired_timeout) < 3600) {
            // Use expired cache if less than 1 hour old
            $expired_data = get_option($expired_cache_key);
            if ($expired_data) {
                error_log('Contract pricing: Using expired cache as fallback (API unavailable)');
                return $expired_data;
            }
        }
        
        return null;  // No cache available, fall back to regular price
    }
    
    $body = wp_remote_retrieve_body($response);
    $data = json_decode($body, true);
    
    if ($data && isset($data['contract_price'])) {
        // Cache the result
        $cache_ttl = get_option('wp_contract_pricing_cache_ttl', WP_CONTRACT_PRICING_CACHE_TTL);
        set_transient($cache_key, $data, $cache_ttl);
        return $data;
    }
    
    return null;
}

/**
 * Get batch contract prices (for cart)
 */
function wp_get_contract_prices_batch($ncr_bid_no, $items) {
    $api_url = get_option('wp_contract_pricing_api_url', 'http://localhost:5000/api/contract-price');
    $api_key = get_option('wp_contract_pricing_api_key', '');
    
    // Prepare items array
    $items_array = array();
    foreach ($items as $item) {
        $items_array[] = array(
            'item_no' => $item['sku'],
            'quantity' => $item['quantity']
        );
    }
    
    $response = wp_remote_post($api_url . 's', array( // Note: /api/contract-prices (plural)
        'body' => json_encode(array(
            'ncr_bid_no' => $ncr_bid_no,
            'items' => $items_array
        )),
        'headers' => array(
            'Content-Type' => 'application/json',
            'X-API-Key' => $api_key
        ),
        'timeout' => 10  // Longer timeout for batch
    ));
    
    if (is_wp_error($response)) {
        error_log('Contract pricing batch API error: ' . $response->get_error_message());
        
        // FAILOVER: Try to get individual prices from expired cache
        $fallback_results = array();
        foreach ($items as $item_key => $item) {
            $cache_key = 'wp_contract_price_' . md5($ncr_bid_no . ':' . $item['sku'] . ':' . $item['quantity']);
            $expired_timeout_key = '_transient_timeout_' . $cache_key;
            $expired_timeout = get_option($expired_timeout_key);
            
            if ($expired_timeout && (time() - $expired_timeout) < 3600) {
                // Use expired cache if less than 1 hour old
                $expired_data = get_option('_transient_' . $cache_key);
                if ($expired_data) {
                    $fallback_results[] = $expired_data;
                }
            }
        }
        
        if (!empty($fallback_results)) {
            error_log('Contract pricing batch: Using expired cache as fallback (API unavailable)');
            return $fallback_results;
        }
        
        return array();  // No cache available, fall back to regular prices
    }
    
    $body = wp_remote_retrieve_body($response);
    $data = json_decode($body, true);
    
    if ($data && isset($data['results'])) {
        // Cache individual results
        $cache_ttl = get_option('wp_contract_pricing_cache_ttl', WP_CONTRACT_PRICING_CACHE_TTL);
        foreach ($data['results'] as $result) {
            $cache_key = 'wp_contract_price_' . md5($ncr_bid_no . ':' . $result['item_no'] . ':' . $result['quantity']);
            set_transient($cache_key, $result, $cache_ttl);
        }
        return $data['results'];
    }
    
    return array();
}

/**
 * Apply contract pricing to product price
 * 
 * Hook: woocommerce_product_get_price
 * Priority: 20 (after tier pricing, before regular price)
 */
function wp_apply_contract_pricing($price, $product) {
    // Skip for guests
    if (!is_user_logged_in()) {
        return $price;
    }
    
    // Skip in admin (unless needed)
    if (is_admin() && !wp_doing_ajax()) {
        return $price;
    }
    
    $user_id = get_current_user_id();
    $ncr_bid = wp_get_customer_ncr_bid($user_id);
    
    if (!$ncr_bid) {
        return $price;
    }
    
    $sku = $product->get_sku();
    if (!$sku) {
        return $price;
    }
    
    // Get quantity from cart if available
    $quantity = 1.0;
    if (WC()->cart) {
        foreach (WC()->cart->get_cart() as $cart_item) {
            if ($cart_item['product_id'] == $product->get_id()) {
                $quantity = $cart_item['quantity'];
                break;
            }
        }
    }
    
    // Get contract price (with caching)
    $contract_data = wp_get_contract_price_cached($ncr_bid, $sku, $quantity);
    
    if ($contract_data && isset($contract_data['contract_price'])) {
        return floatval($contract_data['contract_price']);
    }
    
    return $price;
}
add_filter('woocommerce_product_get_price', 'wp_apply_contract_pricing', 20, 2);
add_filter('woocommerce_product_get_regular_price', 'wp_apply_contract_pricing', 20, 2);

/**
 * Apply contract pricing to cart items (batch)
 */
function wp_apply_contract_pricing_cart() {
    if (!is_user_logged_in() || !WC()->cart) {
        return;
    }
    
    $user_id = get_current_user_id();
    $ncr_bid = wp_get_customer_ncr_bid($user_id);
    
    if (!$ncr_bid) {
        return;
    }
    
    // Prepare items for batch request
    $items = array();
    foreach (WC()->cart->get_cart() as $cart_item_key => $cart_item) {
        $product = $cart_item['data'];
        $sku = $product->get_sku();
        if ($sku) {
            $items[$cart_item_key] = array(
                'sku' => $sku,
                'quantity' => $cart_item['quantity']
            );
        }
    }
    
    if (empty($items)) {
        return;
    }
    
    // Get batch prices
    $prices = wp_get_contract_prices_batch($ncr_bid, $items);
    
    // Apply prices to cart items
    foreach ($prices as $price_data) {
        foreach (WC()->cart->get_cart() as $cart_item_key => $cart_item) {
            if ($cart_item['data']->get_sku() == $price_data['item_no']) {
                $cart_item['data']->set_price($price_data['contract_price']);
                break;
            }
        }
    }
}
add_action('woocommerce_before_calculate_totals', 'wp_apply_contract_pricing_cart', 10);

/**
 * Recalculate on quantity change
 */
function wp_recalculate_contract_pricing_on_quantity_change($cart_item_key, $quantity, $old_quantity) {
    // Clear cache for this item
    if (!is_user_logged_in()) {
        return;
    }
    
    $user_id = get_current_user_id();
    $ncr_bid = wp_get_customer_ncr_bid($user_id);
    
    if (!$ncr_bid) {
        return;
    }
    
    $cart = WC()->cart;
    $cart_item = $cart->get_cart_item($cart_item_key);
    
    if (!$cart_item) {
        return;
    }
    
    $product = $cart_item['data'];
    $sku = $product->get_sku();
    
    if (!$sku) {
        return;
    }
    
    // Clear cache for old quantity
    $old_cache_key = 'wp_contract_price_' . md5($ncr_bid . ':' . $sku . ':' . $old_quantity);
    delete_transient($old_cache_key);
    
    // Get new price (will cache automatically)
    $contract_data = wp_get_contract_price_cached($ncr_bid, $sku, $quantity);
    
    if ($contract_data && isset($contract_data['contract_price'])) {
        $product->set_price($contract_data['contract_price']);
    }
}
add_action('woocommerce_after_cart_item_quantity_update', 'wp_recalculate_contract_pricing_on_quantity_change', 10, 3);

/**
 * Display contract pricing info
 */
function wp_display_contract_pricing_info() {
    if (!is_user_logged_in()) {
        return;
    }
    
    global $product;
    $user_id = get_current_user_id();
    $ncr_bid = wp_get_customer_ncr_bid($user_id);
    
    if (!$ncr_bid) {
        return;
    }
    
    $sku = $product->get_sku();
    if (!$sku) {
        return;
    }
    
    $contract_data = wp_get_contract_price_cached($ncr_bid, $sku, 1.0);
    
    if ($contract_data && isset($contract_data['contract_price'])) {
        $regular_price = $contract_data['regular_price'];
        $contract_price = $contract_data['contract_price'];
        $discount_pct = $contract_data['discount_pct'];
        
        echo '<div class="contract-pricing-info" style="margin-top: 10px; padding: 10px; background: #f0f0f0; border-radius: 4px;">';
        echo '<strong>Contract Pricing Applied</strong><br>';
        echo '<span style="text-decoration: line-through;">Regular: ' . wc_price($regular_price) . '</span> ';
        echo '<span style="color: green; font-weight: bold;">Your Price: ' . wc_price($contract_price) . '</span>';
        if ($discount_pct) {
            echo '<br><small>Discount: ' . number_format($discount_pct, 2) . '%</small>';
        }
        echo '</div>';
    }
}
add_action('woocommerce_single_product_summary', 'wp_display_contract_pricing_info', 25);

/**
 * Admin settings page
 */
function wp_contract_pricing_settings_page() {
    add_options_page(
        'Contract Pricing Settings',
        'Contract Pricing',
        'manage_options',
        'wp-contract-pricing',
        'wp_contract_pricing_settings_html'
    );
}
add_action('admin_menu', 'wp_contract_pricing_settings_page');

function wp_contract_pricing_settings_html() {
    if (!current_user_can('manage_options')) {
        return;
    }
    
    if (isset($_POST['submit'])) {
        update_option('wp_contract_pricing_api_url', sanitize_text_field($_POST['api_url']));
        update_option('wp_contract_pricing_api_key', sanitize_text_field($_POST['api_key']));
        update_option('wp_contract_pricing_cache_ttl', intval($_POST['cache_ttl']));
        echo '<div class="notice notice-success"><p>Settings saved!</p></div>';
    }
    
    $api_url = get_option('wp_contract_pricing_api_url', 'http://localhost:5000/api/contract-price');
    $api_key = get_option('wp_contract_pricing_api_key', '');
    $cache_ttl = get_option('wp_contract_pricing_cache_ttl', WP_CONTRACT_PRICING_CACHE_TTL);
    ?>
    <div class="wrap">
        <h1>Contract Pricing Settings</h1>
        <form method="post">
            <table class="form-table">
                <tr>
                    <th scope="row">
                        <label for="api_url">Contract Pricing API URL</label>
                    </th>
                    <td>
                        <input type="url" id="api_url" name="api_url" value="<?php echo esc_attr($api_url); ?>" class="regular-text" />
                        <p class="description">URL to the contract pricing API endpoint</p>
                    </td>
                </tr>
                <tr>
                    <th scope="row">
                        <label for="api_key">API Key</label>
                    </th>
                    <td>
                        <input type="text" id="api_key" name="api_key" value="<?php echo esc_attr($api_key); ?>" class="regular-text" />
                        <p class="description">API key for authentication (must match server configuration)</p>
                    </td>
                </tr>
                <tr>
                    <th scope="row">
                        <label for="cache_ttl">Cache TTL (seconds)</label>
                    </th>
                    <td>
                        <input type="number" id="cache_ttl" name="cache_ttl" value="<?php echo esc_attr($cache_ttl); ?>" min="60" max="3600" />
                        <p class="description">How long to cache contract prices (60-3600 seconds). Default: 300 (5 minutes)</p>
                    </td>
                </tr>
            </table>
            <?php submit_button(); ?>
        </form>
    </div>
    <?php
}


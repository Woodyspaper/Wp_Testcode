<?php
/**
 * Plugin Name: WooCommerce CounterPoint Orders Display
 * Description: Display CounterPoint orders on retail site with proper units (Each, Pack, Box, Carton, Pallet)
 * Version: 1.0.0
 * Author: Woody's Paper Integration
 * 
 * FEATURES:
 * - Display CP orders via shortcode
 * - Filter by unit type (EA, PK, BX, CT, PL)
 * - Filter by date range, customer, status
 * - WordPress-side caching to reduce API calls
 * - Admin settings for API configuration
 */

if (!defined('ABSPATH')) {
    exit;
}

// Cache TTL (10 minutes default)
define('WP_CP_ORDERS_CACHE_TTL', 600);

/**
 * Get CP orders from API with WordPress caching
 */
function wp_get_cp_orders($params = array()) {
    // Generate cache key from params
    $cache_key = 'wp_cp_orders_' . md5(serialize($params));
    
    // Try cache first
    $cached = get_transient($cache_key);
    if ($cached !== false) {
        return $cached;
    }
    
    // Cache miss - call API
    $api_url = get_option('wp_cp_orders_api_url', 'http://localhost:5001/api/cp-orders');
    $api_key = get_option('wp_cp_orders_api_key', '');
    
    // Build query string
    $query_params = array();
    if (!empty($params['date_from'])) {
        $query_params['date_from'] = $params['date_from'];
    }
    if (!empty($params['date_to'])) {
        $query_params['date_to'] = $params['date_to'];
    }
    if (!empty($params['customer_no'])) {
        $query_params['customer_no'] = $params['customer_no'];
    }
    if (!empty($params['status'])) {
        $query_params['status'] = $params['status'];
    }
    if (!empty($params['unit'])) {
        $query_params['unit'] = $params['unit'];
    }
    if (!empty($params['limit'])) {
        $query_params['limit'] = $params['limit'];
    }
    
    $url = $api_url . (!empty($query_params) ? '?' . http_build_query($query_params) : '');
    
    $response = wp_remote_get($url, array(
        'headers' => array(
            'X-API-Key' => $api_key
        ),
        'timeout' => 10
    ));
    
    if (is_wp_error($response)) {
        error_log('CP Orders API error: ' . $response->get_error_message());
        return array('success' => false, 'error' => $response->get_error_message(), 'orders' => array());
    }
    
    $body = wp_remote_retrieve_body($response);
    $data = json_decode($body, true);
    
    if ($data && isset($data['success']) && $data['success']) {
        // Cache the result
        $cache_ttl = get_option('wp_cp_orders_cache_ttl', WP_CP_ORDERS_CACHE_TTL);
        set_transient($cache_key, $data, $cache_ttl);
        return $data;
    }
    
    return array('success' => false, 'error' => 'Invalid API response', 'orders' => array());
}

/**
 * Get orders by unit type
 */
function wp_get_cp_orders_by_unit($unit_code, $days = 30) {
    $api_url = get_option('wp_cp_orders_api_url', 'http://localhost:5001/api/cp-orders');
    $api_key = get_option('wp_cp_orders_api_key', '');
    
    $url = $api_url . '/by-unit/' . urlencode($unit_code) . '?days=' . intval($days);
    
    $response = wp_remote_get($url, array(
        'headers' => array(
            'X-API-Key' => $api_key
        ),
        'timeout' => 10
    ));
    
    if (is_wp_error($response)) {
        return array('success' => false, 'orders' => array());
    }
    
    $body = wp_remote_retrieve_body($response);
    $data = json_decode($body, true);
    
    return $data ? $data : array('success' => false, 'orders' => array());
}

/**
 * Format order for display
 */
function wp_format_cp_order($order) {
    $html = '<div class="cp-order-item">';
    $html .= '<div class="cp-order-header">';
    $html .= '<strong>Order #' . esc_html($order['ORDER_NUMBER']) . '</strong>';
    $html .= ' - ' . esc_html($order['ORDER_DATE']);
    if (!empty($order['CUSTOMER_NAME'])) {
        $html .= ' - ' . esc_html($order['CUSTOMER_NAME']);
    }
    $html .= '</div>';
    
    $html .= '<div class="cp-order-details">';
    $html .= '<div class="cp-order-line">';
    $html .= '<span class="cp-item-sku">' . esc_html($order['SKU']) . '</span>';
    $html .= ' - <span class="cp-item-desc">' . esc_html($order['ITEM_DESCRIPTION']) . '</span>';
    $html .= '</div>';
    
    $html .= '<div class="cp-order-quantity">';
    $html .= 'Quantity: <strong>' . esc_html($order['QUANTITY_ORDERED']) . '</strong>';
    $html .= ' <span class="cp-unit">' . esc_html($order['UNIT_DISPLAY_NAME']) . '</span>';
    $html .= '</div>';
    
    if (!empty($order['UNIT_PRICE'])) {
        $html .= '<div class="cp-order-price">';
        $html .= 'Price: $' . number_format(floatval($order['UNIT_PRICE']), 2);
        if (!empty($order['LINE_TOTAL'])) {
            $html .= ' | Total: $' . number_format(floatval($order['LINE_TOTAL']), 2);
        }
        $html .= '</div>';
    }
    
    $html .= '</div>';
    $html .= '</div>';
    
    return $html;
}

/**
 * Shortcode: [cp_orders]
 * 
 * Attributes:
 * - unit: Filter by unit (EA, PK, BX, CT, PL, TON)
 * - date_from: Start date (YYYY-MM-DD)
 * - date_to: End date (YYYY-MM-DD)
 * - customer_no: Customer number
 * - status: Order status
 * - limit: Max orders to display (default: 50)
 * - group_by_unit: Group orders by unit type (true/false)
 */
function wp_cp_orders_shortcode($atts) {
    $atts = shortcode_atts(array(
        'unit' => '',
        'date_from' => '',
        'date_to' => '',
        'customer_no' => '',
        'status' => '',
        'limit' => 50,
        'group_by_unit' => 'false'
    ), $atts);
    
    // If unit specified, use by-unit endpoint
    if (!empty($atts['unit'])) {
        $days = 30;
        if (!empty($atts['date_from']) && !empty($atts['date_to'])) {
            $date_from = new DateTime($atts['date_from']);
            $date_to = new DateTime($atts['date_to']);
            $days = $date_from->diff($date_to)->days;
        }
        
        $result = wp_get_cp_orders_by_unit($atts['unit'], $days);
    } else {
        $params = array();
        if (!empty($atts['date_from'])) {
            $params['date_from'] = $atts['date_from'];
        }
        if (!empty($atts['date_to'])) {
            $params['date_to'] = $atts['date_to'];
        }
        if (!empty($atts['customer_no'])) {
            $params['customer_no'] = $atts['customer_no'];
        }
        if (!empty($atts['status'])) {
            $params['status'] = $atts['status'];
        }
        if (!empty($atts['unit'])) {
            $params['unit'] = $atts['unit'];
        }
        $params['limit'] = intval($atts['limit']);
        
        $result = wp_get_cp_orders($params);
    }
    
    if (!$result || !isset($result['success']) || !$result['success']) {
        $error = isset($result['error']) ? $result['error'] : 'Unable to fetch orders';
        return '<div class="cp-orders-error">Error: ' . esc_html($error) . '</div>';
    }
    
    $orders = isset($result['orders']) ? $result['orders'] : array();
    
    if (empty($orders)) {
        return '<div class="cp-orders-empty">No orders found.</div>';
    }
    
    // Group by unit if requested
    if ($atts['group_by_unit'] === 'true') {
        $grouped = array();
        foreach ($orders as $order) {
            $unit = isset($order['UNIT_DISPLAY_NAME']) ? $order['UNIT_DISPLAY_NAME'] : 'Unknown';
            if (!isset($grouped[$unit])) {
                $grouped[$unit] = array();
            }
            $grouped[$unit][] = $order;
        }
        
        $html = '<div class="cp-orders-grouped">';
        foreach ($grouped as $unit => $unit_orders) {
            $html .= '<div class="cp-orders-unit-group">';
            $html .= '<h3 class="cp-unit-header">Orders by ' . esc_html($unit) . ' (' . count($unit_orders) . ')</h3>';
            foreach ($unit_orders as $order) {
                $html .= wp_format_cp_order($order);
            }
            $html .= '</div>';
        }
        $html .= '</div>';
    } else {
        $html = '<div class="cp-orders-list">';
        foreach ($orders as $order) {
            $html .= wp_format_cp_order($order);
        }
        $html .= '</div>';
    }
    
    return $html;
}
add_shortcode('cp_orders', 'wp_cp_orders_shortcode');

/**
 * Admin settings page
 */
function wp_cp_orders_admin_menu() {
    add_options_page(
        'CP Orders Settings',
        'CP Orders',
        'manage_options',
        'wp-cp-orders',
        'wp_cp_orders_admin_page'
    );
}
add_action('admin_menu', 'wp_cp_orders_admin_menu');

/**
 * Admin settings page content
 */
function wp_cp_orders_admin_page() {
    if (isset($_POST['wp_cp_orders_save'])) {
        check_admin_referer('wp_cp_orders_settings');
        
        update_option('wp_cp_orders_api_url', sanitize_text_field($_POST['api_url']));
        update_option('wp_cp_orders_api_key', sanitize_text_field($_POST['api_key']));
        update_option('wp_cp_orders_cache_ttl', intval($_POST['cache_ttl']));
        
        echo '<div class="notice notice-success"><p>Settings saved.</p></div>';
    }
    
    $api_url = get_option('wp_cp_orders_api_url', 'http://localhost:5001/api/cp-orders');
    $api_key = get_option('wp_cp_orders_api_key', '');
    $cache_ttl = get_option('wp_cp_orders_cache_ttl', WP_CP_ORDERS_CACHE_TTL);
    ?>
    <div class="wrap">
        <h1>CounterPoint Orders Settings</h1>
        <form method="post">
            <?php wp_nonce_field('wp_cp_orders_settings'); ?>
            <table class="form-table">
                <tr>
                    <th><label for="api_url">API URL</label></th>
                    <td>
                        <input type="url" id="api_url" name="api_url" value="<?php echo esc_attr($api_url); ?>" class="regular-text" />
                        <p class="description">Full URL to CP Orders API (e.g., http://localhost:5001/api/cp-orders)</p>
                    </td>
                </tr>
                <tr>
                    <th><label for="api_key">API Key</label></th>
                    <td>
                        <input type="text" id="api_key" name="api_key" value="<?php echo esc_attr($api_key); ?>" class="regular-text" />
                        <p class="description">API key for authentication</p>
                    </td>
                </tr>
                <tr>
                    <th><label for="cache_ttl">Cache TTL (seconds)</label></th>
                    <td>
                        <input type="number" id="cache_ttl" name="cache_ttl" value="<?php echo esc_attr($cache_ttl); ?>" min="0" />
                        <p class="description">How long to cache API responses (default: 600 seconds = 10 minutes)</p>
                    </td>
                </tr>
            </table>
            <?php submit_button('Save Settings', 'primary', 'wp_cp_orders_save'); ?>
        </form>
        
        <h2>Usage</h2>
        <p>Use the shortcode <code>[cp_orders]</code> to display CounterPoint orders.</p>
        <h3>Shortcode Attributes:</h3>
        <ul>
            <li><code>unit</code> - Filter by unit (EA, PK, BX, CT, PL, TON)</li>
            <li><code>date_from</code> - Start date (YYYY-MM-DD)</li>
            <li><code>date_to</code> - End date (YYYY-MM-DD)</li>
            <li><code>customer_no</code> - Customer number</li>
            <li><code>status</code> - Order status</li>
            <li><code>limit</code> - Max orders (default: 50)</li>
            <li><code>group_by_unit</code> - Group by unit type (true/false)</li>
        </ul>
        <h3>Examples:</h3>
        <ul>
            <li><code>[cp_orders unit="PL"]</code> - Show pallet orders</li>
            <li><code>[cp_orders date_from="2025-01-01" date_to="2025-12-31"]</code> - Show orders in date range</li>
            <li><code>[cp_orders unit="TON" group_by_unit="true"]</code> - Show ton orders grouped</li>
        </ul>
    </div>
    <?php
}

/**
 * Enqueue basic styles
 */
function wp_cp_orders_styles() {
    ?>
    <style>
        .cp-orders-list, .cp-orders-grouped {
            margin: 20px 0;
        }
        .cp-order-item {
            border: 1px solid #ddd;
            padding: 15px;
            margin-bottom: 15px;
            border-radius: 4px;
        }
        .cp-order-header {
            font-size: 1.1em;
            margin-bottom: 10px;
            padding-bottom: 5px;
            border-bottom: 1px solid #eee;
        }
        .cp-order-details {
            margin-left: 10px;
        }
        .cp-order-line {
            margin-bottom: 5px;
        }
        .cp-item-sku {
            font-weight: bold;
            color: #0073aa;
        }
        .cp-order-quantity {
            margin: 5px 0;
        }
        .cp-unit {
            color: #666;
            font-style: italic;
        }
        .cp-order-price {
            color: #0073aa;
            font-weight: bold;
        }
        .cp-orders-error {
            color: #d63638;
            padding: 10px;
            background: #fef7f7;
            border-left: 4px solid #d63638;
        }
        .cp-orders-empty {
            padding: 10px;
            color: #666;
        }
        .cp-orders-unit-group {
            margin-bottom: 30px;
        }
        .cp-unit-header {
            color: #0073aa;
            border-bottom: 2px solid #0073aa;
            padding-bottom: 5px;
        }
    </style>
    <?php
}
add_action('wp_head', 'wp_cp_orders_styles');

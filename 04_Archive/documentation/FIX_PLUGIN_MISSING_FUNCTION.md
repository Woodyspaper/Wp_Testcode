# Fix WordPress Plugin - Missing wp_get_customer_ncr_bid() Function

**Date:** December 30, 2025  
**Error:** `Call to undefined function wp_get_customer_ncr_bid()`

---

## 🔍 **PROBLEM**

The WordPress plugin on the server is missing the `wp_get_customer_ncr_bid()` function that's defined in your local file.

**Error Location:**
- File: `woocommerce-contract-pricing-enhanced.php`
- Line 174 (calling the function)
- Function should be at line 28 (but missing on server)

---

## ✅ **SOLUTION - 3 OPTIONS**

### **Option 1: WordPress Plugin Editor (Easiest)**

1. **Log into WordPress Admin:**
   - Go to: https://www.woodyspaper.com/wp-admin/
   - Log in with your admin credentials

2. **Navigate to Plugin Editor:**
   - Go to: **Plugins → Plugin Editor**
   - Select: **WooCommerce Contract Pricing (Enhanced)**

3. **Add the Missing Function:**
   - Scroll to the top of the file (after the opening `<?php`)
   - Find where other functions are defined (around line 28)
   - Add this function if it's missing:

```php
/**
 * Get customer's NCR BID # from user meta
 * 
 * @param int $user_id WordPress user ID
 * @return string|null NCR BID # or null if not found
 */
function wp_get_customer_ncr_bid($user_id) {
    $ncr_bid = get_user_meta($user_id, 'ncr_bid_no', true);
    if (empty($ncr_bid)) {
        error_log("Contract Pricing: User ID {$user_id} does not have 'ncr_bid_no' meta field.");
        return null;
    }
    return $ncr_bid;
}
```

4. **Save the file:**
   - Click **Update File**

---

### **Option 2: FTP Upload (Recommended)**

1. **Connect via FTP:**
   - Use FileZilla or similar FTP client
   - Connect to GoDaddy FTP server
   - Navigate to: `/wp-content/plugins/woocommerce-contract-pricing-plugin/`

2. **Upload the file:**
   - Upload: `wordpress/woocommerce-contract-pricing-enhanced.php`
   - Overwrite the existing file

3. **Verify:**
   - Check that the file was uploaded completely
   - File should be ~416 lines

---

### **Option 3: GoDaddy File Manager**

1. **Log into GoDaddy cPanel:**
   - Go to GoDaddy hosting dashboard
   - Open **File Manager**

2. **Navigate to plugin directory:**
   - Path: `public_html/wp-content/plugins/woocommerce-contract-pricing-plugin/`

3. **Upload file:**
   - Click **Upload**
   - Select: `wordpress/woocommerce-contract-pricing-enhanced.php`
   - Overwrite existing file

---

## 🔍 **VERIFY THE FIX**

**After updating the plugin, test:**

```powershell
# Test product access
python test_woo_product_exists.py 13818

# Should return: Status Code 200 (not 500)
```

**Then test inventory sync:**
```powershell
python woo_inventory_sync.py sync --sku "01-10100" --apply
```

---

## 📋 **FUNCTION LOCATION**

**The function should be at the TOP of the plugin file, around line 28:**

```php
<?php
/**
 * Plugin Name: WooCommerce Contract Pricing (Enhanced)
 * ...
 */

if (!defined('ABSPATH')) {
    exit;
}

// Cache TTL (5 minutes default)
define('WP_CONTRACT_PRICING_CACHE_TTL', 300);

/**
 * Get customer's NCR BID # from user meta
 */
function wp_get_customer_ncr_bid($user_id) {
    $ncr_bid = get_user_meta($user_id, 'ncr_bid_no', true);
    if (empty($ncr_bid)) {
        error_log("Contract Pricing: User ID {$user_id} does not have 'ncr_bid_no' meta field.");
        return null;
    }
    return $ncr_bid;
}

// ... rest of plugin code ...
```

**The function MUST be defined before it's used (line 184).**

---

## ⚠️ **IMPORTANT NOTES**

1. **Backup First:**
   - Download the current plugin file from server as backup
   - In case something goes wrong

2. **File Permissions:**
   - After upload, verify file permissions are correct (644 or 755)

3. **Clear Cache:**
   - Clear WordPress cache (WP Rocket or other caching plugins)
   - Clear browser cache

4. **Test Immediately:**
   - Test API access right after upload
   - Verify no more 500 errors

---

## 🎯 **QUICK CHECKLIST**

- [ ] Log into WordPress Admin
- [ ] Navigate to Plugin Editor
- [ ] Verify function exists at top of file (around line 28)
- [ ] If missing, add the function
- [ ] Save/Update file
- [ ] Test: `python test_woo_product_exists.py 13818`
- [ ] Should return Status 200 (not 500)

---

**Last Updated:** December 30, 2025

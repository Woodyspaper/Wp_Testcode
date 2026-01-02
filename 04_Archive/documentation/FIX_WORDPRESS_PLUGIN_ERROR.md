# Fix WordPress Plugin Error - wp_get_customer_ncr_bid()

**Date:** December 30, 2025  
**Error:** `Call to undefined function wp_get_customer_ncr_bid()`

---

## 🔍 **ROOT CAUSE**

**Error Message:**
```
Call to undefined function wp_get_customer_ncr_bid() in 
/home/r55genj3zxx0/public_html/wp-content/plugins/woocommerce-contract-pricing-plugin/woocommerce-contract-pricing-enhanced.php:174
```

**Problem:**
- The function `wp_get_customer_ncr_bid()` is defined in the local plugin file (line 28)
- But the server version is missing this function or has a syntax error
- This causes a 500 error when WooCommerce API tries to access products

---

## ✅ **SOLUTION**

### **Re-upload the Plugin File**

**The plugin file on the server needs to be updated with the correct version.**

**Steps:**

1. **Get the correct plugin file:**
   - File: `wordpress/woocommerce-contract-pricing-enhanced.php`
   - This file has the `wp_get_customer_ncr_bid()` function defined

2. **Upload to WordPress:**
   - **Option A: Via FTP**
     - Connect to GoDaddy FTP
     - Navigate to: `/wp-content/plugins/woocommerce-contract-pricing-plugin/`
     - Upload: `woocommerce-contract-pricing-enhanced.php`
     - Overwrite existing file

   - **Option B: Via WordPress Admin**
     - Go to **Plugins → Add New → Upload Plugin**
     - Upload the plugin ZIP file
     - Or edit the file directly in WordPress file editor

   - **Option C: Via GoDaddy File Manager**
     - Use GoDaddy cPanel File Manager
     - Navigate to plugin directory
     - Upload the file

3. **Verify the function exists:**
   - Check that line 28 has: `function wp_get_customer_ncr_bid($user_id) {`
   - The function should be defined before it's called (line 184)

---

## 🔧 **VERIFICATION**

**After uploading, test again:**
```powershell
python test_woo_product_exists.py 13818
```

**Expected:**
- Status Code: 200 (not 500)
- Product details returned
- No "undefined function" error

---

## ⚠️ **IMPORTANT**

**The function MUST be defined before it's used:**
- Function definition: Line 28
- First use: Line 184
- This is correct in the local file

**If the error persists after upload:**
1. Check for PHP syntax errors in the plugin file
2. Check WordPress error logs
3. Verify the file was uploaded completely
4. Check file permissions

---

## 📋 **QUICK FIX CHECKLIST**

- [ ] Download current plugin file from server (backup)
- [ ] Upload correct version from `wordpress/woocommerce-contract-pricing-enhanced.php`
- [ ] Verify function exists at line 28
- [ ] Test API access: `python test_woo_product_exists.py 13818`
- [ ] Test inventory sync: `python woo_inventory_sync.py sync --sku "01-10100" --apply`

---

**Last Updated:** December 30, 2025

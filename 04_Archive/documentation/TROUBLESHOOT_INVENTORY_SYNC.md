# Troubleshooting Inventory Sync - 500 Error

**Date:** December 30, 2025  
**Issue:** WooCommerce API returning 500 Internal Server Error

---

## 🔍 **ERROR ANALYSIS**

**Error:**
```
Error response: {"code":"internal_server_error","message":"<p>There has been a critical error on this website.</p>...
```

**Status Code:** 500 (Internal Server Error)

**This is a WordPress/WooCommerce server-side error, not a script error.**

---

## 🔧 **POSSIBLE CAUSES**

### **1. WordPress Debug Mode**
- WordPress might be in debug mode
- Check WordPress `wp-config.php` for `WP_DEBUG`
- Error might be logged in WordPress debug log

### **2. Plugin Conflict**
- A WordPress plugin might be interfering
- Try disabling plugins temporarily
- Check WordPress error logs

### **3. Product Doesn't Exist**
- Product ID might not exist in WooCommerce
- Product might have been deleted
- Verify product exists via WooCommerce API

### **4. Payload Format Issue**
- Missing required fields
- Invalid data types
- WooCommerce API version mismatch

### **5. Memory/Resource Limits**
- WordPress memory limit exceeded
- PHP execution time limit
- Server resource constraints

---

## ✅ **FIXES TO TRY**

### **Fix 1: Verify Product Exists**

**Test with Python:**
```python
from woo_client import WooClient

client = WooClient()
url = client._url("/products/13818")
resp = client.session.get(url, timeout=30)
print(resp.status_code)
print(resp.json())
```

**Or test with PowerShell:**
```powershell
# Get product from WooCommerce API
$headers = @{
    "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("consumer_key:consumer_secret"))
}
Invoke-RestMethod -Uri "https://woodyspaper.com/wp-json/wc/v3/products/13818" -Headers $headers
```

---

### **Fix 2: Check WordPress Error Logs**

**Location:**
- WordPress root: `wp-content/debug.log`
- Server error logs
- GoDaddy hosting error logs

**Check for:**
- PHP fatal errors
- Plugin conflicts
- Memory errors

---

### **Fix 3: Use Batch API Instead**

**The script was updated to:**
- First verify product exists (GET request)
- Then update inventory (PUT request)
- Better error handling

**Try running again:**
```powershell
python woo_inventory_sync.py sync --sku "01-10100" --apply
```

---

### **Fix 4: Check WooCommerce API Permissions**

**Verify API credentials:**
- Check `.env` file has correct:
  - `WOO_BASE_URL`
  - `WOO_CONSUMER_KEY`
  - `WOO_CONSUMER_SECRET`

**Test API connection:**
```python
from woo_client import WooClient

client = WooClient()
if client.test_connection():
    print("API connection OK")
else:
    print("API connection FAILED")
```

---

### **Fix 5: Try Different Product**

**Test with a different product:**
```powershell
# Try a different SKU
python woo_inventory_sync.py sync --sku "01-10108" --apply
```

**If this works, the issue is specific to product 01-10100.**

---

### **Fix 6: Check Product Type**

**Some product types might not support inventory:**
- Variable products
- Grouped products
- External products

**Verify product type:**
```python
from woo_client import WooClient

client = WooClient()
url = client._url("/products/13818")
resp = client.session.get(url, timeout=30)
if resp.ok:
    product = resp.json()
    print(f"Product type: {product.get('type')}")
    print(f"Manage stock: {product.get('manage_stock')}")
```

---

## 📋 **DEBUGGING STEPS**

### **Step 1: Enable Verbose Logging**

**Update `woo_inventory_sync.py` to add more logging:**
```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

### **Step 2: Test API Directly**

**Use curl or PowerShell to test:**
```powershell
# Test GET product
$cred = "consumer_key:consumer_secret"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($cred)
$base64 = [System.Convert]::ToBase64String($bytes)
$headers = @{ "Authorization" = "Basic $base64" }
Invoke-RestMethod -Uri "https://woodyspaper.com/wp-json/wc/v3/products/13818" -Headers $headers
```

### **Step 3: Check WordPress Site Health**

**In WordPress Admin:**
- Go to **Tools → Site Health**
- Check for critical issues
- Review error messages

---

## 🎯 **QUICK FIXES**

### **Option 1: Use Batch Endpoint**

**Instead of individual PUT requests, use batch:**
- More reliable
- Better error handling
- Can update multiple products at once

### **Option 2: Add Product Verification**

**Before updating, verify product exists:**
- GET product first
- Check if product is valid
- Then update inventory

### **Option 3: Check WordPress Logs**

**Most 500 errors are logged:**
- Check `wp-content/debug.log`
- Check server error logs
- Check GoDaddy hosting logs

---

## ⚠️ **IMMEDIATE ACTION**

**1. Check WordPress Error Log:**
- Look for PHP errors
- Check for plugin conflicts

**2. Test Product Exists:**
- Verify product ID 13818 exists
- Check product type and settings

**3. Try Different Product:**
- Test with product 01-10108 (ID: 13833)
- See if error is product-specific

**4. Check API Credentials:**
- Verify WooCommerce API keys
- Test API connection

---

**The script has been updated with better error handling. Try running it again!**

---

**Last Updated:** December 30, 2025

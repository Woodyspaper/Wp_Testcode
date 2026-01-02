# Quick Fix: Upload Plugin File (Plugin Editor Not Working)

**Date:** December 30, 2025  
**Problem:** WordPress plugin editor won't load  
**Solution:** Upload via FTP or GoDaddy File Manager

---

## 🚀 **EASIEST METHOD: GoDaddy File Manager**

### **Step 1: Log into GoDaddy**

1. Go to: https://www.godaddy.com/
2. Log into your account
3. Go to **My Products** → **Web Hosting**
4. Click **Manage** next to your hosting account

### **Step 2: Open File Manager**

1. In cPanel, find **File Manager**
2. Click to open it
3. Navigate to: `public_html/wp-content/plugins/`

### **Step 3: Find Your Plugin Folder**

Look for one of these folders:
- `woocommerce-contract-pricing/`
- `woocommerce-contract-pricing-plugin/`
- `woody-paper-integration/`

**If folder doesn't exist:**
- Click **+ Folder** button
- Name it: `woocommerce-contract-pricing`
- Click **Create**

### **Step 4: Upload the File**

1. **Enter the plugin folder** (double-click it)
2. Click **Upload** button (top toolbar)
3. **Select file from your computer:**
   ```
   C:\Users\Administrator.ADWPC-MAIN\OneDrive - woodyspaper.com\Desktop\WP_Testcode\wordpress\woocommerce-contract-pricing-enhanced.php
   ```
4. **Wait for upload to complete**
5. **Overwrite** if it asks (click Yes)

### **Step 5: Verify**

1. The file should show: `woocommerce-contract-pricing-enhanced.php`
2. File size should be around **~15-20 KB**
3. Right-click file → **Edit** (to verify it has the function)

---

## 🔧 **ALTERNATIVE: FTP Upload**

### **Step 1: Get FTP Credentials**

**In GoDaddy cPanel:**
1. Go to **FTP Accounts**
2. Find account: `admin@woodyspaper.com`
3. Note the password (or reset it if needed)

### **Step 2: Download FileZilla (Free)**

**Download:** https://filezilla-project.org/download.php?type=client

### **Step 3: Connect via FTP**

**In FileZilla:**
1. **Host:** `woodyspaper.com`
2. **Username:** `admin@woodyspaper.com`
3. **Password:** [Your FTP password]
4. **Port:** `21`
5. Click **Quickconnect**

### **Step 4: Navigate to Plugin Folder**

**Right panel (Remote site):**
1. Double-click `public_html`
2. Double-click `wp-content`
3. Double-click `plugins`
4. Double-click `woocommerce-contract-pricing` (or create it)

### **Step 5: Upload File**

**Left panel (Local site):**
1. Navigate to: `C:\Users\Administrator.ADWPC-MAIN\OneDrive - woodyspaper.com\Desktop\WP_Testcode\wordpress\`

**Right panel (Remote site):**
1. Make sure you're in: `public_html/wp-content/plugins/woocommerce-contract-pricing/`

**Upload:**
1. **Drag and drop** `woocommerce-contract-pricing-enhanced.php` from left to right
2. Or **right-click** file → **Upload**
3. **Overwrite** if prompted

---

## ✅ **VERIFY THE FIX**

**After upload, test:**

```powershell
# Test product access (should return 200, not 500)
python test_woo_product_exists.py 13818
```

**Expected output:**
```
✅ Product exists: 13818
Status Code: 200
```

**Then test inventory sync:**
```powershell
python woo_inventory_sync.py sync --sku "01-10100" --apply
```

---

## 🔍 **WHAT TO CHECK IN THE FILE**

**The uploaded file should have this function at the top (around line 28):**

```php
function wp_get_customer_ncr_bid($user_id) {
    return get_user_meta($user_id, 'ncr_bid_no', true);
}
```

**If using GoDaddy File Manager:**
- Right-click the file → **Edit**
- Scroll to line 28
- Verify the function exists

---

## ⚠️ **TROUBLESHOOTING**

### **File won't upload:**
- Check file permissions (should be 644)
- Try SFTP instead of FTP (port 22)
- Check file size (should be < 1 MB)

### **Can't find plugin folder:**
- Create it: `woocommerce-contract-pricing`
- Or check if it's named differently

### **Still getting 500 error:**
- Clear WordPress cache (WP Rocket)
- Clear browser cache
- Wait 1-2 minutes for changes to propagate

---

## 📋 **QUICK CHECKLIST**

- [ ] Log into GoDaddy cPanel
- [ ] Open File Manager
- [ ] Navigate to `public_html/wp-content/plugins/`
- [ ] Find or create `woocommerce-contract-pricing` folder
- [ ] Upload `woocommerce-contract-pricing-enhanced.php`
- [ ] Verify file uploaded successfully
- [ ] Test: `python test_woo_product_exists.py 13818`
- [ ] Should return Status 200 (not 500)

---

**Last Updated:** December 30, 2025

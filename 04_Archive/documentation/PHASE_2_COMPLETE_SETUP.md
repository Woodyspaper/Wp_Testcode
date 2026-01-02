# Phase 2: Product Catalog Sync - Complete Setup Guide

**Date:** December 31, 2025  
**Status:** Ready for completion  
**Purpose:** Finish Phase 2 product catalog sync setup

---

## 🎯 **OVERVIEW**

**Phase 2: Product Catalog Sync**
- Syncs full product catalog from CounterPoint → WooCommerce
- Updates product details (name, description, categories, images)
- Sets initial stock levels
- Runs every 6 hours (catalog sync)

**Current Status:**
- ✅ View created (`VI_EXPORT_PRODUCTS`)
- ✅ Script exists and connected (`woo_products.py`)
- ✅ Tested (dry-run works)
- ⚠️ Category mapping needed
- ⚠️ Scheduled job not set up yet

---

## 📋 **SETUP STEPS**

### **Step 1: Verify USER_CATEGORY_MAP Table**

**In SQL Server Management Studio:**

1. **Check if table exists:**
   ```sql
   SELECT * FROM sys.tables WHERE name = 'USER_CATEGORY_MAP';
   ```

2. **If it doesn't exist, create it:**
   - Run: `01_Production/staging_tables.sql`
   - Or run just the USER_CATEGORY_MAP section

---

### **Step 2: Identify Top Categories (Optional but Recommended)**

**In SQL Server Management Studio:**

1. **Run:** `02_Testing/GET_TOP_CATEGORIES.sql`
2. **Review results:** See which categories have the most products
3. **Note:** Products will sync without categories if mapping isn't set up (can be added later)

**Top categories typically include:**
- PRINT AND (most products)
- ENVELOPES
- Other major categories

---

### **Step 3: Set Up Category Mappings (Optional)**

**Option A: Manual SQL (for each category):**

1. **Get WooCommerce category ID:**
   - Log into WordPress admin
   - Go to Products → Categories
   - Note the category ID (or create new category)

2. **Add mapping:**
   ```sql
   INSERT INTO dbo.USER_CATEGORY_MAP
       (CP_CATEGORY_CODE, WOO_CATEGORY_ID, WOO_CATEGORY_SLUG, IS_ACTIVE)
   VALUES
       ('PRINT AND', 123, 'print-and-paper', 1);
   ```

**Option B: Sync without categories first:**
- Products will sync successfully without categories
- Categories can be added manually in WooCommerce later
- Or set up mappings later and re-sync

---

### **Step 4: Test Product Sync**

**Dry-Run (Safe - No Changes):**
```powershell
# Test with 5 products
python woo_products.py sync --max 5

# Test with 10 products
python woo_products.py sync --max 10

# Test specific SKU
python woo_products.py sync --sku "01-10100"
```

**Live Sync (Makes Changes):**
```powershell
# Sync 10 products
python woo_products.py sync --apply --max 10

# Sync all products (use with caution!)
python woo_products.py sync --apply
```

**Expected Output:**
```
Product Sync: CounterPoint -> WooCommerce
Found X product(s) to sync
Created: Y
Updated: Z
Errors: 0
```

---

### **Step 5: Create Scheduled Job**

**Run PowerShell as Administrator:**

```powershell
# Create Task Scheduler job (runs every 6 hours)
.\Create-ProductSyncTask.ps1
```

**Or customize interval:**
```powershell
.\Create-ProductSyncTask.ps1 -IntervalHours 12
```

**Verify:**
```powershell
Get-ScheduledTask -TaskName "WooCommerce Product Catalog Sync"
```

---

### **Step 6: Test Scheduled Job**

**Manually run:**
```powershell
Start-ScheduledTask -TaskName "WooCommerce Product Catalog Sync"
```

**Monitor:**
```powershell
.\Monitor-ProductSync.ps1
```

**Check logs:**
```powershell
Get-ChildItem logs\woo_product_sync_*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content
```

---

## 🔍 **VERIFICATION**

### **Check Products in WooCommerce**

1. **Log into WordPress Admin:**
   - Go to: https://www.woodyspaper.com/wp-admin/
   - Navigate to: Products → All Products

2. **Verify synced products:**
   - Search for SKU: `01-10100`
   - Check product details match CounterPoint
   - Check stock quantity
   - Check category (if mapped)

### **Check Mappings**

**In SQL Server:**
```sql
-- Check product mappings
SELECT TOP 10 * FROM dbo.USER_PRODUCT_MAP ORDER BY CREATED_DT DESC;

-- Check category mappings
SELECT * FROM dbo.USER_CATEGORY_MAP;
```

### **Check Sync Logs**

**In SQL Server:**
```sql
-- Recent product syncs
SELECT TOP 10 *
FROM dbo.USER_SYNC_LOG
WHERE OPERATION_TYPE = 'product_sync'
ORDER BY STARTED_AT DESC;
```

---

## 📊 **MONITORING**

### **Monitor Script**

**Quick check:**
```powershell
.\Monitor-ProductSync.ps1
```

**Detailed view:**
```powershell
.\Monitor-ProductSync.ps1 -ShowDetails
```

**Last 48 hours:**
```powershell
.\Monitor-ProductSync.ps1 -LastNHours 48
```

---

## ⚙️ **CONFIGURATION**

### **Change Sync Interval**

**Option 1: Recreate Task**
```powershell
.\Create-ProductSyncTask.ps1 -IntervalHours 12
```

**Option 2: Task Scheduler GUI**
1. Open Task Scheduler
2. Find "WooCommerce Product Catalog Sync"
3. Right-click → Properties
4. Triggers tab → Edit
5. Change "Repeat task every" to desired interval

### **Incremental Sync**

**The wrapper script uses `--updated-since 24h` by default:**
- Only syncs products updated in last 24 hours
- More efficient for scheduled runs
- Full sync still available with `python woo_products.py sync --apply`

**To change:**
- Edit `Run-WooProductSync-Scheduled.ps1`
- Modify the `--updated-since` parameter

---

## 🐛 **TROUBLESHOOTING**

### **No Products Found**

**Check:**
1. Is `VI_EXPORT_PRODUCTS` view working?
   ```sql
   SELECT TOP 10 * FROM dbo.VI_EXPORT_PRODUCTS;
   ```

2. Are there e-commerce products?
   ```sql
   SELECT COUNT(*) FROM dbo.VI_EXPORT_PRODUCTS WHERE ACTIVE = 1;
   ```

### **Products Sync Without Categories**

**This is normal if:**
- `USER_CATEGORY_MAP` is empty
- Category mapping not set up yet

**Solution:**
- Products will sync successfully
- Add categories manually in WooCommerce
- Or set up mappings and re-sync

### **Task Not Running**

**Check:**
1. Is task enabled? (Task Scheduler → Right-click → Properties)
2. Is Task Scheduler service running?
   ```powershell
   Get-Service Schedule
   ```
3. Check last run result in Task Scheduler
4. Check log files for errors

---

## ✅ **COMPLETION CHECKLIST**

- [ ] USER_CATEGORY_MAP table exists
- [ ] Tested product sync (dry-run)
- [ ] Tested product sync (live - small batch)
- [ ] Verified products in WooCommerce
- [ ] Task Scheduler job created
- [ ] Task tested manually
- [ ] Monitoring script tested
- [ ] Logs verified

---

## 📝 **QUICK REFERENCE**

**Test sync:**
```powershell
python woo_products.py sync --max 10
```

**Create scheduled job:**
```powershell
.\Create-ProductSyncTask.ps1
```

**Monitor:**
```powershell
.\Monitor-ProductSync.ps1
```

**Check top categories:**
```sql
-- Run: 02_Testing/GET_TOP_CATEGORIES.sql
```

---

**Last Updated:** December 31, 2025

# Phase 3: Inventory Sync Setup Guide

**Date:** December 30, 2025  
**Purpose:** Set up automated inventory sync from CounterPoint to WooCommerce

---

## 🎯 **OVERVIEW**

**Phase 3: Inventory Sync**
- Syncs ONLY stock quantities from CounterPoint → WooCommerce
- Fast, frequent sync (every 5 minutes)
- Does NOT create new products or update product details
- Only updates `stock_quantity` and `stock_status` for existing products

---

## 📋 **SETUP STEPS**

### **Step 1: Create Inventory Sync View**

**In SQL Server Management Studio:**

1. **Open:** `01_Production/create_inventory_sync_view.sql`
2. **Verify:** You're connected to `WOODYS_CP` database
3. **Execute:** Run the script
4. **Verify:** View created successfully

**Expected Output:**
```
INVENTORY SYNC VIEW CREATED
View Name: VI_INVENTORY_SYNC
```

**Test the view:**
```sql
-- Test inventory sync view
SELECT TOP 10 * FROM dbo.VI_INVENTORY_SYNC ORDER BY SKU;
```

---

### **Step 2: Test Inventory Sync Script**

**In PowerShell:**

```powershell
# Test inventory sync (dry-run)
python woo_inventory_sync.py sync

# Test specific SKU (dry-run)
python woo_inventory_sync.py sync --sku "01-10100"

# Test with actual update
python woo_inventory_sync.py sync --apply --sku "01-10100"
```

**Expected Output:**
```
DRY RUN - Inventory Sync: CounterPoint → WooCommerce
============================================================
Found X products with inventory data

SKU                  Woo ID    CP Stock      Woo Status        Action    
--------------------------------------------------------------------------------
01-10100             123       527.00        instock          WOULD UPDATE
...
```

---

### **Step 3: Create Task Scheduler Job**

**In Windows Task Scheduler:**

1. **Open:** Task Scheduler
2. **Create Basic Task:**
   - **Name:** `WooCommerce Inventory Sync`
   - **Description:** `Sync inventory levels from CounterPoint to WooCommerce (Phase 3)`

3. **Trigger:**
   - **When:** On a schedule
   - **Frequency:** Every 5 minutes
   - **Start:** Current time (or preferred time)
   - **Repeat:** Every 5 minutes, indefinitely

4. **Action:**
   - **Action:** Start a program
   - **Program/script:** `powershell.exe`
   - **Arguments:**
     ```
     -File "C:\Users\Administrator.ADWPC-MAIN\OneDrive - woodyspaper.com\Desktop\WP_Testcode\Run-WooInventorySync.ps1" -SqlServer "YOUR_SQL_SERVER" -Database "WOODYS_CP" -RepoRoot "C:\Users\Administrator.ADWPC-MAIN\OneDrive - woodyspaper.com\Desktop\WP_Testcode" -PythonExe "C:\Program Files\Python314\python.exe" -WooScriptPath "C:\Users\Administrator.ADWPC-MAIN\OneDrive - woodyspaper.com\Desktop\WP_Testcode\woo_inventory_sync.py"
     ```
   - **Start in:** `C:\Users\Administrator.ADWPC-MAIN\OneDrive - woodyspaper.com\Desktop\WP_Testcode`

5. **Conditions:**
   - ✅ Start only if computer is on AC power
   - ✅ Wake computer to run (optional)

6. **Settings:**
   - ✅ Allow task to be run on demand
   - ✅ Run task as soon as possible after scheduled start is missed
   - ✅ **"If the task is already running, then the following rule applies: Do not start a new instance"** (important!)

7. **Click OK** to create the task

---

### **Step 4: Test Task Scheduler Job**

**In Task Scheduler:**

1. **Right-click:** `WooCommerce Inventory Sync` task
2. **Select:** "Run"
3. **Monitor:** Task execution
4. **Check:** Log file in `logs/woo_inventory_sync_*.log`

**Or test manually:**
```powershell
# Run the PowerShell script directly
.\Run-WooInventorySync.ps1 `
  -SqlServer "YOUR_SQL_SERVER" `
  -Database "WOODYS_CP" `
  -RepoRoot "C:\Users\Administrator.ADWPC-MAIN\OneDrive - woodyspaper.com\Desktop\WP_Testcode" `
  -PythonExe "C:\Program Files\Python314\python.exe" `
  -WooScriptPath "C:\Users\Administrator.ADWPC-MAIN\OneDrive - woodyspaper.com\Desktop\WP_Testcode\woo_inventory_sync.py"
```

---

## 📊 **HOW IT WORKS**

### **Stock Status Mapping:**

| CounterPoint Stock | WooCommerce Status | WooCommerce Stock Qty |
|-------------------|-------------------|---------------------|
| `QTY_ON_HND > 0` | `instock` | Actual quantity |
| `QTY_ON_HND = 0` | `outofstock` | 0 |
| `QTY_ON_HND < 0` | `onbackorder` | 0 (displays as "On Order") |

### **Sync Process:**

1. **Query CounterPoint:**
   - Get inventory from `VI_INVENTORY_SYNC` view
   - Only products that exist in WooCommerce (via `USER_PRODUCT_MAP`)
   - Only e-commerce items (`IS_ECOMM_ITEM = 'Y'`)

2. **Calculate Stock Status:**
   - Determine `stock_status` based on quantity
   - Set `stock_quantity` (0 for backorder/out of stock)

3. **Update WooCommerce:**
   - Update product inventory via WooCommerce API
   - Only updates `stock_quantity` and `stock_status`
   - Does NOT update product details

---

## ✅ **VERIFICATION**

### **Check Inventory Sync:**

```sql
-- Check inventory sync view
SELECT TOP 20 
    SKU,
    WOO_PRODUCT_ID,
    STOCK_QTY,
    CP_STATUS
FROM dbo.VI_INVENTORY_SYNC
ORDER BY SKU;
```

### **Check WooCommerce Products:**

```powershell
# Test specific product in WooCommerce
python woo_inventory_sync.py sync --sku "01-10100" --apply
```

### **Check Logs:**

```powershell
# View latest inventory sync log
Get-Content logs\woo_inventory_sync_*.log -Tail 50 | Select-Object -Last 1
```

---

## ⚠️ **IMPORTANT NOTES**

1. **Only Updates Existing Products:**
   - Does NOT create new products
   - Only updates products that exist in WooCommerce (via `USER_PRODUCT_MAP`)

2. **Fast Sync:**
   - Designed for frequent updates (every 5 minutes)
   - Only syncs inventory, not product details

3. **Stock Status:**
   - Negative quantities show as "On Order" (onbackorder)
   - Zero quantities show as "Out of Stock" (outofstock)
   - Positive quantities show as "In Stock" (instock)

4. **Product Mapping Required:**
   - Products must exist in `USER_PRODUCT_MAP` table
   - Run product sync (Phase 2) first to create mappings

---

## 🔧 **TROUBLESHOOTING**

### **Issue: No products found to sync**

**Check:**
1. Verify products exist in `USER_PRODUCT_MAP`:
   ```sql
   SELECT COUNT(*) FROM dbo.USER_PRODUCT_MAP WHERE IS_ACTIVE = 1;
   ```

2. Verify products are e-commerce items:
   ```sql
   SELECT COUNT(*) FROM dbo.VI_INVENTORY_SYNC;
   ```

### **Issue: Inventory not updating in WooCommerce**

**Check:**
1. Verify WooCommerce API credentials in `.env`
2. Check log file for errors
3. Test with specific SKU: `python woo_inventory_sync.py sync --sku "01-10100" --apply`

### **Issue: Task Scheduler not running**

**Check:**
1. Verify task is enabled
2. Check task history for errors
3. Verify PowerShell script path is correct
4. Check log file for details

---

## 📝 **NEXT STEPS**

After Phase 3 is set up:

1. **Monitor first runs:**
   - Check log files
   - Verify inventory updates in WooCommerce
   - Check for errors

2. **Set up alerts (optional):**
   - Create alerts for sync failures
   - Set up email notifications

3. **Implement Phase 5:**
   - Order creation in CounterPoint
   - Sales ticket creation
   - Inventory updates when orders created

---

**Last Updated:** December 30, 2025

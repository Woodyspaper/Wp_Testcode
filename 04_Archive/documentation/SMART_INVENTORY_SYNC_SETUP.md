# Smart Inventory Sync Setup

**Date:** December 31, 2025  
**Purpose:** Event-driven inventory sync that only updates when needed

---

## 🎯 **OVERVIEW**

**Smart Inventory Sync Logic:**
- ✅ Updates after orders placed (website or CounterPoint POS)
- ✅ Updates when new products added
- ✅ Updates when products phased out/removed
- ✅ Otherwise syncs every 12 hours (instead of every 5 minutes)

**Benefits:**
- Reduces unnecessary API calls
- More efficient resource usage
- Still keeps inventory up-to-date when changes occur

---

## 📋 **HOW IT WORKS**

### **Event Detection**

The sync checks for these events before running:

1. **New Orders:**
   - Checks `USER_ORDER_STAGING` for orders created since last sync
   - Triggers sync if new orders found

2. **New Products:**
   - Checks `VI_EXPORT_PRODUCTS` for products with recent `LST_MAINT_DT`
   - Triggers sync if new products detected

3. **Product Status Changes:**
   - Checks for products modified recently
   - Triggers sync if changes detected

4. **Inventory Changes:**
   - Checks `VI_INVENTORY_SYNC` for inventory modifications
   - Triggers sync if inventory changed

5. **Time-Based Fallback:**
   - If 12+ hours have passed since last sync, sync anyway
   - Ensures inventory stays current even without events

---

## 🔧 **SETUP**

### **Step 1: Update Scheduled Task**

**Run PowerShell as Administrator:**

```powershell
# Recreate task with 12-hour interval
.\Create-InventorySyncTask.ps1
```

**This will:**
- Update task to run every 12 hours
- Add smart sync logic (checks events before syncing)
- Keep existing task name: "WooCommerce Inventory Sync"

---

### **Step 2: Verify Smart Sync Logic**

**Test the checker:**
```powershell
python check_inventory_sync_needed.py
```

**Expected output:**
```
============================================================
Inventory Sync Check
============================================================
Time: 2025-12-31 10:00:00

Should sync: YES/NO
Reason: [reason for sync or skip]
```

---

### **Step 3: Test Full Flow**

**Manually run the scheduled script:**
```powershell
.\Run-WooInventorySync-Scheduled.ps1
```

**Check log output:**
- Should show "Checking if inventory sync is needed..."
- Will show reason for sync or skip
- Only runs actual sync if needed

---

## 📊 **MONITORING**

### **Check Sync Frequency**

**View recent syncs:**
```powershell
.\Monitor-InventorySync.ps1
```

**Check why syncs ran:**
```powershell
Get-ChildItem logs\woo_inventory_sync_*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content | Select-String "Checking if|Reason|SKIPPED|Starting inventory"
```

---

## 🔍 **VERIFICATION**

### **Check Last Sync Time**

**In SQL Server:**
```sql
SELECT TOP 1 
    OPERATION_TYPE,
    START_TIME,
    DATEDIFF(HOUR, START_TIME, GETDATE()) AS HOURS_AGO
FROM dbo.USER_SYNC_LOG
WHERE OPERATION_TYPE = 'inventory_sync'
ORDER BY START_TIME DESC;
```

### **Check Recent Events**

**New orders:**
```sql
SELECT COUNT(*) AS NEW_ORDERS
FROM dbo.USER_ORDER_STAGING
WHERE CREATED_DT >= DATEADD(HOUR, -1, GETDATE());
```

**New products:**
```sql
SELECT COUNT(*) AS NEW_PRODUCTS
FROM dbo.VI_EXPORT_PRODUCTS
WHERE LST_MAINT_DT >= DATEADD(HOUR, -1, GETDATE());
```

---

## ⚙️ **CONFIGURATION**

### **Change Time Threshold**

**Edit `check_inventory_sync_needed.py`:**
```python
# Change from 12 hours to different value
should_sync, reason = should_sync_inventory(conn, hours_threshold=24)
```

### **Change Check Interval**

**Recreate task with different interval:**
```powershell
.\Create-InventorySyncTask.ps1 -IntervalHours 24
```

---

## 🐛 **TROUBLESHOOTING**

### **Sync Always Runs**

**Check:**
1. Is `USER_SYNC_LOG` logging correctly?
2. Are event checks working?
3. Check log for "Never synced before" message

### **Sync Never Runs**

**Check:**
1. Is task enabled in Task Scheduler?
2. Check task last run time
3. Check log files for errors

### **Events Not Detected**

**Check:**
1. Are orders being staged in `USER_ORDER_STAGING`?
2. Are products being modified in CounterPoint?
3. Check timestamps in database

---

## ✅ **COMPLETION CHECKLIST**

- [ ] `check_inventory_sync_needed.py` created
- [ ] `Run-WooInventorySync-Scheduled.ps1` updated with smart logic
- [ ] Scheduled task updated to 12 hours
- [ ] Smart sync logic tested
- [ ] Monitoring verified

---

## 📝 **QUICK REFERENCE**

**Test checker:**
```powershell
python check_inventory_sync_needed.py
```

**Update task:**
```powershell
.\Create-InventorySyncTask.ps1
```

**Monitor:**
```powershell
.\Monitor-InventorySync.ps1
```

**Manual sync (force):**
```powershell
python woo_inventory_sync.py sync --apply
```

---

**Last Updated:** December 31, 2025

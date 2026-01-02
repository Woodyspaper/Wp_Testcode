# Setup Inventory Sync - Task Scheduler

**Date:** December 30, 2025  
**Purpose:** Set up automated inventory sync from CounterPoint to WooCommerce

---

## 🎯 **OVERVIEW**

**Phase 3: Inventory Sync**
- Syncs stock quantities from CounterPoint → WooCommerce
- Runs every 5 minutes (configurable)
- Updates only existing products (doesn't create new ones)
- Logs all activity for monitoring

---

## 📋 **SETUP STEPS**

### **Step 1: Create Task Scheduler Job (Automated)**

**Run PowerShell as Administrator:**

```powershell
# Navigate to project directory
cd "C:\Users\Administrator.ADWPC-MAIN\OneDrive - woodyspaper.com\Desktop\WP_Testcode"

# Create the scheduled task
.\Create-InventorySyncTask.ps1
```

**This will:**
- Create a task named "WooCommerce Inventory Sync"
- Schedule it to run every 5 minutes
- Use the wrapper script `Run-WooInventorySync-Scheduled.ps1`
- Set up proper logging

**To customize the interval:**
```powershell
.\Create-InventorySyncTask.ps1 -IntervalMinutes 10
```

---

### **Step 2: Verify Task Created**

**Option A: PowerShell**
```powershell
Get-ScheduledTask -TaskName "WooCommerce Inventory Sync"
```

**Option B: Task Scheduler GUI**
1. Open **Task Scheduler** (Windows key → type "Task Scheduler")
2. Look for task: **"WooCommerce Inventory Sync"**
3. Verify it's enabled and scheduled

---

### **Step 3: Test the Task**

**Option A: PowerShell**
```powershell
Start-ScheduledTask -TaskName "WooCommerce Inventory Sync"
```

**Option B: Task Scheduler GUI**
1. Right-click the task
2. Select **"Run"**
3. Wait for completion
4. Check the log file in `logs/` folder

---

### **Step 4: Monitor Logs**

**Quick Check:**
```powershell
.\Monitor-InventorySync.ps1
```

**Detailed View:**
```powershell
.\Monitor-InventorySync.ps1 -ShowDetails
```

**Check Last 24 Hours:**
```powershell
.\Monitor-InventorySync.ps1 -LastNHours 24
```

---

## 🔍 **VERIFY IN WOOCOMMERCE**

### **Step 1: Log into WordPress Admin**

1. Go to: https://www.woodyspaper.com/wp-admin/
2. Log in with admin credentials

### **Step 2: Check Product Inventory**

1. Navigate to: **Products** → **All Products**
2. Search for a product (e.g., SKU: `01-10100`)
3. Click to edit the product
4. Check **Inventory** tab:
   - **Stock quantity** should match CounterPoint
   - **Stock status** should be correct (instock/outofstock/onbackorder)

### **Step 3: Verify Multiple Products**

**Test Products (from recent sync):**
- `01-10100` → Should show 495.00 stock
- `01-10105` → Should show 250.00 stock
- `01-10108` → Should show 598.00 stock
- `01-10102` → Should show 0.00 stock (outofstock)

---

## 📊 **MONITORING**

### **Check Task Status**

**PowerShell:**
```powershell
Get-ScheduledTaskInfo -TaskName "WooCommerce Inventory Sync"
```

**Output shows:**
- Last run time
- Last result (0 = success)
- Next run time
- Task state

### **Check Log Files**

**Location:**
```
C:\Users\Administrator.ADWPC-MAIN\OneDrive - woodyspaper.com\Desktop\WP_Testcode\logs\
```

**Log file format:**
```
woo_inventory_sync_20251230_143022.log
```

**Log contains:**
- Timestamp of each run
- Products updated
- Any errors
- Summary statistics

### **Monitor Script**

**Run monitoring script:**
```powershell
.\Monitor-InventorySync.ps1
```

**Shows:**
- Task Scheduler status
- Recent log files
- Success/error counts
- Total products updated

---

## ⚙️ **CONFIGURATION**

### **Change Sync Interval**

**Option 1: Recreate Task**
```powershell
.\Create-InventorySyncTask.ps1 -IntervalMinutes 10
```

**Option 2: Task Scheduler GUI**
1. Open Task Scheduler
2. Find "WooCommerce Inventory Sync"
3. Right-click → **Properties**
4. Go to **Triggers** tab
5. Edit trigger → Change **Repeat task every** to desired interval
6. Click **OK**

### **Disable/Enable Task**

**PowerShell:**
```powershell
# Disable
Disable-ScheduledTask -TaskName "WooCommerce Inventory Sync"

# Enable
Enable-ScheduledTask -TaskName "WooCommerce Inventory Sync"
```

**Task Scheduler GUI:**
- Right-click task → **Disable** or **Enable**

---

## 🐛 **TROUBLESHOOTING**

### **Task Not Running**

**Check:**
1. Is task enabled? (Task Scheduler → Right-click → Properties)
2. Is Task Scheduler service running?
   ```powershell
   Get-Service Schedule
   ```
3. Check last run result in Task Scheduler
4. Check log files for errors

### **Errors in Logs**

**Common Issues:**
- **Python not found:** Update PATH or specify full path in wrapper script
- **Database connection error:** Check `.env` file has correct SQL Server credentials
- **WooCommerce API error:** Check API credentials in `.env`
- **Permission errors:** Run Task Scheduler as user with proper permissions

### **View Detailed Logs**

```powershell
# View latest log
Get-Content logs\woo_inventory_sync_*.log | Select-Object -Last 50

# Search for errors
Get-Content logs\woo_inventory_sync_*.log | Select-String "ERROR"
```

---

## ✅ **VERIFICATION CHECKLIST**

- [ ] Task created in Task Scheduler
- [ ] Task is enabled and scheduled
- [ ] Test run completed successfully
- [ ] Log file created in `logs/` folder
- [ ] Products updated in WooCommerce
- [ ] Stock quantities match CounterPoint
- [ ] Monitoring script shows successful runs

---

## 📝 **QUICK REFERENCE**

**Create Task:**
```powershell
.\Create-InventorySyncTask.ps1
```

**Test Task:**
```powershell
Start-ScheduledTask -TaskName "WooCommerce Inventory Sync"
```

**Monitor:**
```powershell
.\Monitor-InventorySync.ps1
```

**Check Logs:**
```powershell
Get-ChildItem logs\woo_inventory_sync_*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content
```

---

**Last Updated:** December 30, 2025

# Fix Order Processing Schedule

**Issue:** Task is running every 5 minutes instead of using smart check logic  
**Solution:** Update task to run less frequently (30 minutes) - smart check will still skip when not needed

---

## 🔍 **THE PROBLEM**

The task `WP_WooCommerce_Order_Processing` is currently set to run every **5 minutes**. While the smart check logic (`check_order_processing_needed.py`) should skip processing when not needed, the task itself still runs every 5 minutes to perform the check.

**Current Behavior:**
- Task runs every 5 minutes
- Smart check runs (fast SQL query)
- If no orders pending AND < 2 hours since last run → Skip processing ✅
- If orders pending OR > 2 hours since last run → Process ✅

**Issue:** Task runs too frequently (every 5 minutes) even when it will skip processing.

---

## ✅ **THE SOLUTION**

Update the task to run every **30 minutes** instead of 5 minutes. The smart check logic will still work correctly:

- **Every 30 minutes:** Task runs, checks if processing needed
- **If orders pending:** Process immediately ✅
- **If no orders AND < 2 hours since last run:** Skip (log shows "SKIPPED") ✅
- **If no orders AND > 2 hours since last run:** Process (periodic fallback) ✅

---

## 🔧 **HOW TO FIX**

### **Option 1: Run Update Script (Recommended)**

```powershell
# Run as Administrator
.\Update-OrderProcessingTaskSchedule.ps1
```

This will:
- Update the task to run every 30 minutes
- Keep all other settings intact
- Smart check logic remains unchanged

### **Option 2: Manual Update**

1. Open **Task Scheduler**
2. Find task: `WP_WooCommerce_Order_Processing`
3. Right-click → **Properties**
4. Go to **Triggers** tab
5. Select the trigger → **Edit**
6. Change **Repeat task every:** from `5 minutes` to `30 minutes`
7. Click **OK**

### **Option 3: Recreate Task with New Schedule**

```powershell
# Run as Administrator
.\Create-OrderProcessingTask.ps1 -CheckIntervalMinutes 30
```

---

## 📊 **EXPECTED BEHAVIOR AFTER FIX**

### **Scenario 1: Orders Pending**
- Task runs (every 30 min)
- Smart check: "5 pending orders"
- **Result:** Process immediately ✅

### **Scenario 2: No Orders, Recent Processing**
- Task runs (every 30 min)
- Smart check: "No pending orders (last run: 0.5 hours ago)"
- **Result:** Skip processing, log shows "SKIPPED" ✅

### **Scenario 3: No Orders, Old Processing**
- Task runs (every 30 min)
- Smart check: "Periodic check: 2.5 hours since last run"
- **Result:** Process (periodic fallback) ✅

---

## 🧪 **VERIFY IT'S WORKING**

### **Check Task Schedule:**
```powershell
Get-ScheduledTask -TaskName "WP_WooCommerce_Order_Processing" | Get-ScheduledTaskInfo
```

### **Check Logs:**
```powershell
# Look for "SKIPPED" messages when no orders
Get-Content logs\woo_order_processing_*.log | Select-String "SKIPPED"
```

### **Check Smart Check Output:**
```powershell
python check_order_processing_needed.py
```

Should show:
- "Should process: YES" if orders pending or > 2 hours since last run
- "Should process: NO" if no orders and < 2 hours since last run

---

## 📋 **RECOMMENDED SCHEDULE**

| Volume | Check Frequency | Periodic Fallback |
|--------|----------------|-------------------|
| **High** | Every 15-30 min | 1-2 hours |
| **Medium** | Every 30 min | 2-3 hours (default) |
| **Low** | Every 1 hour | 3-4 hours |

**Current recommendation:** 30 minutes (good balance between responsiveness and efficiency)

---

## ⚠️ **IMPORTANT NOTES**

1. **Smart check is working correctly** - it's just the task frequency that needs adjustment
2. **Processing is still event-driven** - orders are processed immediately when pending
3. **Periodic fallback still works** - runs every 2-3 hours even if no orders
4. **No code changes needed** - just update the task schedule

---

**Last Updated:** January 2, 2026  
**Status:** ✅ **FIX READY - Run Update Script**

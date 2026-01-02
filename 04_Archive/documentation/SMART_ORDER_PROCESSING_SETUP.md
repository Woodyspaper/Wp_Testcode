# Smart Order Processing Setup

**Date:** December 31, 2025  
**Status:** ✅ **IMPLEMENTED - Event-Driven Approach**

---

## 🎯 **SMART APPROACH (Instead of Fixed 2-5 Minutes)**

Instead of running every 2-5 minutes regardless of whether there are orders, we use a **smart, event-driven approach**:

### **How It Works:**

1. **Check for Pending Orders** - Only process if orders are waiting
2. **Periodic Fallback** - Check every 2-3 hours even if no orders (catches edge cases)
3. **Retry Failed Orders** - Check for failed orders ready to retry

### **Benefits:**

✅ **Efficient** - Only runs when needed  
✅ **Responsive** - Processes orders immediately when they arrive  
✅ **Resource-Friendly** - Doesn't waste CPU/DB resources when idle  
✅ **Flexible** - Adapts to order volume automatically

---

## 📊 **PROCESSING LOGIC**

### **When Processing Runs:**

| Condition | Action | Frequency |
|-----------|--------|-----------|
| **Pending orders exist** | Process immediately | As needed |
| **No orders, but 2+ hours since last check** | Periodic check | Every 2-3 hours (fallback) |
| **Failed orders ready to retry** | Process retries | Every 2-3 hours (if detected) |
| **No orders, < 2 hours since last check** | Skip | Wait |

### **Example Scenarios:**

**Scenario 1: Orders arrive frequently**
```
10:00 AM - 3 orders arrive → Process immediately
10:05 AM - 2 orders arrive → Process immediately
10:10 AM - 1 order arrives → Process immediately
```
*Result: Orders processed within minutes of arrival*

**Scenario 2: No orders for hours**
```
10:00 AM - Process (no orders, periodic check)
10:05 AM - Skip (no orders, too soon)
10:10 AM - Skip (no orders, too soon)
12:00 PM - Process (no orders, 2+ hours since last check)
```
*Result: Minimal resource usage, checks every 2-3 hours*

**Scenario 3: Mixed workload**
```
10:00 AM - 5 orders arrive → Process immediately
10:02 AM - No orders → Skip (too soon)
10:05 AM - No orders → Skip (too soon)
12:00 PM - No orders → Process (periodic check - 2 hours)
12:15 PM - 1 order arrives → Process immediately
```
*Result: Responsive when needed, efficient when idle*

---

## 🔧 **SETUP INSTRUCTIONS**

### **Step 1: Files Created**

✅ **`check_order_processing_needed.py`** - Smart check script  
✅ **`Run-WooOrderProcessing.ps1`** - Updated to use smart check

### **Step 2: Create Scheduled Task**

**Option A: Task Scheduler (Recommended)**

1. Open Task Scheduler
2. Create Basic Task:
   - **Name:** `WP_WooCommerce_Order_Processing`
   - **Trigger:** Every 5 minutes (runs check, but only processes if needed)
   - **Action:** Run PowerShell script
   - **Script:** `Run-WooOrderProcessing.ps1`
   - **Arguments:**
     ```
     -SqlServer "localhost" -Database "WOODYS_CP" `
     -RepoRoot "C:\path\to\repo" `
     -PythonExe "C:\Python314\python.exe" `
     -ProcessorScriptPath "C:\path\to\cp_order_processor.py" `
     -CheckScriptPath "C:\path\to\check_order_processing_needed.py"
     ```

**Option B: SQL Agent Job**

Create SQL Agent job that:
1. Calls `check_order_processing_needed.py` (via PowerShell)
2. If exit code = 0, calls `cp_order_processor.py process --all`
3. Runs every 5 minutes

---

## ⚙️ **CONFIGURATION**

### **Check Interval (Fallback)**

Default: **2 hours (120 minutes)**

To change, set environment variable:
```powershell
$env:ORDER_PROCESSING_INTERVAL_MINUTES = "180"  # 3 hours
```

Or edit `check_order_processing_needed.py`:
```python
should_process, reason = should_process_orders(
    conn, 
    min_check_interval_minutes=180  # Change this value (in minutes)
)
```

**Recommended values:**
- **High volume:** 1-2 hours
- **Medium volume:** 2-3 hours (default: 2 hours)
- **Low volume:** 3-4 hours

### **Task Scheduler Frequency**

**Recommended:** Run check every **5 minutes**

Why? The check is fast (just a SQL query), and ensures we catch orders quickly. The actual processing only happens when needed. The periodic fallback (2-3 hours) is separate from the check frequency.

---

## 📊 **MONITORING**

### **Check Processing Activity:**

```sql
-- View pending orders
SELECT 
    COUNT(*) AS PendingCount,
    MIN(CREATED_DT) AS OldestOrder,
    MAX(CREATED_DT) AS NewestOrder
FROM dbo.USER_ORDER_STAGING
WHERE IS_APPLIED = 0;
```

### **Check Processing History:**

```sql
-- View recent processing runs
SELECT TOP 20
    START_TIME,
    END_TIME,
    OPERATION_TYPE,
    RECORDS_PROCESSED,
    STATUS
FROM dbo.USER_SYNC_LOG
WHERE OPERATION_TYPE = 'order_processing'
ORDER BY START_TIME DESC;
```

### **Check Processing Logs:**

```powershell
# View recent log files
Get-ChildItem "C:\path\to\logs\woo_order_processing_*.log" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 5
```

---

## 🎯 **COMPARISON: Fixed vs Smart**

| Approach | Fixed 2-5 Min | Smart (Event-Driven) |
|----------|---------------|---------------------|
| **Runs when no orders** | ✅ Yes (wasteful) | ❌ No (efficient) |
| **Runs when orders arrive** | ✅ Yes | ✅ Yes (immediate) |
| **Resource usage** | ⚠️ Constant | ✅ Minimal when idle |
| **Response time** | ⚠️ Up to 5 min delay | ✅ Immediate |
| **Complexity** | ✅ Simple | ⚠️ Slightly more complex |

**Winner:** Smart approach is better for most scenarios

---

## ⚠️ **EDGE CASES HANDLED**

### **1. First Run**
- If never run before, processes immediately to establish baseline

### **2. Failed Orders**
- Checks for failed orders that might be ready to retry
- Retries orders that failed > 1 hour ago

### **3. Database Errors**
- If check fails, defaults to processing (safe fallback)
- Ensures orders aren't missed due to check script errors

### **4. Clock Skew**
- Uses database timestamps (not system clock)
- Prevents issues with time synchronization

---

## 🚀 **NEXT STEPS**

1. **Set up scheduled task** (see Step 2 above)
2. **Test with sample orders** - Verify processing happens quickly
3. **Monitor logs** - Check that smart check is working
4. **Adjust interval** - If needed, change fallback interval

---

## 📝 **TROUBLESHOOTING**

### **Orders not processing:**

1. Check if task is running:
   ```powershell
   Get-ScheduledTask -TaskName "WP_WooCommerce_Order_Processing" | Get-ScheduledTaskInfo
   ```

2. Check logs for errors:
   ```powershell
   Get-Content "C:\path\to\logs\woo_order_processing_*.log" -Tail 50
   ```

3. Manually run check:
   ```powershell
   python check_order_processing_needed.py
   ```

4. Manually process:
   ```powershell
   python cp_order_processor.py process --all
   ```

---

**Last Updated:** December 31, 2025

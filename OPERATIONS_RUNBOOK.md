# Operations Runbook - Order Processing System

**Date:** January 2, 2026  
**Purpose:** Day-to-day operations guide for order processing system

---

## 📋 **DAILY CHECKS**

### **Morning Check (9:00 AM)**

```powershell
# 1. Check system health
python check_order_processing_health.py

# 2. Check pending orders
python cp_order_processor.py list

# 3. Check Task Scheduler status
Get-ScheduledTask -TaskName "WP_WooCommerce_Order_Processing" | Get-ScheduledTaskInfo
```

**Expected Results:**
- Health check: Exit code 0 (healthy) or 1 (warning)
- Pending orders: Should be 0 or low (< 10)
- Task Scheduler: Last run within last hour

---

## 🔍 **TROUBLESHOOTING**

### **Issue: Orders Not Processing**

**Symptoms:**
- Orders stuck in staging
- Health check shows pending orders > 1 hour old

**Steps:**
1. **Check Task Scheduler:**
   ```powershell
   Get-ScheduledTask -TaskName "WP_WooCommerce_Order_Processing" | Get-ScheduledTaskInfo
   ```
   - If `LastTaskResult` is not `0x0`, check logs

2. **Check Logs:**
   ```powershell
   Get-ChildItem "logs\woo_order_processing_*.log" | 
       Sort-Object LastWriteTime -Descending | 
       Select-Object -First 1 | 
       Get-Content -Tail 50
   ```

3. **Manually Process:**
   ```powershell
   python cp_order_processor.py process --all
   ```

4. **Check for Errors:**
   ```sql
   -- Run: 01_Production/FIND_FAILED_ORDERS.sql
   ```

---

### **Issue: Failed Orders**

**Symptoms:**
- Orders with `VALIDATION_ERROR` in staging
- Health check shows failed orders

**Steps:**
1. **Find Failed Orders:**
   ```sql
   -- Run: 01_Production/FIND_FAILED_ORDERS.sql
   ```

2. **Review Error:**
   ```powershell
   python cp_order_processor.py show <STAGING_ID>
   ```

3. **Common Errors & Fixes:**
   - **"Customer not found"** → Create customer in CounterPoint or fix CUST_NO
   - **"Item not found"** → Verify item exists in IM_ITEM or fix SKU
   - **"Line items missing"** → Check LINE_ITEMS_JSON format
   - **"Invalid totals"** → Verify SUBTOT + TAX_AMT + SHIP_AMT = TOT_AMT

4. **Fix and Retry:**
   ```sql
   -- Fix the issue in USER_ORDER_STAGING
   UPDATE dbo.USER_ORDER_STAGING
   SET VALIDATION_ERROR = NULL
   WHERE STAGING_ID = <ID>;
   ```
   ```powershell
   python cp_order_processor.py process <STAGING_ID>
   ```

---

### **Issue: Task Scheduler Not Running**

**Symptoms:**
- Health check shows no recent processing
- Task Scheduler shows "Disabled" or errors

**Steps:**
1. **Check Task Status:**
   ```powershell
   Get-ScheduledTask -TaskName "WP_WooCommerce_Order_Processing"
   ```

2. **Enable Task:**
   ```powershell
   Enable-ScheduledTask -TaskName "WP_WooCommerce_Order_Processing"
   ```

3. **Test Run:**
   ```powershell
   Start-ScheduledTask -TaskName "WP_WooCommerce_Order_Processing"
   ```

4. **Check Result:**
   ```powershell
   Start-Sleep -Seconds 10
   Get-ScheduledTask -TaskName "WP_WooCommerce_Order_Processing" | Get-ScheduledTaskInfo
   ```

---

### **Issue: Database Connection Errors**

**Symptoms:**
- Logs show "Connection failed" or "Timeout"
- Health check fails

**Steps:**
1. **Test Connection:**
   ```python
   python test_connection.py
   ```

2. **Check SQL Server:**
   - Verify SQL Server is running
   - Check network connectivity
   - Verify credentials in `config.py`

3. **Check Firewall:**
   - Ensure SQL Server port (usually 1433) is open
   - Check Windows Firewall rules

---

## 📊 **MONITORING QUERIES**

### **Check Pending Orders:**
```sql
SELECT 
    COUNT(*) AS PendingCount,
    MIN(CREATED_DT) AS OldestOrder,
    MAX(CREATED_DT) AS NewestOrder
FROM dbo.USER_ORDER_STAGING
WHERE IS_APPLIED = 0;
```

### **Check Processing History:**
```sql
SELECT TOP 20
    START_TIME,
    END_TIME,
    RECORDS_PROCESSED,
    SUCCESS,
    ERROR_MESSAGE
FROM dbo.USER_SYNC_LOG
WHERE OPERATION_TYPE = 'order_processing'
ORDER BY START_TIME DESC;
```

### **Check Recent Orders Created:**
```sql
SELECT TOP 20
    h.TKT_NO,
    h.CUST_NO,
    h.TKT_DT,
    h.TOT_AMT,
    s.WOO_ORDER_ID
FROM dbo.PS_DOC_HDR h
INNER JOIN dbo.USER_ORDER_STAGING s ON s.CP_DOC_ID = CAST(h.DOC_ID AS VARCHAR(15))
WHERE h.TKT_DT >= DATEADD(DAY, -1, GETDATE())
ORDER BY h.TKT_DT DESC;
```

---

## 🚨 **EMERGENCY PROCEDURES**

### **System Down - Manual Processing**

If automated processing is down:

1. **Process Orders Manually:**
   ```powershell
   python cp_order_processor.py process --all
   ```

2. **Monitor Progress:**
   ```powershell
   python cp_order_processor.py list
   ```

3. **Check Results:**
   ```sql
   SELECT COUNT(*) FROM dbo.USER_ORDER_STAGING WHERE IS_APPLIED = 0;
   ```

---

### **Data Corruption - Rollback**

If wrong orders were created:

1. **See:** `ROLLBACK_PROCEDURES.md`
2. **Identify affected orders**
3. **Rollback inventory updates**
4. **Delete orders from CounterPoint**
5. **Reset staging records**

---

## 📞 **CONTACT INFORMATION**

**For Issues:**
- **Database Issues:** [Database Admin]
- **CounterPoint Issues:** [CP Admin]
- **WooCommerce Issues:** [WooCommerce Admin]
- **System Issues:** [System Admin]

**Escalation:**
- **Low Priority:** Email within 24 hours
- **Medium Priority:** Email within 4 hours
- **High Priority:** Call immediately

---

## 📝 **LOG LOCATIONS**

- **Python Logs:** `logs/woo_order_processing_*.log`
- **PowerShell Logs:** `logs/woo_order_processing_*.log`
- **SQL Logs:** Check `USER_SYNC_LOG` table
- **Task Scheduler Logs:** Windows Event Viewer

---

## ✅ **WEEKLY MAINTENANCE**

1. **Review Failed Orders:**
   ```sql
   -- Run: 01_Production/FIND_FAILED_ORDERS.sql
   ```

2. **Clean Up Old Logs:**
   ```powershell
   # Delete logs older than 30 days
   Get-ChildItem "logs\*.log" | 
       Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-30)} | 
       Remove-Item
   ```

3. **Review Processing Performance:**
   ```sql
   SELECT 
       AVG(DATEDIFF(SECOND, START_TIME, END_TIME)) AS AvgProcessingTimeSeconds,
       MAX(DATEDIFF(SECOND, START_TIME, END_TIME)) AS MaxProcessingTimeSeconds,
       COUNT(*) AS TotalRuns
   FROM dbo.USER_SYNC_LOG
   WHERE OPERATION_TYPE = 'order_processing'
     AND START_TIME >= DATEADD(DAY, -7, GETDATE());
   ```

---

**Last Updated:** January 2, 2026  
**Status:** ✅ **READY FOR USE**

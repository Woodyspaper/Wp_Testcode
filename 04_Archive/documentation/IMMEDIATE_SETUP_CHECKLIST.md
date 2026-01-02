# Immediate Setup Checklist - Scheduled Jobs

**Date:** December 30, 2025  
**Time:** ~10 minutes  
**Status:** Ready to execute

---

## ✅ **PREREQUISITES CHECK**

Before running the SQL script, verify:

- [ ] **SQL Server Agent is running**
  - Check in SSMS: SQL Server Agent should be green/running
  - If not: Right-click → Start

- [ ] **Python is accessible**
  - Path detected: `C:\Program Files\Python314\python.exe`
  - Script updated automatically ✅

- [ ] **Script paths are correct**
  - Customer script: `woo_customers.py` ✅
  - Order script: `woo_orders.py` ✅
  - Both in project root ✅

- [ ] **WooCommerce API credentials configured**
  - Check `.env` file has:
    - `WOO_BASE_URL`
    - `WOO_CONSUMER_KEY`
    - `WOO_CONSUMER_SECRET`

---

## 📋 **EXECUTION STEPS**

### **Step 1: Open SQL Server Management Studio**

1. Connect to your SQL Server instance
2. **IMPORTANT:** Ensure you're connected to the correct server (not test server)

---

### **Step 2: Run SQL Script**

1. **Open:** `01_Production/create_sync_jobs_complete.sql`
2. **Review:** Check Python paths (should be auto-updated)
3. **Execute:** Press F5 or click Execute
4. **Wait:** Script will create both jobs
5. **Check:** Look for success messages in Messages pane

**Expected Output:**
```
CUSTOMER SYNC JOB CREATED
ORDER SYNC JOB CREATED
SCHEDULED JOBS SETUP COMPLETE
```

---

### **Step 3: Verify Jobs Created**

**In SQL Server Management Studio:**

1. **Expand:** SQL Server Agent → Jobs
2. **Verify:** Two jobs exist:
   - ✅ `WP_WooCommerce_Customer_Sync`
   - ✅ `WP_WooCommerce_Order_Sync`
3. **Check:** Both should show green checkmark (enabled)

**Or verify with SQL:**
```sql
SELECT 
    name AS JobName,
    enabled AS IsEnabled,
    date_modified AS LastModified
FROM msdb.dbo.sysjobs
WHERE name LIKE 'WP_WooCommerce%';
```

---

### **Step 4: Test Jobs Manually**

**Test Customer Sync:**

1. **Right-click:** `WP_WooCommerce_Customer_Sync`
2. **Select:** "Start Job at Step..."
3. **Choose:** Step 1 (Pull Customers)
4. **Monitor:** 
   - Open **Job Activity Monitor** (View → Job Activity Monitor)
   - Watch job execution
5. **Check:** Job History for errors

**Test Order Sync:**

1. **Right-click:** `WP_WooCommerce_Order_Sync`
2. **Select:** "Start Job at Step..."
3. **Monitor:** Job execution
4. **Check:** Job History for errors

**Or test with SQL:**
```sql
-- Test customer sync
EXEC msdb.dbo.sp_start_job @job_name = 'WP_WooCommerce_Customer_Sync';

-- Wait a moment, then check status
SELECT 
    j.name AS JobName,
    h.run_date,
    h.run_time,
    CASE h.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
    END AS Status,
    h.message
FROM msdb.dbo.sysjobhistory h
INNER JOIN msdb.dbo.sysjobs j ON j.job_id = h.job_id
WHERE j.name = 'WP_WooCommerce_Customer_Sync'
ORDER BY h.run_date DESC, h.run_time DESC;
```

---

### **Step 5: Verify Data in Staging Tables**

**Check Customer Staging:**
```sql
-- Check if customers were staged
SELECT TOP 10 
    STAGING_ID, 
    EMAIL_ADRS_1, 
    NAM, 
    IS_VALIDATED, 
    IS_APPLIED,
    VALIDATION_ERROR,
    CREATED_DT
FROM dbo.USER_CUSTOMER_STAGING
ORDER BY CREATED_DT DESC;
```

**Check Order Staging:**
```sql
-- Check if orders were staged
SELECT TOP 10 
    STAGING_ID, 
    WOO_ORDER_ID, 
    CUST_NO, 
    TOT_AMT, 
    IS_VALIDATED, 
    IS_APPLIED,
    VALIDATION_ERROR,
    CREATED_DT
FROM dbo.USER_ORDER_STAGING
ORDER BY CREATED_DT DESC;
```

---

## ⚠️ **TROUBLESHOOTING**

### **Issue: SQL Server Agent Not Running**

**Error:** "SQL Server Agent is not running"

**Fix:**
1. Right-click **SQL Server Agent** → **Start**
2. Right-click **SQL Server Agent** → **Properties**
3. Set **Start Mode** to **Automatic**
4. Retry job creation

---

### **Issue: Python Not Found**

**Error:** "Python is not recognized as an internal or external command"

**Fix:**
1. Find Python path: `where.exe python` in PowerShell
2. Edit SQL script, update job step command:
   ```sql
   @command = N'"C:\Program Files\Python314\python.exe" "C:\Users\...\woo_customers.py" pull --apply',
   ```
   (Use full absolute path)

---

### **Issue: Script Path Not Found**

**Error:** "The system cannot find the path specified"

**Fix:**
1. Verify script paths in job steps
2. Update paths if scripts moved
3. Use full absolute paths (not relative)

---

### **Issue: Job Runs But No Data**

**Check:**
1. Verify WooCommerce API credentials in `.env`
2. Check if there are new customers/orders to sync
3. Review job history for errors
4. Check staging tables for validation errors

---

## 📊 **WHAT HAPPENS AFTER SETUP**

### **Customer Sync (Daily at 2:00 AM):**
- ✅ Pulls new customers from WooCommerce
- ✅ Stages in `USER_CUSTOMER_STAGING`
- ✅ Validates customers (preflight)
- ✅ Creates valid customers in `AR_CUST`
- ✅ Logs results

### **Order Sync (Every 5 minutes):**
- ✅ Pulls new orders from WooCommerce (last 24 hours)
- ✅ Stages in `USER_ORDER_STAGING`
- ✅ Validates orders
- ⚠️ **Note:** Orders are staged only (Phase 5 not implemented yet)

---

## ✅ **VERIFICATION CHECKLIST**

After setup, verify:

- [ ] SQL Server Agent is running
- [ ] Both jobs created successfully
- [ ] Jobs are enabled (green checkmark)
- [ ] Schedules are correct:
  - [ ] Customer sync: Daily at 2:00 AM
  - [ ] Order sync: Every 5 minutes
- [ ] Test run customer sync job manually
- [ ] Test run order sync job manually
- [ ] Check job history for errors
- [ ] Verify data in staging tables
- [ ] Monitor first scheduled run

---

## 🎯 **NEXT STEPS AFTER SETUP**

1. **Monitor first runs:**
   - Check job history after first scheduled run
   - Verify data in staging tables
   - Check for errors

2. **Set up alerts (optional):**
   - Create alerts for job failures
   - Set up email notifications

3. **Implement Phase 5 (future):**
   - Order creation in CounterPoint
   - Sales ticket creation
   - Inventory updates

---

## 📝 **IMPORTANT NOTES**

1. **Orders are staged only** - They won't automatically create in CounterPoint yet (Phase 5 needed)
2. **Customer sync is daily** - New customers won't appear in CP until next sync (or manual run)
3. **Monitor first runs** - Check job history to ensure no errors
4. **Python paths** - Script auto-updated with detected Python path ✅

---

**Last Updated:** December 30, 2025

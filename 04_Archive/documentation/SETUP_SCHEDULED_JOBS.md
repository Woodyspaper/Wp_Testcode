# Setup Scheduled Jobs - Step by Step

**Date:** December 30, 2025  
**Purpose:** Set up automated customer and order sync jobs

---

## ⚠️ **PREREQUISITES**

### **1. SQL Server Agent Must Be Running**

**Check Status:**
```sql
-- Check if SQL Server Agent is running
SELECT 
    servicename AS ServiceName,
    status_desc AS Status
FROM sys.dm_server_services
WHERE servicename LIKE '%SQL Server Agent%';
```

**If Not Running:**
1. Open **SQL Server Configuration Manager**
2. Go to **SQL Server Services**
3. Right-click **SQL Server Agent** → **Start**
4. Set **Start Mode** to **Automatic** (so it starts on reboot)

---

### **2. Verify Python Path**

**Check Python Installation:**
```powershell
# Test Python path
python --version
where.exe python
```

**Common Python Paths:**
- `C:\Program Files\Python314\python.exe`
- `C:\Python314\python.exe`
- `C:\Users\Administrator.ADWPC-MAIN\AppData\Local\Programs\Python\Python314\python.exe`

**Update Script Path:**
- Edit `01_Production/create_sync_jobs_complete.sql`
- Update Python path in job steps if needed

---

### **3. Verify Script Paths**

**Check Script Locations:**
- `woo_customers.py` - Should be in project root
- `woo_orders.py` - Should be in project root

**Update if Different:**
- Edit `01_Production/create_sync_jobs_complete.sql`
- Update paths in job steps

---

## 📋 **SETUP STEPS**

### **Step 1: Run SQL Script**

**In SQL Server Management Studio:**

1. **Open:** `01_Production/create_sync_jobs_complete.sql`
2. **Verify:** You're connected to the correct SQL Server instance
3. **Run:** Execute the entire script
4. **Check:** Look for success messages

**Expected Output:**
```
CUSTOMER SYNC JOB CREATED
ORDER SYNC JOB CREATED
SCHEDULED JOBS SETUP COMPLETE
```

---

### **Step 2: Verify Jobs Created**

**In SQL Server Management Studio:**

1. **Expand:** SQL Server Agent → Jobs
2. **Verify:** Two jobs exist:
   - `WP_WooCommerce_Customer_Sync`
   - `WP_WooCommerce_Order_Sync`
3. **Check:** Both jobs should be enabled (green checkmark)

---

### **Step 3: Test Jobs Manually**

**Test Customer Sync Job:**

1. **Right-click:** `WP_WooCommerce_Customer_Sync`
2. **Select:** "Start Job at Step..."
3. **Choose:** Step 1 (Pull Customers)
4. **Monitor:** Job execution in Job Activity Monitor
5. **Check:** Job history for errors

**Test Order Sync Job:**

1. **Right-click:** `WP_WooCommerce_Order_Sync`
2. **Select:** "Start Job at Step..."
3. **Monitor:** Job execution
4. **Check:** Job history for errors

**Or Use SQL:**
```sql
-- Test customer sync job
EXEC msdb.dbo.sp_start_job @job_name = 'WP_WooCommerce_Customer_Sync';

-- Test order sync job
EXEC msdb.dbo.sp_start_job @job_name = 'WP_WooCommerce_Order_Sync';
```

---

### **Step 4: Verify Job Execution**

**Check Job History:**

1. **Right-click:** Job → **View History**
2. **Check:** 
   - Job ran successfully
   - No errors in log
   - Steps completed

**Check Staging Tables:**

```sql
-- Check customer staging
SELECT TOP 10 
    STAGING_ID, 
    EMAIL_ADRS_1, 
    NAM, 
    IS_VALIDATED, 
    IS_APPLIED,
    VALIDATION_ERROR
FROM dbo.USER_CUSTOMER_STAGING
ORDER BY CREATED_DT DESC;

-- Check order staging
SELECT TOP 10 
    STAGING_ID, 
    WOO_ORDER_ID, 
    CUST_NO, 
    TOT_AMT, 
    IS_VALIDATED, 
    IS_APPLIED,
    VALIDATION_ERROR
FROM dbo.USER_ORDER_STAGING
ORDER BY CREATED_DT DESC;
```

---

### **Step 5: Monitor Jobs**

**Set Up Alerts (Optional):**

1. **Right-click:** SQL Server Agent → **Alerts**
2. **Create Alert:** For job failures
3. **Configure:** Email notifications (if email configured)

**Check Job Status Regularly:**

```sql
-- Check job status
SELECT 
    name AS JobName,
    enabled AS IsEnabled,
    date_modified AS LastModified
FROM msdb.dbo.sysjobs
WHERE name LIKE 'WP_WooCommerce%';

-- Check recent job executions
SELECT 
    j.name AS JobName,
    h.run_date,
    h.run_time,
    h.run_status,
    h.message
FROM msdb.dbo.sysjobhistory h
INNER JOIN msdb.dbo.sysjobs j ON j.job_id = h.job_id
WHERE j.name LIKE 'WP_WooCommerce%'
ORDER BY h.run_date DESC, h.run_time DESC;
```

---

## 🔧 **TROUBLESHOOTING**

### **Issue 1: SQL Server Agent Not Running**

**Error:** "SQL Server Agent is not running"

**Fix:**
1. Start SQL Server Agent service
2. Set to automatic start
3. Retry job creation

---

### **Issue 2: Python Not Found**

**Error:** "Python is not recognized as an internal or external command"

**Fix:**
1. Find Python path: `where.exe python`
2. Update job step command with full path:
   ```
   "C:\Program Files\Python314\python.exe" "C:\Users\...\woo_customers.py" pull --apply
   ```

---

### **Issue 3: Script Path Not Found**

**Error:** "The system cannot find the path specified"

**Fix:**
1. Verify script paths in job steps
2. Update paths if scripts moved
3. Use full absolute paths

---

### **Issue 4: Job Runs But No Data**

**Check:**
1. Verify WooCommerce API credentials in `.env`
2. Check if there are new customers/orders to sync
3. Review job history for errors
4. Check staging tables for validation errors

---

### **Issue 5: Job Fails with Permission Error**

**Error:** "Permission denied" or "Access denied"

**Fix:**
1. Ensure SQL Server Agent service account has:
   - Read access to script files
   - Execute permission for Python
   - Network access to WooCommerce API
2. Consider running as specific service account

---

## 📊 **JOB SCHEDULES**

### **Customer Sync Job:**
- **Frequency:** Daily
- **Time:** 2:00 AM
- **Why:** Customers don't change frequently, daily is sufficient

### **Order Sync Job:**
- **Frequency:** Every 5 minutes
- **Time:** 24/7
- **Why:** Orders need to be synced quickly for fulfillment

**To Modify Schedules:**
1. Right-click job → **Properties**
2. Go to **Schedules** tab
3. Edit or add new schedule
4. Click **OK**

---

## ✅ **VERIFICATION CHECKLIST**

After setup, verify:

- [ ] SQL Server Agent is running
- [ ] Both jobs created successfully
- [ ] Jobs are enabled
- [ ] Schedules are correct
- [ ] Test run customer sync job manually
- [ ] Test run order sync job manually
- [ ] Check job history for errors
- [ ] Verify data in staging tables
- [ ] Monitor first scheduled run

---

## 🎯 **EXPECTED BEHAVIOR**

### **Customer Sync (Daily at 2 AM):**
1. Pulls new customers from WooCommerce
2. Stages in `USER_CUSTOMER_STAGING`
3. Validates customers
4. Creates valid customers in `AR_CUST`
5. Logs results

### **Order Sync (Every 5 minutes):**
1. Pulls new orders from WooCommerce (last 24 hours)
2. Stages in `USER_ORDER_STAGING`
3. Validates orders
4. **Note:** Orders are staged only (Phase 5 not implemented yet)

---

## 📝 **NEXT STEPS**

After scheduled jobs are set up:

1. **Monitor first runs:**
   - Check job history
   - Verify data in staging tables
   - Check for errors

2. **Set up monitoring:**
   - Create alerts for job failures
   - Set up email notifications (optional)

3. **Implement Phase 5:**
   - Order creation in CounterPoint
   - Sales ticket creation
   - Inventory updates

---

**Last Updated:** December 30, 2025

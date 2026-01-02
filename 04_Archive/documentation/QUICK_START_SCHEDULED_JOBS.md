# Quick Start - Scheduled Jobs Setup

**Date:** December 30, 2025  
**Time:** ~10 minutes

---

## 🚀 **QUICK SETUP (3 Steps)**

### **Step 1: Verify SQL Server Agent is Running**

**In SQL Server Management Studio:**
1. Right-click **SQL Server Agent** → **Start** (if not running)
2. Right-click **SQL Server Agent** → **Properties** → Set **Start Mode** to **Automatic**

**Or check with SQL:**
```sql
SELECT 
    servicename AS ServiceName,
    status_desc AS Status
FROM sys.dm_server_services
WHERE servicename LIKE '%SQL Server Agent%';
```

---

### **Step 2: Run SQL Script**

**In SQL Server Management Studio:**
1. Open: `01_Production/create_sync_jobs_complete.sql`
2. **IMPORTANT:** Update Python path if needed (see below)
3. Execute the script
4. Look for success messages

**Update Python Path (if needed):**
- Find your Python path: `where.exe python` in PowerShell
- Edit the SQL script, replace:
  ```
  python.exe "C:\Users\...\woo_customers.py"
  ```
  With:
  ```
  "C:\Your\Python\Path\python.exe" "C:\Your\Script\Path\woo_customers.py"
  ```

---

### **Step 3: Verify Jobs Created**

**In SQL Server Management Studio:**
1. Expand: **SQL Server Agent** → **Jobs**
2. Verify two jobs exist:
   - ✅ `WP_WooCommerce_Customer_Sync`
   - ✅ `WP_WooCommerce_Order_Sync`
3. Both should be **enabled** (green checkmark)

**Test manually:**
- Right-click job → **Start Job at Step...**
- Check **Job Activity Monitor** for execution
- Review **Job History** for errors

---

## ✅ **VERIFICATION**

**Check jobs are working:**
```sql
-- Check job status
SELECT 
    name AS JobName,
    enabled AS IsEnabled
FROM msdb.dbo.sysjobs
WHERE name LIKE 'WP_WooCommerce%';

-- Check recent executions
SELECT TOP 10
    j.name AS JobName,
    h.run_date,
    h.run_time,
    CASE h.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
    END AS Status
FROM msdb.dbo.sysjobhistory h
INNER JOIN msdb.dbo.sysjobs j ON j.job_id = h.job_id
WHERE j.name LIKE 'WP_WooCommerce%'
ORDER BY h.run_date DESC, h.run_time DESC;
```

---

## 📋 **WHAT HAPPENS NOW**

### **Customer Sync (Daily at 2 AM):**
- ✅ Pulls new customers from WooCommerce
- ✅ Stages in `USER_CUSTOMER_STAGING`
- ✅ Validates customers
- ✅ Creates valid customers in `AR_CUST`

### **Order Sync (Every 5 minutes):**
- ✅ Pulls new orders from WooCommerce
- ✅ Stages in `USER_ORDER_STAGING`
- ⚠️ **Note:** Orders are staged only (Phase 5 not implemented yet)

---

## ⚠️ **IMPORTANT NOTES**

1. **Orders are staged only** - They won't automatically create in CounterPoint yet (Phase 5 needed)
2. **Customer sync is daily** - New customers won't appear in CP until next sync (or manual run)
3. **Monitor first runs** - Check job history to ensure no errors

---

## 🔧 **TROUBLESHOOTING**

**Job fails with "Python not found":**
- Update Python path in job step
- Use full absolute path

**Job runs but no data:**
- Check WooCommerce API credentials in `.env`
- Verify there are new customers/orders to sync
- Check staging tables for validation errors

**SQL Server Agent not running:**
- Start SQL Server Agent service
- Set to automatic start

---

**See `SETUP_SCHEDULED_JOBS.md` for detailed troubleshooting**

---

**Last Updated:** December 30, 2025

-- ============================================
-- QUICK REFERENCE QUERIES
-- Save this file - useful queries for daily use
-- ============================================

USE WOODYS_CP;  -- Change to CPPractice if testing
GO

-- ============================================
-- PREFLIGHT VALIDATION
-- ============================================

-- Validate all records in staging
EXEC dbo.usp_Preflight_Validate_Customer_Staging;

-- Validate specific batch
EXEC dbo.usp_Preflight_Validate_Customer_Staging @BatchID = 'YOUR_BATCH_ID';

-- Validate specific staging record
EXEC dbo.usp_Preflight_Validate_Customer_Staging @StagingID = 123;

-- ============================================
-- CREATE CUSTOMERS
-- ============================================

-- Create customers from staging (after validation passes)
EXEC dbo.usp_Create_Customers_From_Staging @BatchID = 'YOUR_BATCH_ID';

-- ============================================
-- CHECK STAGING DATA
-- ============================================

-- View all staging records
SELECT TOP 100
    STAGING_ID,
    BATCH_ID,
    CUST_NO,
    NAM,
    EMAIL_ADRS_1,
    PROF_COD_1,
    CUST_NAM_TYP,
    CREAT_DAT
FROM dbo.USER_CUSTOMER_STAGING
ORDER BY CREAT_DAT DESC;

-- Count records by batch
SELECT 
    BATCH_ID,
    COUNT(*) AS RecordCount,
    MIN(CREAT_DAT) AS FirstRecord,
    MAX(CREAT_DAT) AS LastRecord
FROM dbo.USER_CUSTOMER_STAGING
GROUP BY BATCH_ID
ORDER BY MAX(CREAT_DAT) DESC;

-- ============================================
-- CHECK SYNC LOG
-- ============================================

-- Recent sync activity
SELECT TOP 20
    START_TIME AS SYNC_DAT,
    SYNC_ID AS BATCH_ID,
    OPERATION_TYPE AS ENTITY_TYP,
    DIRECTION AS ACTION_TYP,
    CASE WHEN SUCCESS = 1 THEN 'SUCCESS' ELSE 'FAILED' END AS STATUS,
    RECORDS_CREATED + RECORDS_UPDATED AS RECORDS_PROCESSED,
    RECORDS_FAILED,
    ERROR_MESSAGE AS ERROR_MSG
FROM dbo.USER_SYNC_LOG
ORDER BY START_TIME DESC;

-- Sync summary by batch
SELECT 
    SYNC_ID AS BATCH_ID,
    COUNT(*) AS SyncCount,
    SUM(CASE WHEN SUCCESS = 1 THEN 1 ELSE 0 END) AS SuccessCount,
    SUM(CASE WHEN SUCCESS = 0 THEN 1 ELSE 0 END) AS FailedCount,
    SUM(RECORDS_CREATED + RECORDS_UPDATED) AS TotalProcessed,
    SUM(RECORDS_FAILED) AS TotalFailed
FROM dbo.USER_SYNC_LOG
GROUP BY SYNC_ID
ORDER BY MAX(START_TIME) DESC;

-- ============================================
-- CHECK CUSTOMER MAPPING
-- ============================================

-- View all customer mappings
SELECT 
    CUST_NO AS CP_CUST_NO,
    WOO_USER_ID AS WOO_CUSTOMER_ID,
    WOO_EMAIL,
    CREATED_DT AS MAP_DAT,
    UPDATED_DT AS LAST_SYNC_DAT
FROM dbo.USER_CUSTOMER_MAP
ORDER BY CREATED_DT DESC;

-- Find mapping by WooCommerce ID
SELECT 
    CUST_NO AS CP_CUST_NO,
    WOO_USER_ID AS WOO_CUSTOMER_ID,
    WOO_EMAIL,
    CREATED_DT AS MAP_DAT
FROM dbo.USER_CUSTOMER_MAP
WHERE WOO_USER_ID = 123;  -- Replace with actual WooCommerce ID

-- Find mapping by CounterPoint customer number
SELECT 
    CUST_NO AS CP_CUST_NO,
    WOO_USER_ID AS WOO_CUSTOMER_ID,
    WOO_EMAIL,
    CREATED_DT AS MAP_DAT
FROM dbo.USER_CUSTOMER_MAP
WHERE CUST_NO = 'CUST001';  -- Replace with actual CP customer number

-- ============================================
-- CHECK CREATED CUSTOMERS
-- ============================================

-- Find recently maintained customers
SELECT TOP 50
    CUST_NO,
    NAM,
    EMAIL_ADRS_1,
    PROF_COD_1,
    CATEG_COD,
    LST_MAINT_DT AS CREAT_DAT
FROM dbo.AR_CUST
WHERE LST_MAINT_DT >= DATEADD(day, -7, GETDATE())  -- Last 7 days
ORDER BY LST_MAINT_DT DESC;

-- Find customer by email
SELECT 
    CUST_NO,
    NAM,
    EMAIL_ADRS_1,
    PROF_COD_1,
    LST_MAINT_DT AS CREAT_DAT
FROM dbo.AR_CUST
WHERE EMAIL_ADRS_1 = 'customer@example.com';

-- ============================================
-- CLEANUP (Use with caution!)
-- ============================================

-- Delete test staging records
-- DELETE FROM dbo.USER_CUSTOMER_STAGING WHERE BATCH_ID LIKE 'TEST_BATCH%';

-- Delete test customers (be careful!)
-- DELETE FROM dbo.AR_CUST WHERE CUST_NO IN ('TEST001', 'TEST002');
-- DELETE FROM dbo.USER_CUSTOMER_MAP WHERE CP_CUST_NO IN ('TEST001', 'TEST002');


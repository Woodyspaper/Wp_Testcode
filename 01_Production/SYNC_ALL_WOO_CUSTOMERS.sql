-- ============================================
-- SYNC ALL WOOCOMMERCE CUSTOMERS TO COUNTERPOINT
-- ============================================
-- This script guides you through syncing all WooCommerce customers
-- to CounterPoint, skipping those already in CP.
--
-- Prerequisites:
--   1. Run Python script: python woo_customers.py pull --apply
--   2. This will load all WooCommerce customers into USER_CUSTOMER_STAGING
-- ============================================

USE WOODYS_CP;
GO

-- ============================================
-- STEP 1: Check what's in staging
-- ============================================
PRINT '============================================';
PRINT 'STEP 1: Checking Staging Data';
PRINT '============================================';

-- Find the latest batch ID (prefer WooCommerce batches over test batches)
DECLARE @LatestBatchID VARCHAR(50);
SELECT TOP 1 @LatestBatchID = BATCH_ID
FROM dbo.USER_CUSTOMER_STAGING
WHERE BATCH_ID LIKE 'WOO_PULL_%'  -- Prefer WooCommerce batches
ORDER BY STAGING_ID DESC;

-- If no WooCommerce batch found, get any latest batch
IF @LatestBatchID IS NULL
BEGIN
    SELECT TOP 1 @LatestBatchID = BATCH_ID
    FROM dbo.USER_CUSTOMER_STAGING
    ORDER BY STAGING_ID DESC;
END

IF @LatestBatchID IS NULL
BEGIN
    PRINT '❌ No staging data found!';
    PRINT '';
    PRINT 'Run this first:';
    PRINT '  python woo_customers.py pull --apply';
    PRINT '';
    PRINT 'This will load all WooCommerce customers into USER_CUSTOMER_STAGING';
    RETURN;
END

PRINT 'Latest batch ID: ' + @LatestBatchID;
PRINT '';

-- Count records by status
SELECT 
    COUNT(*) AS TotalRecords,
    SUM(CASE WHEN IS_APPLIED = 1 THEN 1 ELSE 0 END) AS AlreadyProcessed,
    SUM(CASE WHEN IS_APPLIED = 0 AND CUST_NO IS NULL THEN 1 ELSE 0 END) AS ReadyToProcess,
    SUM(CASE WHEN CUST_NO IS NOT NULL THEN 1 ELSE 0 END) AS AlreadyInCP
FROM dbo.USER_CUSTOMER_STAGING
WHERE BATCH_ID = @LatestBatchID;

PRINT '';
GO

-- ============================================
-- STEP 2: Preview customers to be created
-- ============================================
PRINT '============================================';
PRINT 'STEP 2: Preview Customers to Create';
PRINT '============================================';

DECLARE @LatestBatchID VARCHAR(50);
SELECT TOP 1 @LatestBatchID = BATCH_ID
FROM dbo.USER_CUSTOMER_STAGING
ORDER BY STAGING_ID DESC;

SELECT TOP 20
    STAGING_ID,
    BATCH_ID,
    WOO_USER_ID,
    EMAIL_ADRS_1,
    NAM,
    CITY,
    STATE,
    ZIP_COD,
    PROF_COD_1,
    CATEG_COD,
    IS_APPLIED,
    CUST_NO
FROM dbo.USER_CUSTOMER_STAGING
WHERE BATCH_ID = @LatestBatchID
  AND IS_APPLIED = 0
  AND CUST_NO IS NULL
ORDER BY STAGING_ID;

PRINT '';
PRINT 'Showing first 20 records. Check all records with:';
PRINT '  SELECT * FROM USER_CUSTOMER_STAGING WHERE BATCH_ID = ''' + @LatestBatchID + '''';
PRINT '';
GO

-- ============================================
-- STEP 3: Run Preflight Validation
-- ============================================
PRINT '============================================';
PRINT 'STEP 3: Preflight Validation';
PRINT '============================================';
PRINT 'Running preflight validation...';
PRINT '';

DECLARE @LatestBatchID VARCHAR(50);
SELECT TOP 1 @LatestBatchID = BATCH_ID
FROM dbo.USER_CUSTOMER_STAGING
ORDER BY STAGING_ID DESC;

EXEC dbo.usp_Preflight_Validate_Customer_Staging @BatchID = @LatestBatchID;

PRINT '';
PRINT 'If validation PASSED, proceed to Step 4';
PRINT 'If validation FAILED, fix the errors and re-run validation';
PRINT '';
GO

-- ============================================
-- STEP 4: Create Customers (DRY RUN FIRST!)
-- ============================================
PRINT '============================================';
PRINT 'STEP 4: Create Customers in CounterPoint';
PRINT '============================================';
PRINT '';
PRINT '⚠️  IMPORTANT: Run with @DryRun = 1 first to preview!';
PRINT '';

DECLARE @LatestBatchID VARCHAR(50);
SELECT TOP 1 @LatestBatchID = BATCH_ID
FROM dbo.USER_CUSTOMER_STAGING
ORDER BY STAGING_ID DESC;

PRINT 'DRY RUN (preview only - no changes):';
PRINT '  EXEC dbo.usp_Create_Customers_From_Staging @BatchID = ''' + @LatestBatchID + ''', @DryRun = 1;';
PRINT '';
PRINT 'LIVE RUN (creates customers):';
PRINT '  EXEC dbo.usp_Create_Customers_From_Staging @BatchID = ''' + @LatestBatchID + ''', @DryRun = 0;';
PRINT '';
GO

-- ============================================
-- STEP 5: Verify Results
-- ============================================
PRINT '============================================';
PRINT 'STEP 5: Verify Results (After Creation)';
PRINT '============================================';
PRINT '';

DECLARE @LatestBatchID VARCHAR(50);
SELECT TOP 1 @LatestBatchID = BATCH_ID
FROM dbo.USER_CUSTOMER_STAGING
ORDER BY STAGING_ID DESC;

-- Count created customers
SELECT 
    COUNT(*) AS TotalCreated,
    SUM(CASE WHEN WOO_USER_ID IS NOT NULL THEN 1 ELSE 0 END) AS WithWooMapping,
    SUM(CASE WHEN WOO_USER_ID IS NULL THEN 1 ELSE 0 END) AS GuestCheckouts
FROM dbo.USER_CUSTOMER_STAGING
WHERE BATCH_ID = @LatestBatchID
  AND IS_APPLIED = 1
  AND CUST_NO IS NOT NULL;

PRINT '';
PRINT 'Check customer mappings:';
PRINT '  SELECT * FROM USER_CUSTOMER_MAP WHERE CUST_NO IN (';
PRINT '    SELECT CUST_NO FROM USER_CUSTOMER_STAGING WHERE BATCH_ID = ''' + @LatestBatchID + '''';
PRINT '  );';
PRINT '';
GO


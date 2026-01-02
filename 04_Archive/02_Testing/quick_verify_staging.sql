-- ============================================
-- Quick Verify Staging - Latest Batch
-- Run this to check the most recent staging batch
-- ============================================

USE WOODYS_CP;  -- Change to WOODYS_CP when ready for production
GO

-- Get latest batch ID automatically
DECLARE @BatchID VARCHAR(50);
SELECT TOP 1 @BatchID = BATCH_ID
FROM dbo.USER_CUSTOMER_STAGING
ORDER BY STAGING_ID DESC;

PRINT '============================================================';
PRINT 'Quick Verify Staging';
PRINT 'Latest Batch ID: ' + ISNULL(@BatchID, '(No batches found)');
PRINT '============================================================';
PRINT '';

IF @BatchID IS NULL
BEGIN
    PRINT '❌ No staging data found!';
    PRINT 'Run: python woo_customers.py pull --apply';
    RETURN;
END

-- Summary
SELECT 
    COUNT(*) AS TotalRecords,
    SUM(CASE WHEN WOO_USER_ID > 0 THEN 1 ELSE 0 END) AS RegisteredCustomers,
    SUM(CASE WHEN WOO_USER_ID < 0 THEN 1 ELSE 0 END) AS GuestCheckouts,
    SUM(CASE WHEN IS_APPLIED = 1 THEN 1 ELSE 0 END) AS AlreadyProcessed,
    SUM(CASE WHEN IS_APPLIED = 0 THEN 1 ELSE 0 END) AS ReadyToProcess
FROM dbo.USER_CUSTOMER_STAGING
WHERE BATCH_ID = @BatchID;
GO

-- Preview
PRINT '';
PRINT 'Preview (First 5 records):';
SELECT TOP 5
    STAGING_ID,
    EMAIL_ADRS_1,
    NAM,
    CITY,
    STATE,
    ZIP_COD,
    PROF_COD_1
FROM dbo.USER_CUSTOMER_STAGING
WHERE BATCH_ID = @BatchID
ORDER BY STAGING_ID;
GO

-- Run validation
PRINT '';
PRINT '============================================================';
PRINT 'Running Preflight Validation...';
PRINT '============================================================';
PRINT '';

DECLARE @BatchID VARCHAR(50);
SELECT TOP 1 @BatchID = BATCH_ID
FROM dbo.USER_CUSTOMER_STAGING
ORDER BY STAGING_ID DESC;

EXEC dbo.usp_Preflight_Validate_Customer_Staging @BatchID = @BatchID;
GO

PRINT '';
PRINT '============================================================';
PRINT 'Next Steps:';
PRINT '============================================================';
PRINT 'If validation PASSED:';
PRINT '  1. Test dry-run: EXEC dbo.usp_Create_Customers_From_Staging @BatchID = ''WOO_PULL_20251223_112613'', @DryRun = 1;';
PRINT '  2. Create 1-2 test customers (see test_create_one_customer.sql)';
PRINT '';
PRINT 'If validation FAILED:';
PRINT '  Run: SELECT * FROM USER_CUSTOMER_STAGING WHERE BATCH_ID = ''WOO_PULL_20251223_112613'' AND VALIDATION_ERROR IS NOT NULL;';
PRINT '  Fix errors shown above, then re-run validation';
PRINT '============================================================';
GO


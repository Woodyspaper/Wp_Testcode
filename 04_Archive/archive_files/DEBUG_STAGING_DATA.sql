-- ============================================
-- Debug Staging Data
-- Check what's in the staging table and why it's not being processed
-- ============================================

USE WOODYS_CP;  -- Change to CPPractice if testing
GO

PRINT '============================================';
PRINT 'DEBUGGING STAGING DATA';
PRINT '============================================';
PRINT '';

-- Check what's in staging
PRINT '1. All records in USER_CUSTOMER_STAGING:';
SELECT 
    STAGING_ID,
    BATCH_ID,
    CUST_NO,
    NAM,
    EMAIL_ADRS_1,
    CUST_NAM_TYP,
    PROF_COD_1,
    WOO_USER_ID,
    ACTION_TAKEN,
    CREAT_DAT
FROM dbo.USER_CUSTOMER_STAGING
WHERE BATCH_ID = 'TEST_BATCH_001'
ORDER BY STAGING_ID;
GO

PRINT '';
PRINT '2. Checking for records with TEST_BATCH_001:';
SELECT COUNT(*) AS RecordCount
FROM dbo.USER_CUSTOMER_STAGING
WHERE BATCH_ID = 'TEST_BATCH_001';
GO

PRINT '';
PRINT '3. Checking ACTION_TAKEN values (procedure filters on this):';
SELECT 
    ACTION_TAKEN,
    COUNT(*) AS Count
FROM dbo.USER_CUSTOMER_STAGING
WHERE BATCH_ID = 'TEST_BATCH_001'
GROUP BY ACTION_TAKEN;
GO

PRINT '';
PRINT '4. Records that would be processed (ACTION_TAKEN = NULL or empty):';
SELECT 
    STAGING_ID,
    BATCH_ID,
    CUST_NO,
    NAM,
    EMAIL_ADRS_1,
    ACTION_TAKEN
FROM dbo.USER_CUSTOMER_STAGING
WHERE BATCH_ID = 'TEST_BATCH_001'
  AND (ACTION_TAKEN IS NULL OR ACTION_TAKEN = '');
GO

PRINT '';
PRINT '============================================';
PRINT 'SOLUTION:';
PRINT '============================================';
PRINT 'If ACTION_TAKEN is not NULL, the procedure skips the record.';
PRINT 'Update it to NULL or empty string:';
PRINT '';
PRINT 'UPDATE dbo.USER_CUSTOMER_STAGING';
PRINT 'SET ACTION_TAKEN = NULL';
PRINT 'WHERE BATCH_ID = ''TEST_BATCH_001'';';
PRINT '============================================';
GO


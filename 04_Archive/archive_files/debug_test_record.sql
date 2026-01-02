-- ============================================
-- Debug Test Record - Why isn't it being processed?
-- ============================================

USE WOODYS_CP;  -- or CPPractice if testing
GO

PRINT '============================================';
PRINT 'DEBUGGING TEST RECORD';
PRINT '============================================';
PRINT '';

-- Check the test record
SELECT 
    STAGING_ID,
    BATCH_ID,
    CUST_NO,  -- Should be NULL for new customers
    NAM,
    EMAIL_ADRS_1,
    IS_APPLIED,  -- Should be 0 (not processed)
    CUST_NAM_TYP,
    PROF_COD_1,
    TAX_COD,
    CREAT_DAT
FROM dbo.USER_CUSTOMER_STAGING
WHERE BATCH_ID = 'TEST_BATCH_001';
GO

PRINT '';
PRINT '============================================';
PRINT 'DIAGNOSIS:';
PRINT '============================================';
PRINT '';
PRINT 'The procedure requires:';
PRINT '  1. IS_APPLIED = 0 (not yet processed)';
PRINT '  2. CUST_NO IS NULL (new customer)';
PRINT '  3. BATCH_ID = ''TEST_BATCH_001''';
PRINT '';
PRINT 'If any of these are wrong, fix them below:';
PRINT '';
GO

-- Fix the record if needed
UPDATE dbo.USER_CUSTOMER_STAGING
SET 
    CUST_NO = NULL,  -- NULL = new customer
    IS_APPLIED = 0   -- 0 = not processed
WHERE BATCH_ID = 'TEST_BATCH_001'
  AND (CUST_NO IS NOT NULL OR IS_APPLIED != 0);
GO

IF @@ROWCOUNT > 0
BEGIN
    PRINT '✅ Fixed the test record';
    PRINT 'Now run: EXEC dbo.usp_Create_Customers_From_Staging @BatchID = ''TEST_BATCH_001'';';
END
ELSE
BEGIN
    PRINT '✅ Test record looks correct';
    PRINT 'If still not processing, check BATCH_ID matches exactly.';
END
GO


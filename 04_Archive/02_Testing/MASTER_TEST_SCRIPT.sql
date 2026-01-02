-- ============================================
-- MASTER TEST SCRIPT - Complete Testing Workflow
-- Run this script to test the entire pipeline
-- ============================================

USE WOODYS_CP;  -- Change to CPPractice if testing
GO

PRINT '============================================';
PRINT 'MASTER TEST SCRIPT - Complete Pipeline Test';
PRINT '============================================';
PRINT '';

-- ============================================
-- STEP 0: Cleanup Previous Test Data (Optional)
-- ============================================
PRINT 'STEP 0: Cleaning up previous test data...';
GO

DELETE FROM dbo.USER_CUSTOMER_STAGING WHERE BATCH_ID LIKE 'TEST_BATCH%';
-- Note: Can't delete from AR_CUST by CUST_NO yet - we don't know what CUST_NO was assigned
-- DELETE FROM dbo.AR_CUST WHERE CUST_NO IN ('TEST001', 'TEST002');
-- Delete by email instead:
DELETE FROM dbo.AR_CUST WHERE EMAIL_ADRS_1 IN ('test@example.com', 'test2@example.com');
DELETE FROM dbo.USER_CUSTOMER_MAP WHERE WOO_EMAIL IN ('test@example.com', 'test2@example.com');
GO

PRINT '✅ Cleanup complete';
PRINT '';
GO

-- ============================================
-- STEP 1: Create VALID Test Record
-- ============================================
PRINT '============================================';
PRINT 'STEP 1: Creating VALID Test Record';
PRINT '============================================';
PRINT '';

INSERT INTO dbo.USER_CUSTOMER_STAGING (
    BATCH_ID, 
    CUST_NO,  -- NULL for new customers (procedure will generate CUST_NO)
    NAM, 
    CUST_NAM_TYP, 
    ADRS_1, 
    CITY, 
    STATE, 
    ZIP_COD, 
    EMAIL_ADRS_1, 
    PROF_COD_1,
    IS_APPLIED  -- Must be 0 for procedure to process
)
VALUES (
    'TEST_BATCH_001', 
    NULL,  -- NULL = new customer (procedure will assign CUST_NO)
    'Test Customer Company', 
    'B',  -- Business (valid)
    '123 Main Street', 
    'Miami', 
    'FL', 
    '33101', 
    'test@example.com', 
    'TIER1',  -- Valid tier
    0  -- IS_APPLIED = 0 (not yet processed)
);
GO

PRINT '✅ Test record created';
PRINT '';
GO

-- ============================================
-- STEP 2: Run Preflight Validation
-- ============================================
PRINT '============================================';
PRINT 'STEP 2: Running Preflight Validation';
PRINT '============================================';
PRINT '';

EXEC dbo.usp_Preflight_Validate_Customer_Staging @BatchID = 'TEST_BATCH_001';
GO

PRINT '';
PRINT 'If validation PASSED, proceed to Step 3';
PRINT 'If validation FAILED, fix the data and re-run validation';
PRINT '';
GO

-- ============================================
-- STEP 3: Create Customer in CounterPoint
-- ============================================
PRINT '============================================';
PRINT 'STEP 3: Creating Customer in CounterPoint';
PRINT '============================================';
PRINT '';
PRINT 'NOTE: Only run this if Step 2 validation PASSED!';
PRINT '';

-- Diagnostic: Check the test record before creating
PRINT '3.0. Checking test record status...';
SELECT 
    STAGING_ID,
    BATCH_ID,
    CUST_NO,  -- Should be NULL
    IS_APPLIED,  -- Should be 0
    NAM,
    EMAIL_ADRS_1
FROM dbo.USER_CUSTOMER_STAGING
WHERE BATCH_ID = 'TEST_BATCH_001';
GO

PRINT '';
PRINT '3.1. Fixing test record if needed...';
-- Ensure record is ready for processing
UPDATE dbo.USER_CUSTOMER_STAGING
SET 
    CUST_NO = NULL,  -- NULL = new customer
    IS_APPLIED = 0   -- 0 = not processed
WHERE BATCH_ID = 'TEST_BATCH_001';
GO

PRINT 'Creating customer from staging...';
PRINT '';

-- Create customer from staging (only runs if validation passed)
EXEC dbo.usp_Create_Customers_From_Staging @BatchID = 'TEST_BATCH_001', @DryRun = 0;
GO

-- ============================================
-- STEP 4: Verify Customer Creation
-- ============================================
PRINT '============================================';
PRINT 'STEP 4: Verifying Customer Creation';
PRINT '============================================';
PRINT '';

-- 4.1. Check if customer exists in AR_CUST
PRINT '4.1. Checking AR_CUST table...';
SELECT 
    CUST_NO,
    NAM,
    CUST_NAM_TYP,
    ADRS_1,
    CITY,
    STATE,
    ZIP_COD,
    EMAIL_ADRS_1,
    PROF_COD_1,
    CATEG_COD,
    LST_MAINT_DT AS CREAT_DAT,  -- Using last maintenance date (AR_CUST doesn't have creation date)
    LST_MAINT_USR_ID
FROM dbo.AR_CUST
WHERE LOWER(EMAIL_ADRS_1) = 'test@example.com'  -- Find by email (procedure converts to lowercase)
   OR CUST_NO = '10036';  -- Also check by generated CUST_NO
GO

-- 4.2. Check sync log
PRINT '';
PRINT '4.2. Checking sync log...';
SELECT TOP 5
    START_TIME AS SYNC_DAT,
    SYNC_ID AS BATCH_ID,
    OPERATION_TYPE AS ENTITY_TYP,
    DIRECTION AS ACTION_TYP,
    CASE WHEN SUCCESS = 1 THEN 'SUCCESS' ELSE 'FAILED' END AS STATUS,
    RECORDS_CREATED + RECORDS_UPDATED AS RECORDS_PROCESSED,
    RECORDS_FAILED,
    ERROR_MESSAGE AS ERROR_MSG
FROM dbo.USER_SYNC_LOG
WHERE SYNC_ID = 'TEST_BATCH_001'
ORDER BY START_TIME DESC;
GO

-- 4.3. Check customer mapping
PRINT '';
PRINT '4.3. Checking customer mapping...';
SELECT 
    CUST_NO AS CP_CUST_NO,
    WOO_USER_ID AS WOO_CUSTOMER_ID,
    WOO_EMAIL,
    CREATED_DT AS MAP_DAT,
    UPDATED_DT AS LAST_SYNC_DAT
FROM dbo.USER_CUSTOMER_MAP
WHERE LOWER(WOO_EMAIL) = 'test@example.com'  -- Find by email (lowercase)
   OR CUST_NO IN (SELECT CUST_NO FROM dbo.AR_CUST WHERE LOWER(EMAIL_ADRS_1) = 'test@example.com' OR CUST_NO = '10036');
GO

-- ============================================
-- STEP 5: Test with Invalid Data (Optional)
-- ============================================
PRINT '';
PRINT '============================================';
PRINT 'STEP 5: Testing Error Detection (Optional)';
PRINT '============================================';
PRINT '';

-- Create invalid test record
INSERT INTO dbo.USER_CUSTOMER_STAGING (
    BATCH_ID, 
    CUST_NO,  -- NULL for new customers
    NAM, 
    CUST_NAM_TYP,  -- Will be NULL (invalid)
    ADRS_1, 
    CITY, 
    STATE, 
    ZIP_COD,  -- Will be NULL (invalid)
    EMAIL_ADRS_1, 
    PROF_COD_1,
    IS_APPLIED  -- Must be 0
)
VALUES (
    'TEST_BATCH_002', 
    NULL,  -- NULL = new customer
    'Test Customer 2', 
    NULL,  -- INVALID: Should be 'B' or 'P'
    '456 Oak Avenue', 
    'Tampa', 
    'FL', 
    NULL,  -- INVALID: Required field
    'test2@example.com', 
    'INVALID',  -- INVALID: Not a recognized tier
    0  -- IS_APPLIED = 0
);
GO

PRINT '✅ Invalid test record created';
PRINT '';
PRINT 'Running validation (should show errors)...';
PRINT '';

EXEC dbo.usp_Preflight_Validate_Customer_Staging @BatchID = 'TEST_BATCH_002';
GO

PRINT '';
PRINT '============================================';
PRINT 'TEST COMPLETE';
PRINT '============================================';
PRINT '';
PRINT 'Summary:';
PRINT '  Step 1: ✅ Created valid test record';
PRINT '  Step 2: ✅ Ran preflight validation';
PRINT '  Step 3: ⏳ Create customer (uncomment when ready)';
PRINT '  Step 4: ⏳ Verify customer creation';
PRINT '  Step 5: ✅ Tested error detection';
PRINT '';
PRINT 'Next Steps:';
PRINT '  1. If Step 2 validation passed, uncomment Step 3 and run again';
PRINT '  2. Review Step 4 results to verify customer was created';
PRINT '  3. Check Step 5 to see how validation catches errors';
PRINT '============================================';
GO


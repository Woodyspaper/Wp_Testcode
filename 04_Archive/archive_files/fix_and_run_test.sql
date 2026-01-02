-- ============================================
-- Fix Test Record and Create Customer
-- ============================================

USE WOODYS_CP;  -- or CPPractice if testing
GO

PRINT '============================================';
PRINT 'FIXING TEST RECORD AND CREATING CUSTOMER';
PRINT '============================================';
PRINT '';

-- Step 1: Ensure test record is ready
UPDATE dbo.USER_CUSTOMER_STAGING
SET 
    CUST_NO = NULL,  -- NULL = new customer
    IS_APPLIED = 0   -- 0 = not processed
WHERE BATCH_ID = 'TEST_BATCH_001';
GO

-- Step 2: Verify the record
SELECT 
    STAGING_ID,
    BATCH_ID,
    CUST_NO,
    IS_APPLIED,
    NAM,
    EMAIL_ADRS_1
FROM dbo.USER_CUSTOMER_STAGING
WHERE BATCH_ID = 'TEST_BATCH_001';
GO

PRINT '';
PRINT 'Creating customer...';
PRINT '';

-- Step 3: Create the customer
EXEC dbo.usp_Create_Customers_From_Staging @BatchID = 'TEST_BATCH_001', @DryRun = 0;
GO

PRINT '';
PRINT '============================================';
PRINT 'VERIFYING CUSTOMER CREATION';
PRINT '============================================';
PRINT '';

-- Step 4: Verify it was created
SELECT 
    CUST_NO,
    NAM,
    EMAIL_ADRS_1,
    PROF_COD_1,
    LST_MAINT_DT
FROM dbo.AR_CUST
WHERE EMAIL_ADRS_1 = 'test@example.com';
GO

PRINT '';
PRINT '✅ Done!';
GO


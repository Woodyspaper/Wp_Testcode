-- ============================================
-- TEST ORDER STORED PROCEDURES
-- ============================================
-- Purpose: Test sp_ValidateStagedOrder, sp_CreateOrderFromStaging, sp_CreateOrderLines
-- Run this in SSMS to test the stored procedures
-- ============================================

USE WOODYS_CP;  -- Change to CPPractice if testing
GO

PRINT '============================================';
PRINT 'TEST ORDER STORED PROCEDURES';
PRINT '============================================';
PRINT '';

-- ============================================
-- STEP 0: Setup - Find Valid Test Data
-- ============================================
PRINT 'STEP 0: Finding valid test data...';
PRINT '';

-- Find a valid customer
DECLARE @TestCustNo VARCHAR(15);
SELECT TOP 1 @TestCustNo = CUST_NO
FROM dbo.AR_CUST
WHERE CUST_NO IS NOT NULL  -- Any valid customer
ORDER BY CUST_NO;
PRINT 'Test Customer: ' + ISNULL(@TestCustNo, 'NOT FOUND - NEED TO CREATE ONE');

-- Find valid items for line items
DECLARE @TestItem1 VARCHAR(20);
DECLARE @TestItem2 VARCHAR(20);
SELECT TOP 1 @TestItem1 = ITEM_NO
FROM dbo.IM_ITEM
WHERE STAT = 'A'  -- Active item
ORDER BY ITEM_NO;

SELECT TOP 1 @TestItem2 = ITEM_NO
FROM dbo.IM_ITEM
WHERE STAT = 'A' AND ITEM_NO <> @TestItem1
ORDER BY ITEM_NO;

PRINT 'Test Item 1: ' + ISNULL(@TestItem1, 'NOT FOUND');
PRINT 'Test Item 2: ' + ISNULL(@TestItem2, 'NOT FOUND');
PRINT '';

-- Check if we have valid test data
IF @TestCustNo IS NULL OR @TestItem1 IS NULL
BEGIN
    PRINT 'ERROR: Missing required test data!';
    PRINT '  - Need at least 1 customer in AR_CUST';
    PRINT '  - Need at least 1 active item in IM_ITEM (STAT = ''A'')';
    PRINT '';
    PRINT 'Please create test data or use existing data.';
    RETURN;
END

-- ============================================
-- STEP 1: Cleanup Previous Test Data
-- ============================================
PRINT '============================================';
PRINT 'STEP 1: Cleaning up previous test data...';
PRINT '============================================';
PRINT '';

-- Delete test orders from staging (if any)
DELETE FROM dbo.USER_ORDER_STAGING 
WHERE BATCH_ID = 'TEST_ORDER_PROC' OR WOO_ORDER_ID = 999999;

-- Note: We won't delete from PS_DOC_HDR automatically
-- You may want to manually clean up test orders after verification
PRINT '✅ Cleanup complete';
PRINT '';

-- ============================================
-- STEP 2: Create Test Staged Order (VALID)
-- ============================================
PRINT '============================================';
PRINT 'STEP 2: Creating VALID test staged order';
PRINT '============================================';
PRINT '';

DECLARE @LineItemsJSON NVARCHAR(MAX);
SET @LineItemsJSON = '[' +
    '{"sku":"' + @TestItem1 + '","name":"Test Product 1","quantity":2,"price":10.50,"total":21.00},' +
    '{"sku":"' + @TestItem2 + '","name":"Test Product 2","quantity":1,"price":15.75,"total":15.75}' +
']';

INSERT INTO dbo.USER_ORDER_STAGING (
    BATCH_ID,
    WOO_ORDER_ID,
    WOO_ORDER_NO,
    CUST_NO,
    CUST_EMAIL,
    ORD_DAT,
    ORD_STATUS,
    PMT_METH,
    SHIP_VIA,
    SUBTOT,
    SHIP_AMT,
    TAX_AMT,
    DISC_AMT,
    TOT_AMT,
    SHIP_NAM,
    SHIP_ADRS_1,
    SHIP_CITY,
    SHIP_STATE,
    SHIP_ZIP_COD,
    SHIP_CNTRY,
    LINE_ITEMS_JSON,
    IS_VALIDATED,
    IS_APPLIED
)
VALUES (
    'TEST_ORDER_PROC',
    999999,
    'TEST-999999',
    @TestCustNo,
    'test@example.com',
    CAST(GETDATE() AS DATE),
    'processing',
    'Credit Card',
    'Standard Shipping',
    36.75,  -- Subtotal (21.00 + 15.75)
    5.00,   -- Shipping
    2.50,   -- Tax
    0.00,   -- Discount
    44.25,  -- Total
    'Test Customer',
    '123 Test Street',
    'Miami',
    'FL',
    '33101',
    'US',
    @LineItemsJSON,
    0,  -- Not validated yet
    0   -- Not applied yet
);

DECLARE @TestStagingID INT;
SET @TestStagingID = SCOPE_IDENTITY();

PRINT '✅ Test staged order created';
PRINT '   STAGING_ID: ' + CAST(@TestStagingID AS VARCHAR);
PRINT '   CUST_NO: ' + @TestCustNo;
PRINT '   Total: $44.25';
PRINT '';

-- Show the test order
SELECT 
    STAGING_ID,
    WOO_ORDER_ID,
    CUST_NO,
    TOT_AMT,
    IS_VALIDATED,
    IS_APPLIED,
    LINE_ITEMS_JSON
FROM dbo.USER_ORDER_STAGING
WHERE STAGING_ID = @TestStagingID;
PRINT '';

-- ============================================
-- STEP 3: Test Validation (VALID case)
-- ============================================
PRINT '============================================';
PRINT 'STEP 3: Testing sp_ValidateStagedOrder (VALID)';
PRINT '============================================';
PRINT '';

DECLARE @IsValid BIT;
DECLARE @ErrorMessage NVARCHAR(500);

EXEC dbo.sp_ValidateStagedOrder
    @StagingID = @TestStagingID,
    @IsValid = @IsValid OUTPUT,
    @ErrorMessage = @ErrorMessage OUTPUT;

IF @IsValid = 1
BEGIN
    PRINT '✅ VALIDATION PASSED';
    PRINT '   Order is valid and ready to process';
END
ELSE
BEGIN
    PRINT '❌ VALIDATION FAILED';
    PRINT '   Error: ' + ISNULL(@ErrorMessage, 'Unknown error');
END
PRINT '';

-- ============================================
-- STEP 4: Test Validation (INVALID case)
-- ============================================
PRINT '============================================';
PRINT 'STEP 4: Testing sp_ValidateStagedOrder (INVALID)';
PRINT '============================================';
PRINT '';

-- Create an invalid test order (missing customer)
DECLARE @InvalidStagingID INT;
INSERT INTO dbo.USER_ORDER_STAGING (
    BATCH_ID,
    WOO_ORDER_ID,
    CUST_NO,  -- NULL = invalid
    ORD_DAT,
    TOT_AMT,
    LINE_ITEMS_JSON,
    IS_APPLIED
)
VALUES (
    'TEST_ORDER_PROC',
    999998,
    NULL,  -- Invalid: no customer
    CAST(GETDATE() AS DATE),
    10.00,
    '[{"sku":"TEST","name":"Test","quantity":1,"price":10.00,"total":10.00}]',
    0
);

SET @InvalidStagingID = SCOPE_IDENTITY();

DECLARE @IsValidInvalid BIT;
DECLARE @ErrorMsgInvalid NVARCHAR(500);

EXEC dbo.sp_ValidateStagedOrder
    @StagingID = @InvalidStagingID,
    @IsValid = @IsValidInvalid OUTPUT,
    @ErrorMessage = @ErrorMsgInvalid OUTPUT;

IF @IsValidInvalid = 0
BEGIN
    PRINT '✅ VALIDATION CORRECTLY REJECTED INVALID ORDER';
    PRINT '   Error: ' + ISNULL(@ErrorMsgInvalid, 'Unknown error');
END
ELSE
BEGIN
    PRINT '❌ VALIDATION SHOULD HAVE FAILED BUT PASSED';
END
PRINT '';

-- ============================================
-- STEP 5: Test Order Creation (VALID order)
-- ============================================
PRINT '============================================';
PRINT 'STEP 5: Testing sp_CreateOrderFromStaging';
PRINT '============================================';
PRINT '';
PRINT 'WARNING: This will create actual records in PS_DOC_HDR, PS_DOC_LIN, PS_DOC_HDR_TOT';
PRINT 'Press Ctrl+C to cancel, or wait 5 seconds...';
PRINT '';
WAITFOR DELAY '00:00:05';
PRINT '';

DECLARE @DocID BIGINT;
DECLARE @TktNo VARCHAR(15);
DECLARE @Success BIT;
DECLARE @CreateError NVARCHAR(500);

PRINT 'Creating order from staging...';
EXEC dbo.sp_CreateOrderFromStaging
    @StagingID = @TestStagingID,
    @DocID = @DocID OUTPUT,
    @TktNo = @TktNo OUTPUT,
    @Success = @Success OUTPUT,
    @ErrorMessage = @CreateError OUTPUT;

IF @Success = 1
BEGIN
    PRINT '✅ ORDER CREATED SUCCESSFULLY!';
    PRINT '   DOC_ID: ' + CAST(@DocID AS VARCHAR);
    PRINT '   TKT_NO: ' + ISNULL(@TktNo, 'NULL');
    PRINT '';
    
    -- Verify the order was created
    PRINT 'Verifying order in PS_DOC_HDR...';
    SELECT 
        DOC_ID,
        TKT_NO,
        CUST_NO,
        TKT_DT,
        ORD_LINS,
        SAL_LINS
    FROM dbo.PS_DOC_HDR
    WHERE DOC_ID = @DocID;
    PRINT '';
    
    -- Verify line items
    PRINT 'Verifying line items in PS_DOC_LIN...';
    SELECT 
        DOC_ID,
        LIN_SEQ_NO,
        ITEM_NO,
        DESCR,
        QTY_SOLD,
        PRC,
        EXT_PRC
    FROM dbo.PS_DOC_LIN
    WHERE DOC_ID = @DocID
    ORDER BY LIN_SEQ_NO;
    PRINT '';
    
    -- Verify totals
    PRINT 'Verifying totals in PS_DOC_HDR_TOT...';
    SELECT 
        DOC_ID,
        SUB_TOT,
        TAX_AMT,
        TOT,
        TOT_HDR_DISC,
        TOT_LIN_DISC,
        AMT_DUE
    FROM dbo.PS_DOC_HDR_TOT
    WHERE DOC_ID = @DocID;
    PRINT '';
    
    -- Verify staging record was updated
    PRINT 'Verifying staging record was updated...';
    SELECT 
        STAGING_ID,
        IS_APPLIED,
        CP_DOC_ID,
        APPLIED_DT
    FROM dbo.USER_ORDER_STAGING
    WHERE STAGING_ID = @TestStagingID;
    PRINT '';
    
    PRINT '✅ ALL VERIFICATIONS COMPLETE';
END
ELSE
BEGIN
    PRINT '❌ ORDER CREATION FAILED';
    PRINT '   Error: ' + ISNULL(@CreateError, 'Unknown error');
END
PRINT '';

-- ============================================
-- STEP 6: Test Error Handling (Already Applied)
-- ============================================
PRINT '============================================';
PRINT 'STEP 6: Testing error handling (already applied)';
PRINT '============================================';
PRINT '';

-- Try to create the same order again (should fail)
DECLARE @DocID2 BIGINT;
DECLARE @TktNo2 VARCHAR(15);
DECLARE @Success2 BIT;
DECLARE @CreateError2 NVARCHAR(500);

EXEC dbo.sp_CreateOrderFromStaging
    @StagingID = @TestStagingID,
    @DocID = @DocID2 OUTPUT,
    @TktNo = @TktNo2 OUTPUT,
    @Success = @Success2 OUTPUT,
    @ErrorMessage = @CreateError2 OUTPUT;

IF @Success2 = 0
BEGIN
    PRINT '✅ CORRECTLY REJECTED DUPLICATE PROCESSING';
    PRINT '   Error: ' + ISNULL(@CreateError2, 'Unknown error');
END
ELSE
BEGIN
    PRINT '❌ SHOULD HAVE REJECTED DUPLICATE BUT DID NOT';
END
PRINT '';

-- ============================================
-- STEP 7: Summary
-- ============================================
PRINT '============================================';
PRINT 'TEST SUMMARY';
PRINT '============================================';
PRINT '';
PRINT 'Test Results:';
PRINT '  - Validation (valid): ' + CASE WHEN @IsValid = 1 THEN 'PASSED' ELSE 'FAILED' END;
PRINT '  - Validation (invalid): ' + CASE WHEN @IsValidInvalid = 0 THEN 'PASSED' ELSE 'FAILED' END;
PRINT '  - Order Creation: ' + CASE WHEN @Success = 1 THEN 'PASSED' ELSE 'FAILED' END;
PRINT '  - Duplicate Prevention: ' + CASE WHEN @Success2 = 0 THEN 'PASSED' ELSE 'FAILED' END;
PRINT '';
PRINT 'Test Order Details:';
PRINT '  STAGING_ID: ' + CAST(@TestStagingID AS VARCHAR);
IF @Success = 1
BEGIN
    PRINT '  DOC_ID: ' + CAST(@DocID AS VARCHAR);
    PRINT '  TKT_NO: ' + ISNULL(@TktNo, 'NULL');
END
PRINT '';
PRINT 'NOTE: Test orders were created in PS_DOC_HDR.';
PRINT '      You may want to manually delete them after verification.';
PRINT '';
PRINT 'To clean up test data:';
PRINT '  DELETE FROM dbo.PS_DOC_LIN WHERE DOC_ID = ' + CAST(@DocID AS VARCHAR) + ';';
PRINT '  DELETE FROM dbo.PS_DOC_HDR_TOT WHERE DOC_ID = ' + CAST(@DocID AS VARCHAR) + ';';
PRINT '  DELETE FROM dbo.PS_DOC_HDR WHERE DOC_ID = ' + CAST(@DocID AS VARCHAR) + ';';
PRINT '  DELETE FROM dbo.USER_ORDER_STAGING WHERE BATCH_ID = ''TEST_ORDER_PROC'';';
PRINT '';
PRINT '============================================';
PRINT 'TEST COMPLETE';
PRINT '============================================';

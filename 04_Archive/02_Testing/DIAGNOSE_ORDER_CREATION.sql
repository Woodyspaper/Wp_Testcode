-- ============================================
-- DIAGNOSE ORDER CREATION FAILURES
-- ============================================
-- Purpose: Comprehensive diagnostic to find why order creation fails
-- ============================================

USE WOODYS_CP;
GO

PRINT '============================================';
PRINT 'ORDER CREATION DIAGNOSTIC';
PRINT '============================================';
PRINT '';

-- 1. Check if procedures exist
PRINT '1. Checking stored procedures...';
IF OBJECT_ID('dbo.sp_ValidateStagedOrder', 'P') IS NOT NULL
    PRINT '   [OK] sp_ValidateStagedOrder exists';
ELSE
    PRINT '   [FAIL] sp_ValidateStagedOrder does NOT exist';

IF OBJECT_ID('dbo.sp_CreateOrderFromStaging', 'P') IS NOT NULL
    PRINT '   [OK] sp_CreateOrderFromStaging exists';
ELSE
    PRINT '   [FAIL] sp_CreateOrderFromStaging does NOT exist';

IF OBJECT_ID('dbo.sp_CreateOrderLines', 'P') IS NOT NULL
    PRINT '   [OK] sp_CreateOrderLines exists';
ELSE
    PRINT '   [FAIL] sp_CreateOrderLines does NOT exist';

PRINT '';

-- 2. Check for test staging order
PRINT '2. Checking for test staging order...';
DECLARE @TestStagingID INT;
SELECT TOP 1 @TestStagingID = STAGING_ID
FROM dbo.USER_ORDER_STAGING
WHERE IS_APPLIED = 0
  AND CUST_NO IS NOT NULL
  AND LINE_ITEMS_JSON IS NOT NULL
ORDER BY STAGING_ID DESC;

IF @TestStagingID IS NOT NULL
BEGIN
    PRINT '   [OK] Found test staging order: ' + CAST(@TestStagingID AS VARCHAR);
    
    -- Show staging order details
    SELECT 
        STAGING_ID,
        CUST_NO,
        ORD_DAT,
        SUBTOT,
        TAX_AMT,
        TOT_AMT,
        LEFT(LINE_ITEMS_JSON, 100) AS LINE_ITEMS_PREVIEW,
        IS_APPLIED
    FROM dbo.USER_ORDER_STAGING
    WHERE STAGING_ID = @TestStagingID;
END
ELSE
BEGIN
    PRINT '   [FAIL] No test staging order found';
    PRINT '   Create one first using test_order_processor.py';
    RETURN;
END

PRINT '';

-- 3. Test validation
PRINT '3. Testing validation...';
DECLARE @IsValid BIT;
DECLARE @ValidationError NVARCHAR(500);

EXEC dbo.sp_ValidateStagedOrder
    @StagingID = @TestStagingID,
    @IsValid = @IsValid OUTPUT,
    @ErrorMessage = @ValidationError OUTPUT;

IF @IsValid = 1
    PRINT '   [OK] Validation passed';
ELSE
BEGIN
    PRINT '   [FAIL] Validation failed: ' + @ValidationError;
    RETURN;
END

PRINT '';

-- 4. Check customer exists
PRINT '4. Checking customer...';
DECLARE @CustNo VARCHAR(15);
SELECT @CustNo = CUST_NO FROM dbo.USER_ORDER_STAGING WHERE STAGING_ID = @TestStagingID;

IF EXISTS (SELECT 1 FROM dbo.AR_CUST WHERE CUST_NO = @CustNo)
    PRINT '   [OK] Customer exists: ' + @CustNo;
ELSE
BEGIN
    PRINT '   [FAIL] Customer does NOT exist: ' + ISNULL(@CustNo, 'NULL');
    RETURN;
END

PRINT '';

-- 5. Check items exist
PRINT '5. Checking items in JSON...';
DECLARE @LineItemsJSON NVARCHAR(MAX);
SELECT @LineItemsJSON = LINE_ITEMS_JSON FROM dbo.USER_ORDER_STAGING WHERE STAGING_ID = @TestStagingID;

-- Try to extract SKUs (simple check)
DECLARE @SkuCount INT = 0;
DECLARE @Pos INT = 1;
DECLARE @SkuStart INT;

WHILE @Pos <= LEN(@LineItemsJSON)
BEGIN
    SET @SkuStart = CHARINDEX('"sku":"', @LineItemsJSON, @Pos);
    IF @SkuStart = 0 BREAK;
    
    SET @SkuStart = @SkuStart + 7;
    DECLARE @SkuEnd INT = CHARINDEX('"', @LineItemsJSON, @SkuStart);
    IF @SkuEnd = 0 BREAK;
    
    DECLARE @Sku VARCHAR(20) = SUBSTRING(@LineItemsJSON, @SkuStart, @SkuEnd - @SkuStart);
    
    IF EXISTS (SELECT 1 FROM dbo.IM_ITEM WHERE ITEM_NO = @Sku)
        SET @SkuCount = @SkuCount + 1;
    ELSE
        PRINT '   [WARN] Item not found: ' + @Sku;
    
    SET @Pos = @SkuEnd + 1;
END

PRINT '   Found ' + CAST(@SkuCount AS VARCHAR) + ' valid items in JSON';

PRINT '';

-- 6. Try to create order with detailed error handling
PRINT '6. Attempting order creation with detailed error capture...';
PRINT '';
PRINT '   Note: sp_CreateOrderFromStaging manages its own transaction';
PRINT '   (No outer transaction wrapper needed)';
PRINT '';

DECLARE @DocID BIGINT;
DECLARE @TktNo VARCHAR(15);
DECLARE @Success BIT;
DECLARE @ErrorMessage NVARCHAR(500);

BEGIN TRY
    -- Don't wrap in transaction - the stored procedure manages its own
    EXEC dbo.sp_CreateOrderFromStaging
        @StagingID = @TestStagingID,
        @DocID = @DocID OUTPUT,
        @TktNo = @TktNo OUTPUT,
        @Success = @Success OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;
    
    IF @Success = 1
    BEGIN
        PRINT '   [OK] Order created successfully!';
        PRINT '   DOC_ID: ' + CAST(@DocID AS VARCHAR);
        PRINT '   TKT_NO: ' + @TktNo;
        
        -- Verify records were created
        PRINT '';
        PRINT '7. Verifying created records...';
        
        IF EXISTS (SELECT 1 FROM dbo.PS_DOC_HDR WHERE DOC_ID = @DocID)
            PRINT '   [OK] PS_DOC_HDR record exists';
        ELSE
            PRINT '   [FAIL] PS_DOC_HDR record NOT found';
        
        DECLARE @LineCount INT;
        SELECT @LineCount = COUNT(*) FROM dbo.PS_DOC_LIN WHERE DOC_ID = @DocID;
        PRINT '   [INFO] PS_DOC_LIN records: ' + CAST(@LineCount AS VARCHAR);
        
        IF EXISTS (SELECT 1 FROM dbo.PS_DOC_HDR_TOT WHERE DOC_ID = @DocID)
            PRINT '   [OK] PS_DOC_HDR_TOT record exists';
        ELSE
            PRINT '   [FAIL] PS_DOC_HDR_TOT record NOT found';
    END
    ELSE
    BEGIN
        PRINT '   [FAIL] Order creation failed!';
        PRINT '   Error: ' + @ErrorMessage;
        
        -- Try to get more details from SQL error
        PRINT '';
        PRINT '   SQL Error Details:';
        PRINT '   Error Number: ' + CAST(ERROR_NUMBER() AS VARCHAR);
        PRINT '   Error Message: ' + ERROR_MESSAGE();
        PRINT '   Error Severity: ' + CAST(ERROR_SEVERITY() AS VARCHAR);
        PRINT '   Error State: ' + CAST(ERROR_STATE() AS VARCHAR);
        PRINT '   Error Line: ' + CAST(ERROR_LINE() AS VARCHAR);
    END
END TRY
BEGIN CATCH
    -- Only rollback if we're in a transaction (check @@TRANCOUNT)
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    
    PRINT '   [FAIL] Exception caught during order creation!';
    PRINT '   Error Number: ' + CAST(ERROR_NUMBER() AS VARCHAR);
    PRINT '   Error Message: ' + ERROR_MESSAGE();
    PRINT '   Error Severity: ' + CAST(ERROR_SEVERITY() AS VARCHAR);
    PRINT '   Error State: ' + CAST(ERROR_STATE() AS VARCHAR);
    PRINT '   Error Line: ' + CAST(ERROR_LINE() AS VARCHAR);
    PRINT '   Error Procedure: ' + ISNULL(ERROR_PROCEDURE(), 'N/A');
END CATCH

PRINT '';
PRINT '============================================';
PRINT 'DIAGNOSTIC COMPLETE';
PRINT '============================================';

GO

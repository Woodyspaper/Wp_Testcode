-- ============================================
-- sp_ValidateStagedOrder
-- ============================================
-- Purpose: Validate a staged order before creating in CounterPoint
--          For Phase 5: Order Creation
-- ============================================
-- Parameters:
--   @StagingID - ID from USER_ORDER_STAGING
-- Returns:
--   Validation result with error messages
-- ============================================

USE WOODYS_CP;
GO

IF OBJECT_ID('dbo.sp_ValidateStagedOrder', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_ValidateStagedOrder;
GO

CREATE PROCEDURE dbo.sp_ValidateStagedOrder
    @StagingID INT,
    @IsValid BIT OUTPUT,
    @ErrorMessage NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CustNo VARCHAR(15);
    DECLARE @LineItemsJSON NVARCHAR(MAX);
    DECLARE @ErrorCount INT = 0;
    DECLARE @Errors NVARCHAR(500) = '';
    
    -- Initialize output
    SET @IsValid = 0;
    SET @ErrorMessage = '';
    
    -- Check if staging record exists
    IF NOT EXISTS (SELECT 1 FROM dbo.USER_ORDER_STAGING WHERE STAGING_ID = @StagingID)
    BEGIN
        SET @ErrorMessage = 'Staging record not found';
        RETURN;
    END
    
    -- Get staging data
    SELECT 
        @CustNo = CUST_NO,
        @LineItemsJSON = LINE_ITEMS_JSON
    FROM dbo.USER_ORDER_STAGING
    WHERE STAGING_ID = @StagingID;
    
    -- Validate customer exists
    IF @CustNo IS NULL OR @CustNo = ''
    BEGIN
        SET @ErrorCount = @ErrorCount + 1;
        SET @Errors = @Errors + 'Customer number is required. ';
    END
    ELSE IF NOT EXISTS (SELECT 1 FROM dbo.AR_CUST WHERE CUST_NO = @CustNo)
    BEGIN
        SET @ErrorCount = @ErrorCount + 1;
        SET @Errors = @Errors + 'Customer ' + @CustNo + ' does not exist. ';
    END
    
    -- Validate line items JSON
    IF @LineItemsJSON IS NULL OR @LineItemsJSON = ''
    BEGIN
        SET @ErrorCount = @ErrorCount + 1;
        SET @Errors = @Errors + 'Line items are required. ';
    END
    
    -- Check if already applied
    IF EXISTS (SELECT 1 FROM dbo.USER_ORDER_STAGING WHERE STAGING_ID = @StagingID AND IS_APPLIED = 1)
    BEGIN
        SET @ErrorCount = @ErrorCount + 1;
        SET @Errors = @Errors + 'Order already applied. ';
    END
    
    -- Set result
    IF @ErrorCount = 0
    BEGIN
        SET @IsValid = 1;
        SET @ErrorMessage = '';
    END
    ELSE
    BEGIN
        SET @IsValid = 0;
        SET @ErrorMessage = @Errors;
    END
END
GO

PRINT 'Created sp_ValidateStagedOrder';

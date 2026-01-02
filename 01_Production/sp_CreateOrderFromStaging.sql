-- ============================================
-- sp_CreateOrderFromStaging
-- ============================================
-- Purpose: Create CounterPoint order from staged WooCommerce order
--          For Phase 5: Order Creation
-- ============================================
-- Parameters:
--   @StagingID - ID from USER_ORDER_STAGING
-- Returns:
--   @DocID - Created document ID (bigint)
--   @TktNo - Created ticket number (varchar(15))
--   @Success - 1 if successful, 0 if failed
--   @ErrorMessage - Error message if failed
-- ============================================

USE WOODYS_CP;
GO

IF OBJECT_ID('dbo.sp_CreateOrderFromStaging', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_CreateOrderFromStaging;
GO

CREATE PROCEDURE dbo.sp_CreateOrderFromStaging
    @StagingID INT,
    @DocID BIGINT OUTPUT,
    @TktNo VARCHAR(15) OUTPUT,
    @Success BIT OUTPUT,
    @ErrorMessage NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CustNo VARCHAR(15);
    DECLARE @OrdDat DATE;
    DECLARE @TktDt DATETIME;
    DECLARE @SubTot DECIMAL(15,4);
    DECLARE @TaxAmt DECIMAL(15,4);
    DECLARE @DiscAmt DECIMAL(15,4);
    DECLARE @TotAmt DECIMAL(15,4);
    DECLARE @ShipAmt DECIMAL(15,4);
    DECLARE @ShipViaCod VARCHAR(10);
    DECLARE @LineItemsJSON NVARCHAR(MAX);
    DECLARE @StrId VARCHAR(10) = '01';
    DECLARE @StaId VARCHAR(10) = '101';
    DECLARE @DocTyp VARCHAR(1) = 'O';
    DECLARE @TotTyp VARCHAR(1) = 'S';
    DECLARE @LineSeqNo INT = 0;
    DECLARE @TotLinDisc DECIMAL(15,4) = 0;
    
    -- Initialize outputs
    SET @DocID = NULL;
    SET @TktNo = NULL;
    SET @Success = 0;
    SET @ErrorMessage = '';
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Validate staging record exists
        IF NOT EXISTS (SELECT 1 FROM dbo.USER_ORDER_STAGING WHERE STAGING_ID = @StagingID)
        BEGIN
            SET @ErrorMessage = 'Staging record not found';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Check if already applied
        IF EXISTS (SELECT 1 FROM dbo.USER_ORDER_STAGING WHERE STAGING_ID = @StagingID AND IS_APPLIED = 1)
        BEGIN
            SET @ErrorMessage = 'Order already applied';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Get staging data
        SELECT 
            @CustNo = CUST_NO,
            @OrdDat = ORD_DAT,
            @SubTot = SUBTOT,
            @TaxAmt = TAX_AMT,
            @DiscAmt = DISC_AMT,
            @TotAmt = TOT_AMT,
            @ShipAmt = SHIP_AMT,
            @ShipViaCod = LEFT(SHIP_VIA, 10),
            @LineItemsJSON = LINE_ITEMS_JSON
        FROM dbo.USER_ORDER_STAGING
        WHERE STAGING_ID = @StagingID;
        
        -- Validate customer
        IF @CustNo IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.AR_CUST WHERE CUST_NO = @CustNo)
        BEGIN
            SET @ErrorMessage = 'Customer not found: ' + ISNULL(@CustNo, 'NULL');
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Convert date to datetime
        SET @TktDt = CAST(@OrdDat AS DATETIME);
        
        -- Generate DOC_ID (DOC_ID is NOT IDENTITY - must generate manually)
        -- Get the maximum DOC_ID and add 1
        SELECT @DocID = ISNULL(MAX(DOC_ID), 0) + 1
        FROM dbo.PS_DOC_HDR;
        
        -- Generate TKT_NO BEFORE inserting (TKT_NO is required and cannot be NULL)
        -- Format: Station-TicketNumber (e.g., "101-000001")
        DECLARE @TktNoSuffix INT;
        SELECT @TktNoSuffix = ISNULL(MAX(CAST(SUBSTRING(TKT_NO, LEN(@StaId) + 2, LEN(TKT_NO)) AS INT)), 0) + 1
        FROM dbo.PS_DOC_HDR
        WHERE STA_ID = @StaId AND TKT_NO LIKE @StaId + '-%';
        
        SET @TktNo = @StaId + '-' + RIGHT('000000' + CAST(@TktNoSuffix AS VARCHAR), 6);
        
        -- Insert with explicit DOC_ID, TKT_NO, and DOC_GUID (GUID is required)
        INSERT INTO dbo.PS_DOC_HDR (
            DOC_ID, DOC_GUID, DOC_TYP, STR_ID, STA_ID, CUST_NO, TKT_DT, TKT_NO,
            SHIP_VIA_COD, STK_LOC_ID, PRC_LOC_ID,
            ORD_LINS, SAL_LINS, SAL_LIN_TOT
        )
        VALUES (
            @DocID, NEWID(), @DocTyp, @StrId, @StaId, @CustNo, @TktDt, @TktNo,
            @ShipViaCod, @StrId, @StrId,
            0, 0, 0
        );
        
        -- Calculate line discounts from JSON (simplified - would need proper JSON parsing)
        -- For now, assume line discounts are in the JSON
        SET @TotLinDisc = 0; -- Will be calculated when parsing line items
        
        -- Create totals record
        -- Note: INITIAL_MIN_DUE, TOT_WEIGHT, TOT_CUBE, TAX_AMT_SHIPPED are required (cannot be NULL)
        INSERT INTO dbo.PS_DOC_HDR_TOT (
            DOC_ID, TOT_TYP,
            SUB_TOT, TAX_AMT, TOT,
            TOT_HDR_DISC, TOT_LIN_DISC,
            AMT_DUE, TOT_MISC, INITIAL_MIN_DUE,
            TOT_WEIGHT, TOT_CUBE, TAX_AMT_SHIPPED
        )
        VALUES (
            @DocID, @TotTyp,
            ISNULL(@SubTot, 0), ISNULL(@TaxAmt, 0), ISNULL(@TotAmt, 0),
            ISNULL(@DiscAmt, 0), @TotLinDisc,
            ISNULL(@TotAmt, 0), ISNULL(@ShipAmt, 0), ISNULL(@TotAmt, 0),
            0, 0, ISNULL(@TaxAmt, 0)  -- TOT_WEIGHT, TOT_CUBE default to 0; TAX_AMT_SHIPPED = TAX_AMT
        );
        
        -- Parse and create line items
        DECLARE @LinesCreated INT;
        DECLARE @LineItemsSuccess BIT;
        DECLARE @LineItemsError NVARCHAR(500);
        
        EXEC dbo.sp_CreateOrderLines
            @DocID = @DocID,
            @TktNo = @TktNo,
            @LineItemsJSON = @LineItemsJSON,
            @LinesCreated = @LinesCreated OUTPUT,
            @TotLinDisc = @TotLinDisc OUTPUT,
            @Success = @LineItemsSuccess OUTPUT,
            @ErrorMessage = @LineItemsError OUTPUT;
        
        IF @LineItemsSuccess = 0
        BEGIN
            SET @ErrorMessage = 'Error creating line items: ' + @LineItemsError;
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Update totals with calculated line discounts
        UPDATE dbo.PS_DOC_HDR_TOT
        SET TOT_LIN_DISC = @TotLinDisc,
            TOT = SUB_TOT - TOT_HDR_DISC - @TotLinDisc + TAX_AMT + TOT_MISC,
            AMT_DUE = SUB_TOT - TOT_HDR_DISC - @TotLinDisc + TAX_AMT + TOT_MISC
        WHERE DOC_ID = @DocID;
        
        -- Update header with line counts
        UPDATE dbo.PS_DOC_HDR
        SET ORD_LINS = @LinesCreated,
            SAL_LINS = @LinesCreated
        WHERE DOC_ID = @DocID;
        
        -- Update staging record
        UPDATE dbo.USER_ORDER_STAGING
        SET 
            IS_APPLIED = 1,
            APPLIED_DT = GETDATE(),
            CP_DOC_ID = CAST(@DocID AS VARCHAR(15))
        WHERE STAGING_ID = @StagingID;
        
        SET @Success = 1;
        COMMIT TRANSACTION;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        SET @Success = 0;
        SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH
END
GO

PRINT 'Created sp_CreateOrderFromStaging (Note: Line items parsing needs to be completed)';

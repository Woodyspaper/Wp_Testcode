-- ============================================
-- DEPLOY ORDER PROCESSING STORED PROCEDURES
-- ============================================
-- Purpose: Deploy all three stored procedures for order processing
-- Run this script in SSMS to create all procedures at once
-- ============================================

USE WOODYS_CP;  -- Change to CPPractice if testing
GO

PRINT '============================================';
PRINT 'DEPLOYING ORDER PROCESSING STORED PROCEDURES';
PRINT '============================================';
PRINT '';

-- ============================================
-- 1. Deploy sp_ValidateStagedOrder
-- ============================================
PRINT '1. Deploying sp_ValidateStagedOrder...';
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

PRINT '   ✅ sp_ValidateStagedOrder created';
PRINT '';

-- ============================================
-- 2. Deploy sp_CreateOrderLines
-- ============================================
PRINT '2. Deploying sp_CreateOrderLines...';
GO

IF OBJECT_ID('dbo.sp_CreateOrderLines', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_CreateOrderLines;
GO

CREATE PROCEDURE dbo.sp_CreateOrderLines
    @DocID BIGINT,
    @TktNo VARCHAR(15),  -- Added: Required for PS_DOC_LIN
    @LineItemsJSON NVARCHAR(MAX),
    @LinesCreated INT OUTPUT,
    @TotLinDisc DECIMAL(15,4) OUTPUT,
    @Success BIT OUTPUT,
    @ErrorMessage NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @LineSeqNo INT = 0;
    DECLARE @ItemNo VARCHAR(20);
    DECLARE @Descr VARCHAR(250);
    DECLARE @QtySold DECIMAL(15,4);
    DECLARE @Prc MONEY;
    DECLARE @ExtPrc DECIMAL(15,2);  -- Changed to (15,2) to match table definition
    DECLARE @SellUnit VARCHAR(1);
    DECLARE @StkLocId VARCHAR(10);
    DECLARE @CategCod VARCHAR(10);
    DECLARE @LineDisc DECIMAL(15,4);
    DECLARE @LineTotal DECIMAL(15,4);
    DECLARE @ItemCount INT = 0;
    DECLARE @StrId VARCHAR(10) = '01';  -- Default store ID
    DECLARE @StaId VARCHAR(10) = '101';  -- Default station ID
    DECLARE @DocTyp VARCHAR(1) = 'O';  -- Document type: O=Order (matches header)
    DECLARE @LinTyp VARCHAR(1) = 'S';  -- Line type: S=Sale (from sample data)
    DECLARE @GrossExtPrc DECIMAL(15,2);  -- Gross extended price (required, no default)
    
    -- Initialize outputs
    SET @LinesCreated = 0;
    SET @TotLinDisc = 0;
    SET @Success = 0;
    SET @ErrorMessage = '';
    
    BEGIN TRY
        -- Validate JSON
        IF @LineItemsJSON IS NULL OR @LineItemsJSON = ''
        BEGIN
            SET @ErrorMessage = 'Line items JSON is empty';
            RETURN;
        END
        
        -- Parse JSON and create line items
        -- Use string parsing for compatibility (works on all SQL Server versions)
        DECLARE @LineItems TABLE (
            sku NVARCHAR(50),
            name NVARCHAR(255),
            quantity DECIMAL(15,4),
            price DECIMAL(15,4),
            total DECIMAL(15,4)
        );
        
        -- Parse JSON using string functions
        -- Format: [{"sku":"01-10100","name":"Test Product 1","quantity":2,"price":10.50,"total":21.00}]
        DECLARE @Pos INT = 1;
        DECLARE @NextPos INT;
        DECLARE @Sku NVARCHAR(50);
        DECLARE @Name NVARCHAR(255);
        DECLARE @Quantity DECIMAL(15,4);
        DECLARE @Price DECIMAL(15,4);
        DECLARE @Total DECIMAL(15,4);
        DECLARE @SkuStart INT;
        DECLARE @SkuEnd INT;
        DECLARE @NameStart INT;
        DECLARE @NameEnd INT;
        DECLARE @QtyStart INT;
        DECLARE @QtyEnd INT;
        DECLARE @PriceStart INT;
        DECLARE @PriceEnd INT;
        DECLARE @TotalStart INT;
        DECLARE @TotalEnd INT;
        
        -- Find each JSON object and extract values
        -- Handle both formats: "sku":"value" and "sku": "value" (with/without spaces)
        WHILE @Pos <= LEN(@LineItemsJSON)
        BEGIN
            -- Find next SKU field (try both with and without space after colon)
            SET @SkuStart = CHARINDEX('"sku"', @LineItemsJSON, @Pos);
            IF @SkuStart = 0 BREAK;  -- No more items found
            
            -- Skip past "sku" and find the colon
            SET @SkuStart = @SkuStart + 5;  -- Move past '"sku"'
            -- Skip any whitespace and colon
            WHILE @SkuStart <= LEN(@LineItemsJSON) AND (SUBSTRING(@LineItemsJSON, @SkuStart, 1) = ' ' OR SUBSTRING(@LineItemsJSON, @SkuStart, 1) = ':')
                SET @SkuStart = @SkuStart + 1;
            -- Skip opening quote
            IF SUBSTRING(@LineItemsJSON, @SkuStart, 1) = '"'
                SET @SkuStart = @SkuStart + 1;
            
            SET @SkuEnd = CHARINDEX('"', @LineItemsJSON, @SkuStart);
            IF @SkuEnd = 0 BREAK;  -- Invalid JSON format
            SET @Sku = SUBSTRING(@LineItemsJSON, @SkuStart, @SkuEnd - @SkuStart);
            
            -- Find Name (handle both formats)
            SET @NameStart = CHARINDEX('"name"', @LineItemsJSON, @SkuEnd);
            IF @NameStart = 0 BREAK;
            SET @NameStart = @NameStart + 6;  -- Move past '"name"'
            -- Skip any whitespace and colon
            WHILE @NameStart <= LEN(@LineItemsJSON) AND (SUBSTRING(@LineItemsJSON, @NameStart, 1) = ' ' OR SUBSTRING(@LineItemsJSON, @NameStart, 1) = ':')
                SET @NameStart = @NameStart + 1;
            -- Skip opening quote
            IF SUBSTRING(@LineItemsJSON, @NameStart, 1) = '"'
                SET @NameStart = @NameStart + 1;
            
            SET @NameEnd = CHARINDEX('"', @LineItemsJSON, @NameStart);
            IF @NameEnd = 0 BREAK;
            SET @Name = SUBSTRING(@LineItemsJSON, @NameStart, @NameEnd - @NameStart);
            
            -- Find Quantity (handle both formats)
            SET @QtyStart = CHARINDEX('"quantity"', @LineItemsJSON, @NameEnd);
            IF @QtyStart = 0 BREAK;
            SET @QtyStart = @QtyStart + 10;  -- Move past '"quantity"'
            -- Skip any whitespace and colon
            WHILE @QtyStart <= LEN(@LineItemsJSON) AND (SUBSTRING(@LineItemsJSON, @QtyStart, 1) = ' ' OR SUBSTRING(@LineItemsJSON, @QtyStart, 1) = ':')
                SET @QtyStart = @QtyStart + 1;
            
            -- Find the end of the quantity value (comma or closing brace)
            SET @QtyEnd = CHARINDEX(',', @LineItemsJSON, @QtyStart);
            IF @QtyEnd = 0 OR @QtyEnd > CHARINDEX('}', @LineItemsJSON, @QtyStart)
                SET @QtyEnd = CHARINDEX('}', @LineItemsJSON, @QtyStart);
            IF @QtyEnd = 0 BREAK;
            SET @Quantity = CAST(LTRIM(RTRIM(SUBSTRING(@LineItemsJSON, @QtyStart, @QtyEnd - @QtyStart))) AS DECIMAL(15,4));
            
            -- Find Price (handle both formats)
            SET @PriceStart = CHARINDEX('"price"', @LineItemsJSON, @QtyEnd);
            IF @PriceStart = 0 BREAK;
            SET @PriceStart = @PriceStart + 7;  -- Move past '"price"'
            -- Skip any whitespace and colon
            WHILE @PriceStart <= LEN(@LineItemsJSON) AND (SUBSTRING(@LineItemsJSON, @PriceStart, 1) = ' ' OR SUBSTRING(@LineItemsJSON, @PriceStart, 1) = ':')
                SET @PriceStart = @PriceStart + 1;
            
            -- Find the end of the price value (comma or closing brace)
            SET @PriceEnd = CHARINDEX(',', @LineItemsJSON, @PriceStart);
            IF @PriceEnd = 0 OR @PriceEnd > CHARINDEX('}', @LineItemsJSON, @PriceStart)
                SET @PriceEnd = CHARINDEX('}', @LineItemsJSON, @PriceStart);
            IF @PriceEnd = 0 BREAK;
            SET @Price = CAST(LTRIM(RTRIM(SUBSTRING(@LineItemsJSON, @PriceStart, @PriceEnd - @PriceStart))) AS DECIMAL(15,4));
            
            -- Find Total (handle both formats)
            SET @TotalStart = CHARINDEX('"total"', @LineItemsJSON, @PriceEnd);
            IF @TotalStart = 0 BREAK;
            SET @TotalStart = @TotalStart + 7;  -- Move past '"total"'
            -- Skip any whitespace and colon
            WHILE @TotalStart <= LEN(@LineItemsJSON) AND (SUBSTRING(@LineItemsJSON, @TotalStart, 1) = ' ' OR SUBSTRING(@LineItemsJSON, @TotalStart, 1) = ':')
                SET @TotalStart = @TotalStart + 1;
            
            -- Find the end of the total value (closing brace)
            SET @TotalEnd = CHARINDEX('}', @LineItemsJSON, @TotalStart);
            IF @TotalEnd = 0 BREAK;
            SET @Total = CAST(LTRIM(RTRIM(SUBSTRING(@LineItemsJSON, @TotalStart, @TotalEnd - @TotalStart))) AS DECIMAL(15,4));
            
            -- Insert parsed values
            INSERT INTO @LineItems (sku, name, quantity, price, total)
            VALUES (@Sku, @Name, @Quantity, @Price, @Total);
            
            -- Move to next object (skip past closing brace and comma if present)
            SET @Pos = @TotalEnd + 1;
            -- Skip comma if present
            IF @Pos <= LEN(@LineItemsJSON) AND SUBSTRING(@LineItemsJSON, @Pos, 1) = ','
                SET @Pos = @Pos + 1;
            -- Skip any whitespace after comma
            WHILE @Pos <= LEN(@LineItemsJSON) AND SUBSTRING(@LineItemsJSON, @Pos, 1) = ' '
                SET @Pos = @Pos + 1;
        END
        
        -- Check if any items were parsed
        SELECT @ItemCount = COUNT(*) FROM @LineItems;
        IF @ItemCount = 0
        BEGIN
            SET @ErrorMessage = 'No line items could be parsed from JSON';
            RETURN;
        END
        
        -- Process each line item
        DECLARE line_cursor CURSOR FOR
        SELECT sku, name, quantity, price, total
        FROM @LineItems;
        
        OPEN line_cursor;
        FETCH NEXT FROM line_cursor INTO @ItemNo, @Descr, @QtySold, @Prc, @LineTotal;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @LineSeqNo = @LineSeqNo + 1;
            
            -- Validate item exists
            IF NOT EXISTS (SELECT 1 FROM dbo.IM_ITEM WHERE ITEM_NO = @ItemNo)
            BEGIN
                SET @ErrorMessage = 'Item not found: ' + @ItemNo;
                CLOSE line_cursor;
                DEALLOCATE line_cursor;
                RETURN;
            END
            
            -- Get item details (SELL_UNIT and STK_LOC_ID don't exist in IM_ITEM - use defaults)
            SELECT 
                @CategCod = CATEG_COD
            FROM dbo.IM_ITEM
            WHERE ITEM_NO = @ItemNo;
            
            -- Set defaults for SELL_UNIT and STK_LOC_ID (these are PS_DOC_LIN columns, not IM_ITEM)
            SET @SellUnit = '0';  -- Default selling unit code
            SET @StkLocId = '01'; -- Default stock location
            
            -- Calculate extended price (round to 2 decimal places to match table definition)
            SET @ExtPrc = CAST(ROUND(@QtySold * CAST(@Prc AS DECIMAL(15,4)), 2) AS DECIMAL(15,2));
            SET @GrossExtPrc = @ExtPrc;  -- Gross extended price (same as EXT_PRC for now)
            
            -- Calculate line discount (if any)
            SET @LineDisc = (@QtySold * @Prc) - @LineTotal;
            IF @LineDisc < 0 SET @LineDisc = 0;
            SET @TotLinDisc = @TotLinDisc + @LineDisc;
            
            -- Create line item
            -- Include ALL required columns without defaults: DOC_ID, LIN_SEQ_NO, STR_ID, STA_ID, TKT_NO, LIN_TYP, ITEM_NO, QTY_SOLD, SELL_UNIT, EXT_PRC, LIN_GUID, GROSS_EXT_PRC, CALC_EXT_PRC
            INSERT INTO dbo.PS_DOC_LIN (
                DOC_ID, LIN_SEQ_NO, STR_ID, STA_ID, TKT_NO, LIN_TYP, ITEM_NO, DESCR,
                QTY_SOLD, SELL_UNIT, PRC, EXT_PRC,
                STK_LOC_ID, CATEG_COD, LIN_GUID, GROSS_EXT_PRC, CALC_EXT_PRC
            )
            VALUES (
                @DocID, @LineSeqNo, @StrId, @StaId, @TktNo, @LinTyp, @ItemNo, LEFT(@Descr, 250),
                @QtySold, @SellUnit, @Prc, @ExtPrc,
                @StkLocId, @CategCod, NEWID(), @GrossExtPrc, @ExtPrc
            );
            
            SET @LinesCreated = @LinesCreated + 1;
            
            FETCH NEXT FROM line_cursor INTO @ItemNo, @Descr, @QtySold, @Prc, @LineTotal;
        END
        
        CLOSE line_cursor;
        DEALLOCATE line_cursor;
        
        SET @Success = 1;
        
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('global', 'line_cursor') >= 0
        BEGIN
            CLOSE line_cursor;
            DEALLOCATE line_cursor;
        END
        
        SET @Success = 0;
        SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH
END
GO

PRINT '   ✅ sp_CreateOrderLines created';
PRINT '';

-- ============================================
-- 3. Deploy sp_CreateOrderFromStaging
-- ============================================
PRINT '3. Deploying sp_CreateOrderFromStaging...';
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

PRINT '   ✅ sp_CreateOrderFromStaging created';
PRINT '';

-- ============================================
-- Summary
-- ============================================
PRINT '============================================';
PRINT 'DEPLOYMENT COMPLETE';
PRINT '============================================';
PRINT '';
PRINT 'All three stored procedures have been deployed:';
PRINT '  ✅ sp_ValidateStagedOrder';
PRINT '  ✅ sp_CreateOrderLines';
PRINT '  ✅ sp_CreateOrderFromStaging';
PRINT '';
PRINT 'You can now:';
PRINT '  1. Run the SQL test script: 02_Testing/TEST_ORDER_STORED_PROCEDURES.sql';
PRINT '  2. Run the Python test script: python test_order_processor.py';
PRINT '  3. Use cp_order_processor.py to process real orders';
PRINT '';
PRINT '============================================';

-- ============================================
-- sp_CreateOrderLines
-- ============================================
-- Purpose: Parse JSON line items and create PS_DOC_LIN records
--          For Phase 5: Order Creation
-- ============================================
-- Parameters:
--   @DocID - Document ID from PS_DOC_HDR
--   @LineItemsJSON - JSON array of line items
-- Returns:
--   @LinesCreated - Number of lines created
--   @TotLinDisc - Total line discounts
--   @Success - 1 if successful, 0 if failed
--   @ErrorMessage - Error message if failed
-- ============================================

USE WOODYS_CP;
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
            
            -- Update inventory after creating line item
            -- CounterPoint does NOT auto-update inventory, so we must do it manually
            -- Note: QTY_AVAIL is a computed column (calculated automatically by CounterPoint)
            --       We only update QTY_ON_SO, and CounterPoint will recalculate QTY_AVAIL
            -- Ensure inventory record exists for item/location
            IF NOT EXISTS (SELECT 1 FROM dbo.IM_INV WHERE ITEM_NO = @ItemNo AND LOC_ID = @StkLocId)
            BEGIN
                -- Create inventory record if it doesn't exist (with all required NOT NULL columns)
                INSERT INTO dbo.IM_INV (
                    ITEM_NO, LOC_ID,
                    MIN_QTY, MAX_QTY, QTY_COMMIT,
                    QTY_ON_HND, QTY_ON_PO, QTY_ON_BO, QTY_ON_XFER_OUT, QTY_ON_XFER_IN,
                    QTY_ON_ORD, QTY_ON_LWY, QTY_ON_SO,
                    LST_AVG_COST, LST_COST, STD_COST, COST_OF_SLS_PCT, GL_VAL,
                    RS_STAT, DROPSHIP_QTY_ON_CUST_ORD, DROPSHIP_QTY_ON_PO
                )
                VALUES (
                    @ItemNo, @StkLocId,
                    0, 0, 0,  -- MIN_QTY, MAX_QTY, QTY_COMMIT
                    0, 0, 0, 0, 0,  -- QTY_ON_HND, QTY_ON_PO, QTY_ON_BO, QTY_ON_XFER_OUT, QTY_ON_XFER_IN
                    0, 0, 0,  -- QTY_ON_ORD, QTY_ON_LWY, QTY_ON_SO
                    0, 0, 0, 0, 0,  -- LST_AVG_COST, LST_COST, STD_COST, COST_OF_SLS_PCT, GL_VAL
                    1, 0, 0  -- RS_STAT (default 1), DROPSHIP_QTY_ON_CUST_ORD, DROPSHIP_QTY_ON_PO
                );
            END
            
            -- Update inventory quantities
            -- QTY_ON_SO: Increase by order quantity (quantity on sales order - tracks allocated inventory)
            -- Note: QTY_AVAIL is a computed column (cannot be updated directly)
            --       CounterPoint's QTY_AVAIL formula does NOT include QTY_ON_SO, so it won't auto-update
            --       This is expected behavior - QTY_ON_SO tracks orders, QTY_AVAIL may use different formula
            UPDATE dbo.IM_INV
            SET QTY_ON_SO = QTY_ON_SO + @QtySold
            WHERE ITEM_NO = @ItemNo 
              AND LOC_ID = @StkLocId;
            
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

PRINT 'Created sp_CreateOrderLines';

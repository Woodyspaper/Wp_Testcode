-- Fix sp_CreateOrderLines to handle JSON with extra fields
-- Fix: Check for comma before closing brace when parsing "total" field

USE WOODYS_CP;
GO

IF OBJECT_ID('dbo.sp_CreateOrderLines', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_CreateOrderLines;
GO

CREATE PROCEDURE dbo.sp_CreateOrderLines
    @DocID BIGINT,
    @TktNo VARCHAR(15),
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
    DECLARE @ExtPrc DECIMAL(15,2);
    DECLARE @SellUnit VARCHAR(1);
    DECLARE @StkLocId VARCHAR(10);
    DECLARE @CategCod VARCHAR(10);
    DECLARE @LineDisc DECIMAL(15,4);
    DECLARE @LineTotal DECIMAL(15,4);
    DECLARE @ItemCount INT = 0;
    DECLARE @StrId VARCHAR(10) = '01';
    DECLARE @StaId VARCHAR(10) = '101';
    DECLARE @DocTyp VARCHAR(1) = 'O';
    DECLARE @LinTyp VARCHAR(1) = 'S';
    DECLARE @GrossExtPrc DECIMAL(15,2);
    
    SET @LinesCreated = 0;
    SET @TotLinDisc = 0;
    SET @Success = 0;
    SET @ErrorMessage = '';
    
    BEGIN TRY
        IF @LineItemsJSON IS NULL OR @LineItemsJSON = ''
        BEGIN
            SET @ErrorMessage = 'Line items JSON is empty';
            RETURN;
        END
        
        DECLARE @LineItems TABLE (
            sku NVARCHAR(50),
            name NVARCHAR(255),
            quantity DECIMAL(15,4),
            price DECIMAL(15,4),
            total DECIMAL(15,4)
        );
        
        DECLARE @Pos INT = 1;
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
        
        WHILE @Pos <= LEN(@LineItemsJSON)
        BEGIN
            SET @SkuStart = CHARINDEX('"sku"', @LineItemsJSON, @Pos);
            IF @SkuStart = 0 BREAK;
            
            SET @SkuStart = @SkuStart + 5;
            WHILE @SkuStart <= LEN(@LineItemsJSON) AND (SUBSTRING(@LineItemsJSON, @SkuStart, 1) = ' ' OR SUBSTRING(@LineItemsJSON, @SkuStart, 1) = ':')
                SET @SkuStart = @SkuStart + 1;
            IF SUBSTRING(@LineItemsJSON, @SkuStart, 1) = '"'
                SET @SkuStart = @SkuStart + 1;
            
            SET @SkuEnd = CHARINDEX('"', @LineItemsJSON, @SkuStart);
            IF @SkuEnd = 0 BREAK;
            SET @Sku = SUBSTRING(@LineItemsJSON, @SkuStart, @SkuEnd - @SkuStart);
            
            SET @NameStart = CHARINDEX('"name"', @LineItemsJSON, @SkuEnd);
            IF @NameStart = 0 BREAK;
            SET @NameStart = @NameStart + 6;
            WHILE @NameStart <= LEN(@LineItemsJSON) AND (SUBSTRING(@LineItemsJSON, @NameStart, 1) = ' ' OR SUBSTRING(@LineItemsJSON, @NameStart, 1) = ':')
                SET @NameStart = @NameStart + 1;
            IF SUBSTRING(@LineItemsJSON, @NameStart, 1) = '"'
                SET @NameStart = @NameStart + 1;
            
            SET @NameEnd = CHARINDEX('"', @LineItemsJSON, @NameStart);
            IF @NameEnd = 0 BREAK;
            SET @Name = SUBSTRING(@LineItemsJSON, @NameStart, @NameEnd - @NameStart);
            
            SET @QtyStart = CHARINDEX('"quantity"', @LineItemsJSON, @NameEnd);
            IF @QtyStart = 0 BREAK;
            SET @QtyStart = @QtyStart + 10;
            WHILE @QtyStart <= LEN(@LineItemsJSON) AND (SUBSTRING(@LineItemsJSON, @QtyStart, 1) = ' ' OR SUBSTRING(@LineItemsJSON, @QtyStart, 1) = ':')
                SET @QtyStart = @QtyStart + 1;
            
            SET @QtyEnd = CHARINDEX(',', @LineItemsJSON, @QtyStart);
            IF @QtyEnd = 0 OR @QtyEnd > CHARINDEX('}', @LineItemsJSON, @QtyStart)
                SET @QtyEnd = CHARINDEX('}', @LineItemsJSON, @QtyStart);
            IF @QtyEnd = 0 BREAK;
            SET @Quantity = CAST(LTRIM(RTRIM(SUBSTRING(@LineItemsJSON, @QtyStart, @QtyEnd - @QtyStart))) AS DECIMAL(15,4));
            
            SET @PriceStart = CHARINDEX('"price"', @LineItemsJSON, @QtyEnd);
            IF @PriceStart = 0 BREAK;
            SET @PriceStart = @PriceStart + 7;
            WHILE @PriceStart <= LEN(@LineItemsJSON) AND (SUBSTRING(@LineItemsJSON, @PriceStart, 1) = ' ' OR SUBSTRING(@LineItemsJSON, @PriceStart, 1) = ':')
                SET @PriceStart = @PriceStart + 1;
            
            SET @PriceEnd = CHARINDEX(',', @LineItemsJSON, @PriceStart);
            IF @PriceEnd = 0 OR @PriceEnd > CHARINDEX('}', @LineItemsJSON, @PriceStart)
                SET @PriceEnd = CHARINDEX('}', @LineItemsJSON, @PriceStart);
            IF @PriceEnd = 0 BREAK;
            SET @Price = CAST(LTRIM(RTRIM(SUBSTRING(@LineItemsJSON, @PriceStart, @PriceEnd - @PriceStart))) AS DECIMAL(15,4));
            
            SET @TotalStart = CHARINDEX('"total"', @LineItemsJSON, @PriceEnd);
            IF @TotalStart = 0 BREAK;
            SET @TotalStart = @TotalStart + 7;
            WHILE @TotalStart <= LEN(@LineItemsJSON) AND (SUBSTRING(@LineItemsJSON, @TotalStart, 1) = ' ' OR SUBSTRING(@LineItemsJSON, @TotalStart, 1) = ':')
                SET @TotalStart = @TotalStart + 1;
            
            -- FIX: Check for comma first (if there are more fields after "total")
            SET @TotalEnd = CHARINDEX(',', @LineItemsJSON, @TotalStart);
            IF @TotalEnd = 0 OR @TotalEnd > CHARINDEX('}', @LineItemsJSON, @TotalStart)
                SET @TotalEnd = CHARINDEX('}', @LineItemsJSON, @TotalStart);
            IF @TotalEnd = 0 BREAK;
            SET @Total = CAST(LTRIM(RTRIM(SUBSTRING(@LineItemsJSON, @TotalStart, @TotalEnd - @TotalStart))) AS DECIMAL(15,4));
            
            INSERT INTO @LineItems (sku, name, quantity, price, total)
            VALUES (@Sku, @Name, @Quantity, @Price, @Total);
            
            SET @Pos = @TotalEnd + 1;
            IF @Pos <= LEN(@LineItemsJSON) AND SUBSTRING(@LineItemsJSON, @Pos, 1) = ','
                SET @Pos = @Pos + 1;
            WHILE @Pos <= LEN(@LineItemsJSON) AND SUBSTRING(@LineItemsJSON, @Pos, 1) = ' '
                SET @Pos = @Pos + 1;
        END
        
        SELECT @ItemCount = COUNT(*) FROM @LineItems;
        IF @ItemCount = 0
        BEGIN
            SET @ErrorMessage = 'No line items could be parsed from JSON';
            RETURN;
        END
        
        DECLARE line_cursor CURSOR FOR
        SELECT sku, name, quantity, price, total
        FROM @LineItems;
        
        OPEN line_cursor;
        FETCH NEXT FROM line_cursor INTO @ItemNo, @Descr, @QtySold, @Prc, @LineTotal;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @LineSeqNo = @LineSeqNo + 1;
            
            IF NOT EXISTS (SELECT 1 FROM dbo.IM_ITEM WHERE ITEM_NO = @ItemNo)
            BEGIN
                SET @ErrorMessage = 'Item not found: ' + @ItemNo;
                CLOSE line_cursor;
                DEALLOCATE line_cursor;
                RETURN;
            END
            
            SET @ExtPrc = @Prc * @QtySold;
            SET @GrossExtPrc = @ExtPrc;
            SET @LineDisc = 0;
            SET @SellUnit = 'E';
            SET @StkLocId = @StrId;
            
            INSERT INTO dbo.PS_DOC_LIN (
                DOC_ID, TKT_NO, LIN_SEQ_NO, ITEM_NO, DESCR,
                QTY_SOLD, PRC, EXT_PRC, SELL_UNIT, STK_LOC_ID,
                LIN_TYP, DOC_TYP, STR_ID, STA_ID, GROSS_EXT_PRC
            ) VALUES (
                @DocID, @TktNo, @LineSeqNo, @ItemNo, @Descr,
                @QtySold, @Prc, @ExtPrc, @SellUnit, @StkLocId,
                @LinTyp, @DocTyp, @StrId, @StaId, @GrossExtPrc
            );
            
            SET @TotLinDisc = @TotLinDisc + @LineDisc;
            SET @LinesCreated = @LinesCreated + 1;
            
            FETCH NEXT FROM line_cursor INTO @ItemNo, @Descr, @QtySold, @Prc, @LineTotal;
        END
        
        CLOSE line_cursor;
        DEALLOCATE line_cursor;
        
        SET @Success = 1;
    END TRY
    BEGIN CATCH
        SET @ErrorMessage = 'Error creating line items: ' + ERROR_MESSAGE();
        IF CURSOR_STATUS('global', 'line_cursor') >= 0
        BEGIN
            CLOSE line_cursor;
            DEALLOCATE line_cursor;
        END
    END CATCH
END

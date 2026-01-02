-- ============================================
-- TEST JSON PARSING LOGIC
-- ============================================
-- Purpose: Test the JSON parsing logic used in sp_CreateOrderLines
-- ============================================

USE WOODYS_CP;
GO

DECLARE @LineItemsJSON NVARCHAR(MAX);
SET @LineItemsJSON = '[{"sku":"01-10100","name":"Test Product 1","quantity":2,"price":10.50,"total":21.00},{"sku":"01-10102","name":"Test Product 2","quantity":1,"price":15.75,"total":15.75}]';

PRINT 'Testing JSON: ' + @LineItemsJSON;
PRINT '';

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

-- Find each JSON object and extract values
WHILE @Pos <= LEN(@LineItemsJSON)
BEGIN
    -- Find next SKU field
    SET @SkuStart = CHARINDEX('"sku":"', @LineItemsJSON, @Pos);
    IF @SkuStart = 0 BREAK;  -- No more items found
    
    PRINT 'Found SKU at position: ' + CAST(@SkuStart AS VARCHAR);
    
    SET @SkuStart = @SkuStart + 7;  -- Move past '"sku":"'
    SET @SkuEnd = CHARINDEX('"', @LineItemsJSON, @SkuStart);
    IF @SkuEnd = 0 BREAK;  -- Invalid JSON format
    SET @Sku = SUBSTRING(@LineItemsJSON, @SkuStart, @SkuEnd - @SkuStart);
    PRINT '  SKU: ' + @Sku;
    
    -- Find Name
    SET @NameStart = CHARINDEX('"name":"', @LineItemsJSON, @SkuEnd);
    IF @NameStart = 0 BREAK;
    SET @NameStart = @NameStart + 8;  -- Move past '"name":"'
    SET @NameEnd = CHARINDEX('"', @LineItemsJSON, @NameStart);
    IF @NameEnd = 0 BREAK;
    SET @Name = SUBSTRING(@LineItemsJSON, @NameStart, @NameEnd - @NameStart);
    PRINT '  Name: ' + @Name;
    
    -- Find Quantity
    SET @QtyStart = CHARINDEX('"quantity":', @LineItemsJSON, @NameEnd);
    IF @QtyStart = 0 BREAK;
    SET @QtyStart = @QtyStart + 11;  -- Move past '"quantity":'
    -- Find the end of the quantity value (comma or closing brace)
    SET @QtyEnd = CHARINDEX(',', @LineItemsJSON, @QtyStart);
    IF @QtyEnd = 0 OR @QtyEnd > CHARINDEX('}', @LineItemsJSON, @QtyStart)
        SET @QtyEnd = CHARINDEX('}', @LineItemsJSON, @QtyStart);
    IF @QtyEnd = 0 BREAK;
    SET @Quantity = CAST(LTRIM(RTRIM(SUBSTRING(@LineItemsJSON, @QtyStart, @QtyEnd - @QtyStart))) AS DECIMAL(15,4));
    PRINT '  Quantity: ' + CAST(@Quantity AS VARCHAR);
    
    -- Find Price
    SET @PriceStart = CHARINDEX('"price":', @LineItemsJSON, @QtyEnd);
    IF @PriceStart = 0 BREAK;
    SET @PriceStart = @PriceStart + 8;  -- Move past '"price":'
    -- Find the end of the price value (comma or closing brace)
    SET @PriceEnd = CHARINDEX(',', @LineItemsJSON, @PriceStart);
    IF @PriceEnd = 0 OR @PriceEnd > CHARINDEX('}', @LineItemsJSON, @PriceStart)
        SET @PriceEnd = CHARINDEX('}', @LineItemsJSON, @PriceStart);
    IF @PriceEnd = 0 BREAK;
    SET @Price = CAST(LTRIM(RTRIM(SUBSTRING(@LineItemsJSON, @PriceStart, @PriceEnd - @PriceStart))) AS DECIMAL(15,4));
    PRINT '  Price: ' + CAST(@Price AS VARCHAR);
    
    -- Find Total
    SET @TotalStart = CHARINDEX('"total":', @LineItemsJSON, @PriceEnd);
    IF @TotalStart = 0 BREAK;
    SET @TotalStart = @TotalStart + 8;  -- Move past '"total":'
    -- Find the end of the total value (closing brace)
    SET @TotalEnd = CHARINDEX('}', @LineItemsJSON, @TotalStart);
    IF @TotalEnd = 0 BREAK;
    SET @Total = CAST(LTRIM(RTRIM(SUBSTRING(@LineItemsJSON, @TotalStart, @TotalEnd - @TotalStart))) AS DECIMAL(15,4));
    PRINT '  Total: ' + CAST(@Total AS VARCHAR);
    
    -- Insert parsed values
    INSERT INTO @LineItems (sku, name, quantity, price, total)
    VALUES (@Sku, @Name, @Quantity, @Price, @Total);
    
    PRINT '  Inserted item into table variable';
    PRINT '';
    
    -- Move to next object (skip past closing brace and comma if present)
    SET @Pos = @TotalEnd + 1;
    -- Skip comma if present
    IF @Pos <= LEN(@LineItemsJSON) AND SUBSTRING(@LineItemsJSON, @Pos, 1) = ','
        SET @Pos = @Pos + 1;
    
    PRINT '  Next position: ' + CAST(@Pos AS VARCHAR);
    PRINT '';
END

-- Show results
PRINT '============================================';
PRINT 'PARSED ITEMS:';
PRINT '============================================';
SELECT * FROM @LineItems;
PRINT 'Total items parsed: ' + CAST((SELECT COUNT(*) FROM @LineItems) AS VARCHAR);
GO

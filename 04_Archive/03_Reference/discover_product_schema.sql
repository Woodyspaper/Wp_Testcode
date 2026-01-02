USE WOODYS_CP;
GO

-- ============================================
-- DISCOVERY: Product Export View Schema Investigation
-- ============================================
-- Let's understand the actual data types and values before fixing the view
-- ============================================

-- 1. Check IM_ITEM table structure - focus on e-commerce fields
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE,
    COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
    AND TABLE_NAME = 'IM_ITEM'
    AND COLUMN_NAME IN ('IS_ECOMM_ITEM', 'ECOMM_PUB_STAT', 'DESCR', 'SHORT_DESCR', 'LONG_DESCR', 'ITEM_NO', 'CATEG_COD')
ORDER BY ORDINAL_POSITION;
GO

-- 2. Check EC_ITEM_DESCR table structure
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
    AND TABLE_NAME = 'EC_ITEM_DESCR'
    AND COLUMN_NAME IN ('ITEM_NO', 'HTML_DESCR')
ORDER BY ORDINAL_POSITION;
GO

-- 3. Sample actual values for IS_ECOMM_ITEM
SELECT DISTINCT
    IS_ECOMM_ITEM,
    COUNT(*) AS COUNT,
    'Sample ITEM_NO' = MIN(ITEM_NO)
FROM dbo.IM_ITEM
GROUP BY IS_ECOMM_ITEM;
GO

-- 4. Sample actual values for ECOMM_PUB_STAT (if it exists and has data)
SELECT TOP 20
    ITEM_NO,
    IS_ECOMM_ITEM,
    ECOMM_PUB_STAT,
    CASE 
        WHEN ECOMM_PUB_STAT IS NULL THEN 'NULL'
        ELSE 'HAS_VALUE'
    END AS STATUS_CHECK
FROM dbo.IM_ITEM
WHERE IS_ECOMM_ITEM = 'Y'
ORDER BY ITEM_NO;
GO

-- 5. Check what data types DESCR, SHORT_DESCR, LONG_DESCR actually are
SELECT TOP 5
    ITEM_NO,
    DESCR,
    SHORT_DESCR,
    CASE 
        WHEN LONG_DESCR IS NULL THEN 'NULL'
        WHEN DATALENGTH(LONG_DESCR) = 0 THEN 'EMPTY'
        ELSE 'HAS_DATA'
    END AS LONG_DESCR_STATUS
FROM dbo.IM_ITEM
WHERE IS_ECOMM_ITEM = 'Y'
ORDER BY ITEM_NO;
GO

-- 6. Check if EC_ITEM_DESCR table exists and has data
IF OBJECT_ID('dbo.EC_ITEM_DESCR', 'U') IS NOT NULL
BEGIN
    SELECT TOP 5
        ITEM_NO,
        CASE 
            WHEN HTML_DESCR IS NULL THEN 'NULL'
            WHEN DATALENGTH(HTML_DESCR) = 0 THEN 'EMPTY'
            ELSE 'HAS_DATA'
        END AS HTML_DESCR_STATUS
    FROM dbo.EC_ITEM_DESCR
    ORDER BY ITEM_NO;
END
ELSE
BEGIN
    SELECT 'EC_ITEM_DESCR table does not exist' AS STATUS;
END
GO

-- 7. Check current view definition (if it exists)
IF OBJECT_ID('dbo.VI_EXPORT_PRODUCTS', 'V') IS NOT NULL
BEGIN
    SELECT 
        OBJECT_DEFINITION(OBJECT_ID('dbo.VI_EXPORT_PRODUCTS')) AS VIEW_DEFINITION;
END
ELSE
BEGIN
    SELECT 'VI_EXPORT_PRODUCTS view does not exist' AS STATUS;
END
GO

-- 8. Test a simple query on IM_ITEM to see what works
SELECT TOP 5
    ITEM_NO,
    CAST(DESCR AS NVARCHAR(MAX)) AS DESCR_TEST,
    IS_ECOMM_ITEM,
    ECOMM_PUB_STAT
FROM dbo.IM_ITEM
WHERE IS_ECOMM_ITEM = 'Y'
ORDER BY ITEM_NO;
GO


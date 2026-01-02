-- ============================================
-- DISCOVER IM_INV TABLE COLUMNS
-- ============================================
-- Purpose: Find actual column names in IM_INV table
-- ============================================

USE WOODYS_CP;
GO

-- Method 1: Get all column names from INFORMATION_SCHEMA
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    NUMERIC_PRECISION,
    NUMERIC_SCALE,
    IS_NULLABLE,
    COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'IM_INV'
ORDER BY ORDINAL_POSITION;

-- Method 2: Get sample data to see actual structure
PRINT '';
PRINT 'Sample data from IM_INV (first 5 rows):';
PRINT '';

SELECT TOP 5 *
FROM dbo.IM_INV
ORDER BY ITEM_NO;

-- Method 3: Check for location-related columns
PRINT '';
PRINT 'Location-related columns:';
PRINT '';

SELECT 
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'IM_INV'
  AND (
      COLUMN_NAME LIKE '%LOC%'
      OR COLUMN_NAME LIKE '%STK%'
      OR COLUMN_NAME LIKE '%QTY%'
      OR COLUMN_NAME LIKE '%ALLOC%'
  )
ORDER BY COLUMN_NAME;

GO

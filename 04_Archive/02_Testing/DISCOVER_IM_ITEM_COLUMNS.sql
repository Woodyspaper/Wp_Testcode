-- Discover actual column names in IM_ITEM table
-- Date: December 30, 2025

-- Method 1: Get all column names
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'IM_ITEM'
ORDER BY ORDINAL_POSITION;

-- Method 2: Get sample data to see column names
SELECT TOP 1 *
FROM dbo.IM_ITEM
WHERE ITEM_NO = '01-10100';

-- Method 3: Search for location-related columns
SELECT 
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'IM_ITEM'
  AND (
      COLUMN_NAME LIKE '%LOC%'
      OR COLUMN_NAME LIKE '%STK%'
      OR COLUMN_NAME LIKE '%PRC%'
  )
ORDER BY COLUMN_NAME;

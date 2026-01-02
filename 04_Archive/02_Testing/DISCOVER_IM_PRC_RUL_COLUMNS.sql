-- Discover actual column names in IM_PRC_RUL table
-- Date: December 30, 2025

-- Method 1: Get all column names
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'IM_PRC_RUL'
ORDER BY ORDINAL_POSITION;

-- Method 2: Get sample data to see column names
SELECT TOP 1 *
FROM dbo.IM_PRC_RUL
WHERE GRP_TYP = 'C';  -- Contract type

-- Method 3: Search for group-related columns
SELECT 
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'IM_PRC_RUL'
  AND (
      COLUMN_NAME LIKE '%GRP%'
      OR COLUMN_NAME LIKE '%GROUP%'
      OR COLUMN_NAME LIKE '%NAM%'
      OR COLUMN_NAME LIKE '%DESCR%'
  )
ORDER BY COLUMN_NAME;

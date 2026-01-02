-- Discover the actual column name for customer group/contract group
-- Date: December 30, 2025

-- Method 1: Search for group-related columns in AR_CUST
SELECT 
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'AR_CUST'
  AND (
      COLUMN_NAME LIKE '%GRP%'
      OR COLUMN_NAME LIKE '%GROUP%'
      OR COLUMN_NAME LIKE '%CONTRACT%'
      OR COLUMN_NAME LIKE '%CATEG%'
  )
ORDER BY COLUMN_NAME;

-- Method 2: Check contract pricing rules table to see how customers are linked
SELECT TOP 5
    GRP_COD,
    GRP_NAM,
    GRP_TYP,
    RUL_SEQ_NO,
    ITEM_FILT_TEXT
FROM dbo.IM_PRC_RUL
WHERE GRP_TYP = 'C'  -- Contract type
ORDER BY GRP_COD;

-- Method 3: Check if there's a relationship table
-- Look for tables that might link customers to groups
SELECT 
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'dbo'
  AND (
      TABLE_NAME LIKE '%CUST%GRP%'
      OR TABLE_NAME LIKE '%GRP%CUST%'
      OR TABLE_NAME LIKE '%CONTRACT%'
  )
ORDER BY TABLE_NAME;

-- Method 4: Check sample customer data to see all columns
SELECT TOP 1 *
FROM dbo.AR_CUST;

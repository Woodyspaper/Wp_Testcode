-- ============================================
-- DISCOVER PS_DOC_HDR COLUMNS
-- ============================================
-- Purpose: Discover actual column names in PS_DOC_HDR table
--          For Phase 5: Order Creation
-- ============================================

USE WOODYS_CP;
GO

-- Get all columns from PS_DOC_HDR
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE,
    COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'PS_DOC_HDR'
ORDER BY ORDINAL_POSITION;

-- Sample row to see actual data
-- First, discover what date columns actually exist
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'PS_DOC_HDR'
  AND (COLUMN_NAME LIKE '%DAT%' OR COLUMN_NAME LIKE '%DATE%' OR COLUMN_NAME LIKE '%TIM%' OR COLUMN_NAME LIKE '%TIME%')
ORDER BY COLUMN_NAME;

-- Then get a sample row (using DOC_ID which should exist)
SELECT TOP 1 *
FROM dbo.PS_DOC_HDR
ORDER BY DOC_ID DESC;

-- Key columns we need for order creation
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'PS_DOC_HDR'
  AND COLUMN_NAME IN (
    'DOC_ID', 'DOC_TYP', 'CUST_NO', 'DAT', 'TIM',
    'SUBTOT', 'DISC_AMT', 'TAX_AMT', 'TOT_AMT',
    'STR_ID', 'STN_ID', 'EVENT_NO', 'SLS_REP',
    'SHIP_VIA_COD', 'SHIP_DAT', 'SHIP_NAM',
    'SHIP_ADRS_1', 'SHIP_ADRS_2', 'SHIP_CITY',
    'SHIP_STATE', 'SHIP_ZIP_COD', 'SHIP_CNTRY',
    'PMT_METH', 'STAT', 'LST_MAINT_DT'
  )
ORDER BY COLUMN_NAME;

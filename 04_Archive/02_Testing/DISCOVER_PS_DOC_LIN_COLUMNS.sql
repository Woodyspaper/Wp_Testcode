-- ============================================
-- DISCOVER PS_DOC_LIN COLUMNS
-- ============================================
-- Purpose: Discover actual column names in PS_DOC_LIN table
--          For Phase 5: Order Creation
-- ============================================

USE WOODYS_CP;
GO

-- Get all columns from PS_DOC_LIN
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE,
    COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'PS_DOC_LIN'
ORDER BY ORDINAL_POSITION;

-- Sample row to see actual data
-- First, discover what date columns actually exist
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'PS_DOC_LIN'
  AND (COLUMN_NAME LIKE '%DAT%' OR COLUMN_NAME LIKE '%DATE%' OR COLUMN_NAME LIKE '%TIM%' OR COLUMN_NAME LIKE '%TIME%')
ORDER BY COLUMN_NAME;

-- Then get a sample row (using DOC_ID which should exist)
SELECT TOP 1 *
FROM dbo.PS_DOC_LIN
ORDER BY DOC_ID DESC, LIN_SEQ_NO;

-- Key columns we need for order lines
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'PS_DOC_LIN'
  AND COLUMN_NAME IN (
    'DOC_ID', 'LIN_SEQ_NO', 'ITEM_NO', 'DESCR',
    'QTY_ORD', 'QTY_SHIP', 'SELL_UNIT', 'PRC',
    'DISC_AMT', 'TOT_AMT', 'CATEG_COD', 'LOC_ID',
    'STAT', 'LST_MAINT_DT'
  )
ORDER BY COLUMN_NAME;

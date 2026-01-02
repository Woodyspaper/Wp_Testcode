-- ============================================
-- DISCOVER PS_DOC_HDR TOTALS TABLE
-- ============================================
-- Purpose: Find where order totals (SUBTOT, TAX_AMT, TOT_AMT) are stored
--          For Phase 5: Order Creation
-- ============================================

USE WOODYS_CP;
GO

-- Check if PS_DOC_HDR_TOT table exists
IF OBJECT_ID('dbo.PS_DOC_HDR_TOT', 'U') IS NOT NULL
BEGIN
    PRINT 'PS_DOC_HDR_TOT table exists';
    
    -- Get all columns from PS_DOC_HDR_TOT
    SELECT 
        COLUMN_NAME,
        DATA_TYPE,
        CHARACTER_MAXIMUM_LENGTH,
        IS_NULLABLE,
        COLUMN_DEFAULT
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'dbo'
      AND TABLE_NAME = 'PS_DOC_HDR_TOT'
    ORDER BY ORDINAL_POSITION;
    
    -- Sample row
    SELECT TOP 1 *
    FROM dbo.PS_DOC_HDR_TOT
    ORDER BY DOC_ID DESC;
END
ELSE
BEGIN
    PRINT 'PS_DOC_HDR_TOT table does NOT exist';
END
GO

-- Search for tables with "TOT" in name
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME LIKE '%TOT%'
  AND TABLE_NAME LIKE '%DOC%'
ORDER BY TABLE_NAME;

-- Search for columns with "TOT", "SUBTOT", "TAX", "AMT" in PS_DOC_HDR
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'PS_DOC_HDR'
  AND (
    COLUMN_NAME LIKE '%TOT%' OR
    COLUMN_NAME LIKE '%SUBTOT%' OR
    COLUMN_NAME LIKE '%TAX%' OR
    COLUMN_NAME LIKE '%AMT%' OR
    COLUMN_NAME LIKE '%DISC%'
  )
ORDER BY COLUMN_NAME;

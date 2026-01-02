-- ============================================
-- CHECK ALL REQUIRED (NON-NULLABLE) COLUMNS IN PS_DOC_LIN
-- ============================================
-- Purpose: Find ALL non-nullable columns to fix INSERT statement
-- ============================================

USE WOODYS_CP;
GO

-- Get all non-nullable columns
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    NUMERIC_PRECISION,
    NUMERIC_SCALE,
    COLUMN_DEFAULT,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'PS_DOC_LIN'
  AND IS_NULLABLE = 'NO'
ORDER BY ORDINAL_POSITION;

-- Also get a sample row to see what values are typically used
SELECT TOP 1 *
FROM dbo.PS_DOC_LIN
ORDER BY DOC_ID DESC, LIN_SEQ_NO;

GO

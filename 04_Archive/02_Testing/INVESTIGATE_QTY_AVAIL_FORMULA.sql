-- ============================================
-- INVESTIGATE QTY_AVAIL FORMULA
-- ============================================
-- Purpose: Determine if QTY_AVAIL is computed or can be updated
--          and what formula CounterPoint uses
-- ============================================

USE WOODYS_CP;
GO

PRINT '============================================';
PRINT 'INVESTIGATE QTY_AVAIL COLUMN';
PRINT '============================================';
PRINT '';

-- Check if QTY_AVAIL is a computed column
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    COLUMN_DEFAULT,
    -- Check if it's computed
    CASE 
        WHEN COLUMNPROPERTY(OBJECT_ID('dbo.IM_INV'), COLUMN_NAME, 'IsComputed') = 1 
        THEN 'YES - Computed Column'
        ELSE 'NO - Regular Column'
    END AS IsComputed,
    -- Get computed column definition if it exists
    CASE 
        WHEN COLUMNPROPERTY(OBJECT_ID('dbo.IM_INV'), COLUMN_NAME, 'IsComputed') = 1 
        THEN OBJECT_DEFINITION(OBJECT_ID('dbo.IM_INV'))
        ELSE NULL
    END AS ComputedDefinition
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'IM_INV'
  AND COLUMN_NAME = 'QTY_AVAIL';

PRINT '';
PRINT '============================================';
PRINT 'SAMPLE DATA: Check QTY_AVAIL vs Other Fields';
PRINT '============================================';
PRINT '';

-- Get sample data to see relationship between QTY_AVAIL and other quantities
SELECT TOP 10
    ITEM_NO,
    LOC_ID,
    QTY_ON_HND,
    QTY_AVAIL,
    QTY_ON_SO,
    QTY_COMMIT,
    QTY_ON_ORD,
    QTY_ON_LWY,
    -- Try to calculate what QTY_AVAIL might be
    QTY_ON_HND - ISNULL(QTY_ON_SO, 0) - ISNULL(QTY_COMMIT, 0) - ISNULL(QTY_ON_ORD, 0) - ISNULL(QTY_ON_LWY, 0) AS Calculated_Available,
    -- Compare to actual QTY_AVAIL
    QTY_AVAIL - (QTY_ON_HND - ISNULL(QTY_ON_SO, 0) - ISNULL(QTY_COMMIT, 0) - ISNULL(QTY_ON_ORD, 0) - ISNULL(QTY_ON_LWY, 0)) AS Difference
FROM dbo.IM_INV
WHERE QTY_ON_HND > 0
ORDER BY ITEM_NO, LOC_ID;

PRINT '';
PRINT '============================================';
PRINT 'TEST: Try to UPDATE QTY_AVAIL directly';
PRINT '============================================';
PRINT '';

-- Test if we can update QTY_AVAIL (this will fail if it's computed)
-- We'll use a test item that we know exists
DECLARE @TestItem VARCHAR(20) = '01-10100';
DECLARE @TestLoc VARCHAR(10) = '01';
DECLARE @CurrentQtyAvail DECIMAL(15,4);
DECLARE @NewQtyAvail DECIMAL(15,4);

-- Get current value
SELECT @CurrentQtyAvail = QTY_AVAIL
FROM dbo.IM_INV
WHERE ITEM_NO = @TestItem AND LOC_ID = @TestLoc;

PRINT 'Current QTY_AVAIL for ' + @TestItem + ' (LOC ' + @TestLoc + '): ' + CAST(@CurrentQtyAvail AS VARCHAR);
PRINT '';

-- Try to update it (this will show us if it's updatable)
BEGIN TRY
    SET @NewQtyAvail = @CurrentQtyAvail - 1.0;
    
    UPDATE dbo.IM_INV
    SET QTY_AVAIL = @NewQtyAvail
    WHERE ITEM_NO = @TestItem AND LOC_ID = @TestLoc;
    
    PRINT '✅ SUCCESS: QTY_AVAIL can be updated directly';
    PRINT '   Updated to: ' + CAST(@NewQtyAvail AS VARCHAR);
    PRINT '';
    PRINT 'Reverting change...';
    
    -- Revert
    UPDATE dbo.IM_INV
    SET QTY_AVAIL = @CurrentQtyAvail
    WHERE ITEM_NO = @TestItem AND LOC_ID = @TestLoc;
    
    PRINT '   Reverted to original value';
    
END TRY
BEGIN CATCH
    PRINT '❌ ERROR: QTY_AVAIL cannot be updated directly';
    PRINT '   Error: ' + ERROR_MESSAGE();
    PRINT '';
    PRINT 'This suggests QTY_AVAIL is a computed column or has constraints';
END CATCH

PRINT '';
PRINT '============================================';
PRINT 'CHECK FOR TRIGGERS ON IM_INV';
PRINT '============================================';
PRINT '';

-- Check if there are triggers that might update QTY_AVAIL
SELECT 
    t.name AS TriggerName,
    t.is_disabled AS IsDisabled,
    OBJECT_DEFINITION(t.object_id) AS TriggerDefinition
FROM sys.triggers t
INNER JOIN sys.objects o ON t.parent_id = o.object_id
WHERE o.name = 'IM_INV'
  AND o.schema_id = SCHEMA_ID('dbo');

PRINT '';
PRINT '============================================';
PRINT 'CHECK FOR STORED PROCEDURES THAT UPDATE QTY_AVAIL';
PRINT '============================================';
PRINT '';

-- Search for procedures that might update QTY_AVAIL
SELECT 
    OBJECT_NAME(object_id) AS ProcedureName,
    OBJECT_DEFINITION(object_id) AS ProcedureDefinition
FROM sys.procedures
WHERE OBJECT_DEFINITION(object_id) LIKE '%QTY_AVAIL%'
  AND schema_id = SCHEMA_ID('dbo');

GO

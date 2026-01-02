-- ============================================
-- INVESTIGATE INVENTORY AUTO-UPDATE
-- ============================================
-- Purpose: Determine if CounterPoint automatically updates IM_INV
--          when orders are created in PS_DOC_HDR/PS_DOC_LIN
-- ============================================
-- Known IM_INV columns (from existing views):
--   - ITEM_NO (join key)
--   - QTY_ON_HND (quantity on hand)
--   - QTY_AVAIL (available quantity)
-- ============================================
-- This script will:
-- 1. Check for triggers on PS_DOC_HDR/PS_DOC_LIN that might update inventory
-- 2. Find recent orders and check if inventory was affected
-- 3. Get IM_INV structure to confirm columns
-- 4. Provide test queries to verify behavior
-- ============================================

USE WOODYS_CP;
GO

PRINT '';
PRINT '============================================';
PRINT 'INVENTORY AUTO-UPDATE INVESTIGATION';
PRINT '============================================';
PRINT '';

-- ============================================
-- STEP 1: Check for Triggers on PS_DOC_HDR/PS_DOC_LIN
-- ============================================
PRINT 'STEP 1: Checking for triggers on PS_DOC_HDR and PS_DOC_LIN...';
PRINT '';

SELECT 
    t.name AS TriggerName,
    OBJECT_NAME(t.parent_id) AS TableName,
    t.is_disabled AS IsDisabled,
    t.create_date AS CreatedDate,
    t.modify_date AS ModifiedDate
FROM sys.triggers t
WHERE OBJECT_NAME(t.parent_id) IN ('PS_DOC_HDR', 'PS_DOC_LIN')
ORDER BY TableName, TriggerName;

PRINT '';
PRINT 'If triggers exist, they may auto-update inventory.';
PRINT 'If no triggers, CounterPoint likely does NOT auto-update.';
PRINT '';

-- ============================================
-- STEP 2: Get IM_INV Table Structure
-- ============================================
PRINT 'STEP 2: IM_INV table structure...';
PRINT '';

SELECT 
    c.COLUMN_NAME,
    c.DATA_TYPE,
    c.CHARACTER_MAXIMUM_LENGTH,
    c.NUMERIC_PRECISION,
    c.NUMERIC_SCALE,
    c.IS_NULLABLE,
    c.COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS c
WHERE c.TABLE_SCHEMA = 'dbo'
  AND c.TABLE_NAME = 'IM_INV'
ORDER BY c.ORDINAL_POSITION;

PRINT '';
PRINT 'Key columns to check:';
PRINT '  - QTY_ON_HND: Quantity on hand';
PRINT '  - QTY_ALLOC: Allocated quantity (reserved for orders)';
PRINT '  - QTY_AVAIL: Available quantity (QTY_ON_HND - QTY_ALLOC)';
PRINT '';

-- ============================================
-- STEP 3: Find Recent Orders and Their Items
-- ============================================
PRINT 'STEP 3: Finding recent orders (last 7 days)...';
PRINT '';

SELECT TOP 10
    h.DOC_ID,
    h.TKT_NO,
    h.CUST_NO,
    h.TKT_DT,
    h.DOC_TYP,
    COUNT(l.LIN_SEQ_NO) AS LineCount
FROM dbo.PS_DOC_HDR h
INNER JOIN dbo.PS_DOC_LIN l ON l.DOC_ID = h.DOC_ID
WHERE h.TKT_DT >= DATEADD(DAY, -7, GETDATE())
  AND h.DOC_TYP = 'O'  -- Orders only
GROUP BY h.DOC_ID, h.TKT_NO, h.CUST_NO, h.TKT_DT, h.DOC_TYP
ORDER BY h.TKT_DT DESC;

PRINT '';
PRINT 'Use one of these DOC_ID values for testing.';
PRINT '';

-- ============================================
-- STEP 4: Get Items from Recent Orders
-- ============================================
PRINT 'STEP 4: Items from recent orders...';
PRINT '';

SELECT TOP 20
    l.DOC_ID,
    l.ITEM_NO,
    l.QTY_SOLD,
    h.TKT_DT,
    h.TKT_NO
FROM dbo.PS_DOC_LIN l
INNER JOIN dbo.PS_DOC_HDR h ON h.DOC_ID = l.DOC_ID
WHERE h.TKT_DT >= DATEADD(DAY, -7, GETDATE())
  AND h.DOC_TYP = 'O'
ORDER BY h.TKT_DT DESC, l.LIN_SEQ_NO;

PRINT '';
PRINT 'These are the items that should have inventory updated.';
PRINT '';

-- ============================================
-- STEP 5: Check Current Inventory for Order Items
-- ============================================
PRINT 'STEP 5: Current inventory for items in recent orders...';
PRINT '';

-- Note: IM_INV structure may vary - using only ITEM_NO join
-- If location-specific columns exist, they will be discovered by DISCOVER_IM_INV_COLUMNS.sql
SELECT 
    l.ITEM_NO,
    SUM(l.QTY_SOLD) AS TotalQtyOrdered,
    SUM(inv.QTY_ON_HND) AS QTY_ON_HND,
    SUM(inv.QTY_AVAIL) AS QTY_AVAIL,
    h.TKT_DT AS OrderDate,
    h.TKT_NO
FROM dbo.PS_DOC_LIN l
INNER JOIN dbo.PS_DOC_HDR h ON h.DOC_ID = l.DOC_ID
LEFT JOIN dbo.IM_INV inv ON inv.ITEM_NO = l.ITEM_NO
WHERE h.TKT_DT >= DATEADD(DAY, -7, GETDATE())
  AND h.DOC_TYP = 'O'
GROUP BY l.ITEM_NO, h.TKT_DT, h.TKT_NO
ORDER BY h.TKT_DT DESC, l.ITEM_NO;

PRINT '';
PRINT 'Compare QTY_AVAIL to TotalQtyOrdered:';
PRINT '  - If QTY_AVAIL decreased by order quantity → CounterPoint auto-updates';
PRINT '  - If QTY_AVAIL unchanged → CounterPoint does NOT auto-update';
PRINT '';

-- ============================================
-- STEP 6: Test Query - Before Order Creation
-- ============================================
PRINT 'STEP 6: Test query template (run BEFORE creating test order)...';
PRINT '';

PRINT '-- Run this BEFORE creating a test order:';
PRINT 'SELECT ';
PRINT '    ITEM_NO,';
PRINT '    SUM(QTY_ON_HND) AS QTY_ON_HND,';
PRINT '    SUM(QTY_AVAIL) AS QTY_AVAIL,';
PRINT '    GETDATE() AS CheckTime';
PRINT 'FROM dbo.IM_INV';
PRINT 'WHERE ITEM_NO IN (''01-10100'', ''01-10102'')  -- Replace with test items';
PRINT 'GROUP BY ITEM_NO;';
PRINT '';

-- ============================================
-- STEP 7: Test Query - After Order Creation
-- ============================================
PRINT 'STEP 7: Test query template (run AFTER creating test order)...';
PRINT '';

PRINT '-- Run this AFTER creating a test order:';
PRINT 'SELECT ';
PRINT '    ITEM_NO,';
PRINT '    SUM(QTY_ON_HND) AS QTY_ON_HND,';
PRINT '    SUM(QTY_AVAIL) AS QTY_AVAIL,';
PRINT '    GETDATE() AS CheckTime';
PRINT 'FROM dbo.IM_INV';
PRINT 'WHERE ITEM_NO IN (''01-10100'', ''01-10102'')  -- Replace with test items';
PRINT 'GROUP BY ITEM_NO;';
PRINT '';
PRINT '-- Compare results:';
PRINT '-- If QTY_ON_HND or QTY_AVAIL changed → CounterPoint auto-updates';
PRINT '-- If unchanged → Need to add inventory update logic';
PRINT '';

-- ============================================
-- STEP 8: Check for Stored Procedures that Update Inventory
-- ============================================
PRINT 'STEP 8: Checking for stored procedures that update IM_INV...';
PRINT '';

SELECT 
    p.name AS ProcedureName,
    p.create_date AS CreatedDate,
    p.modify_date AS ModifiedDate
FROM sys.procedures p
WHERE p.name LIKE '%INV%'
   OR p.name LIKE '%INVENTORY%'
   OR p.name LIKE '%STOCK%'
ORDER BY p.name;

PRINT '';
PRINT 'If procedures exist, they may be called by triggers or manually.';
PRINT '';

-- ============================================
-- STEP 9: Summary and Recommendations
-- ============================================
PRINT '';
PRINT '============================================';
PRINT 'INVESTIGATION SUMMARY';
PRINT '============================================';
PRINT '';
PRINT 'To determine if CounterPoint auto-updates inventory:';
PRINT '';
PRINT '1. Check triggers above - if triggers exist, they may handle it';
PRINT '2. Compare QTY_ALLOC in STEP 5 to order quantities';
PRINT '3. Run test queries (STEP 6 and 7) with a test order';
PRINT '';
PRINT 'If CounterPoint does NOT auto-update:';
PRINT '  - Add inventory update logic to sp_CreateOrderFromStaging';
PRINT '  - Update IM_INV.QTY_ALLOC when order created';
PRINT '  - Optionally update IM_INV.QTY_ON_HND if orders reduce stock';
PRINT '';
PRINT '============================================';
PRINT '';

GO

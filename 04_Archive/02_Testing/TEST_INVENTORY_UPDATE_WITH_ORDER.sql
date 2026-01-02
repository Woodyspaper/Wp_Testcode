-- ============================================
-- TEST INVENTORY UPDATE WITH ORDER CREATION
-- ============================================
-- Purpose: Test if CounterPoint automatically updates inventory
--          when an order is created
-- ============================================
-- Known IM_INV columns (from existing views):
--   - ITEM_NO (join key)
--   - QTY_ON_HND (quantity on hand)
--   - QTY_AVAIL (available quantity)
-- ============================================
-- Instructions:
-- 1. Run PART 1 to get baseline inventory
-- 2. Create a test order (use existing staging record or create new one)
-- 3. Run PART 2 to check if inventory changed
-- ============================================

USE WOODYS_CP;
GO

-- ============================================
-- PART 1: BASELINE INVENTORY (Run BEFORE creating order)
-- ============================================

PRINT '';
PRINT '============================================';
PRINT 'PART 1: BASELINE INVENTORY (BEFORE ORDER)';
PRINT '============================================';
PRINT '';

-- Get inventory for items that will be in test order
-- Replace ITEM_NO values with items from your test order
DECLARE @TestItems TABLE (ITEM_NO VARCHAR(20));
INSERT INTO @TestItems VALUES ('01-10100'), ('01-10102');  -- Replace with actual test items

-- Note: IM_INV may not have STK_LOC_ID or QTY_ALLOC columns
-- Using SUM to aggregate across all locations if multiple exist
SELECT 
    inv.ITEM_NO,
    SUM(inv.QTY_ON_HND) AS QtyOnHand_Before,
    SUM(inv.QTY_AVAIL) AS QtyAvailable_Before,
    GETDATE() AS CheckTime_Before
FROM dbo.IM_INV inv
INNER JOIN @TestItems t ON t.ITEM_NO = inv.ITEM_NO
GROUP BY inv.ITEM_NO
ORDER BY inv.ITEM_NO;

-- Store baseline values for comparison
DECLARE @Baseline TABLE (
    ITEM_NO VARCHAR(20),
    QTY_ON_HND DECIMAL(15,4),
    QTY_AVAIL DECIMAL(15,4)
);

INSERT INTO @Baseline (ITEM_NO, QTY_ON_HND, QTY_AVAIL)
SELECT 
    inv.ITEM_NO,
    SUM(inv.QTY_ON_HND),
    SUM(inv.QTY_AVAIL)
FROM dbo.IM_INV inv
INNER JOIN @TestItems t ON t.ITEM_NO = inv.ITEM_NO
GROUP BY inv.ITEM_NO;

PRINT '';
PRINT 'Baseline inventory captured.';
PRINT 'Now create a test order using one of these methods:';
PRINT '  1. Use existing staging record: EXEC sp_CreateOrderFromStaging @StagingID = <ID>';
PRINT '  2. Create new staging record and process it';
PRINT '';
PRINT 'After creating the order, run PART 2 below.';
PRINT '';

-- ============================================
-- PART 2: CHECK INVENTORY AFTER ORDER (Run AFTER creating order)
-- ============================================

-- Uncomment and run this section AFTER creating the test order
/*
PRINT '';
PRINT '============================================';
PRINT 'PART 2: INVENTORY AFTER ORDER CREATION';
PRINT '============================================';
PRINT '';

-- Get current inventory (aggregated across all locations)
SELECT 
    inv.ITEM_NO,
    SUM(inv.QTY_ON_HND) AS QtyOnHand_After,
    SUM(inv.QTY_AVAIL) AS QtyAvailable_After,
    GETDATE() AS CheckTime_After
FROM dbo.IM_INV inv
INNER JOIN @TestItems t ON t.ITEM_NO = inv.ITEM_NO
GROUP BY inv.ITEM_NO
ORDER BY inv.ITEM_NO;

-- Compare before and after
SELECT 
    b.ITEM_NO,
    b.QTY_ON_HND AS QtyOnHand_Before,
    SUM(inv.QTY_ON_HND) AS QtyOnHand_After,
    SUM(inv.QTY_ON_HND) - b.QTY_ON_HND AS QtyOnHand_Change,
    b.QTY_AVAIL AS QtyAvailable_Before,
    SUM(inv.QTY_AVAIL) AS QtyAvailable_After,
    SUM(inv.QTY_AVAIL) - b.QTY_AVAIL AS QtyAvailable_Change,
    CASE 
        WHEN SUM(inv.QTY_ON_HND) <> b.QTY_ON_HND OR SUM(inv.QTY_AVAIL) <> b.QTY_AVAIL 
        THEN 'INVENTORY CHANGED - CounterPoint auto-updates'
        ELSE 'INVENTORY UNCHANGED - Need to add update logic'
    END AS Result
FROM @Baseline b
INNER JOIN dbo.IM_INV inv ON inv.ITEM_NO = b.ITEM_NO
GROUP BY b.ITEM_NO, b.QTY_ON_HND, b.QTY_AVAIL
ORDER BY b.ITEM_NO;

-- Get order quantities for comparison
SELECT 
    l.ITEM_NO,
    SUM(l.QTY_SOLD) AS TotalQtyOrdered,
    h.DOC_ID,
    h.TKT_NO,
    h.TKT_DT
FROM dbo.PS_DOC_LIN l
INNER JOIN dbo.PS_DOC_HDR h ON h.DOC_ID = l.DOC_ID
INNER JOIN @TestItems t ON t.ITEM_NO = l.ITEM_NO
WHERE h.TKT_DT >= DATEADD(MINUTE, -5, GETDATE())  -- Orders created in last 5 minutes
  AND h.DOC_TYP = 'O'
GROUP BY l.ITEM_NO, h.DOC_ID, h.TKT_NO, h.TKT_DT
ORDER BY h.TKT_DT DESC, l.ITEM_NO;

PRINT '';
PRINT 'Analysis:';
PRINT '  - If QtyAvailable_Change decreased by order quantity → CounterPoint auto-updates';
PRINT '  - If QtyOnHand_Change decreased by order quantity → CounterPoint reduces stock on order';
PRINT '  - If no changes → CounterPoint does NOT auto-update';
PRINT '';
*/

GO

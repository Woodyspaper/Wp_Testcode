-- ============================================
-- QUICK CHECK: EXISTING ORDER INVENTORY IMPACT
-- ============================================
-- Purpose: Check if existing order (101-000001) affected inventory
--          Compare QTY_ON_SO to order quantities
-- ============================================

USE WOODYS_CP;
GO

PRINT '';
PRINT '============================================';
PRINT 'CHECK EXISTING ORDER INVENTORY IMPACT';
PRINT '============================================';
PRINT '';

-- Check order 101-000001 (created Dec 31, 2025)
SELECT 
    h.TKT_NO,
    h.DOC_ID,
    h.TKT_DT,
    l.ITEM_NO,
    l.QTY_SOLD AS QtyOrdered,
    l.STK_LOC_ID AS OrderLocation,
    inv.LOC_ID AS InvLocation,
    inv.QTY_ON_SO AS QtyOnSalesOrder,
    inv.QTY_AVAIL AS QtyAvailable,
    inv.QTY_ON_HND AS QtyOnHand,
    CASE 
        WHEN inv.QTY_ON_SO >= l.QTY_SOLD THEN 'QTY_ON_SO reflects order (likely auto-updated)'
        WHEN inv.QTY_ON_SO = 0 THEN 'QTY_ON_SO is 0 (may NOT auto-update)'
        ELSE 'QTY_ON_SO exists but doesn''t match order quantity'
    END AS Analysis
FROM dbo.PS_DOC_HDR h
INNER JOIN dbo.PS_DOC_LIN l ON l.DOC_ID = h.DOC_ID
LEFT JOIN dbo.IM_INV inv ON inv.ITEM_NO = l.ITEM_NO 
    AND inv.LOC_ID = ISNULL(l.STK_LOC_ID, '01')
WHERE h.TKT_NO = '101-000001'
  AND h.DOC_TYP = 'O'
ORDER BY l.LIN_SEQ_NO;

PRINT '';
PRINT 'Expected:';
PRINT '  - If CounterPoint auto-updates: QTY_ON_SO should be >= QtyOrdered';
PRINT '  - If CounterPoint does NOT auto-update: QTY_ON_SO should be 0 or unchanged';
PRINT '';

-- Also check current inventory for test items
PRINT '';
PRINT '============================================';
PRINT 'CURRENT INVENTORY FOR TEST ITEMS';
PRINT '============================================';
PRINT '';

SELECT 
    inv.ITEM_NO,
    inv.LOC_ID,
    inv.QTY_ON_SO,
    inv.QTY_AVAIL,
    inv.QTY_ON_HND,
    inv.QTY_COMMIT
FROM dbo.IM_INV inv
WHERE inv.ITEM_NO IN ('01-10100', '01-10102')
ORDER BY inv.ITEM_NO, inv.LOC_ID;

PRINT '';
PRINT 'Baseline from PART 1:';
PRINT '  - 01-10100: QTY_ON_HND = 495.0000, QTY_AVAIL = 15.0000';
PRINT '  - 01-10102: QTY_ON_HND = 0.0000, QTY_AVAIL = 0.0000';
PRINT '';
PRINT 'Order 101-000001 quantities:';
PRINT '  - 01-10100: QtyOrdered = 2.0000';
PRINT '  - 01-10102: QtyOrdered = 1.0000';
PRINT '';
PRINT 'If QTY_ON_SO shows 2+ for 01-10100 and 1+ for 01-10102 → CounterPoint auto-updates';
PRINT 'If QTY_ON_SO is 0 for both → CounterPoint does NOT auto-update';
PRINT '';

GO

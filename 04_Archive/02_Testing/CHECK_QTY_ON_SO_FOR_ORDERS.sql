-- ============================================
-- CHECK QTY_ON_SO FOR RECENT ORDERS
-- ============================================
-- Purpose: Check if QTY_ON_SO (Quantity on Sales Order) reflects
--          the orders we've created
-- ============================================
-- Based on investigation findings:
--   - IM_INV has QTY_ON_SO column (quantity on sales order)
--   - This might be what CounterPoint uses to track allocated inventory
-- ============================================

USE WOODYS_CP;
GO

PRINT '';
PRINT '============================================';
PRINT 'CHECK QTY_ON_SO FOR RECENT ORDERS';
PRINT '============================================';
PRINT '';

-- Get items from recent orders and their QTY_ON_SO
SELECT 
    l.ITEM_NO,
    l.STK_LOC_ID AS LineLocation,
    SUM(l.QTY_SOLD) AS TotalQtyOrdered,
    inv.LOC_ID AS InvLocation,
    inv.QTY_ON_SO AS QtyOnSalesOrder,
    inv.QTY_AVAIL AS QtyAvailable,
    inv.QTY_ON_HND AS QtyOnHand,
    inv.QTY_COMMIT AS QtyCommitted,
    h.TKT_DT AS OrderDate,
    h.TKT_NO,
    h.DOC_ID
FROM dbo.PS_DOC_LIN l
INNER JOIN dbo.PS_DOC_HDR h ON h.DOC_ID = l.DOC_ID
LEFT JOIN dbo.IM_INV inv ON inv.ITEM_NO = l.ITEM_NO 
    AND inv.LOC_ID = ISNULL(l.STK_LOC_ID, '01')  -- Match location (PS_DOC_LIN uses STK_LOC_ID)
WHERE h.TKT_DT >= DATEADD(DAY, -7, GETDATE())
  AND h.DOC_TYP = 'O'
GROUP BY 
    l.ITEM_NO, 
    l.STK_LOC_ID,
    inv.LOC_ID,
    inv.QTY_ON_SO,
    inv.QTY_AVAIL,
    inv.QTY_ON_HND,
    inv.QTY_COMMIT,
    h.TKT_DT,
    h.TKT_NO,
    h.DOC_ID
ORDER BY h.TKT_DT DESC, l.ITEM_NO, l.STK_LOC_ID;

PRINT '';
PRINT 'Analysis:';
PRINT '  - If QTY_ON_SO matches or exceeds TotalQtyOrdered → CounterPoint tracks orders';
PRINT '  - If QTY_ON_SO is 0 or doesn''t match → CounterPoint may NOT auto-update';
PRINT '';

-- Check specific test items
PRINT '';
PRINT '============================================';
PRINT 'SPECIFIC TEST ITEMS (from test order)';
PRINT '============================================';
PRINT '';

SELECT 
    inv.ITEM_NO,
    inv.LOC_ID,
    inv.QTY_ON_SO,
    inv.QTY_AVAIL,
    inv.QTY_ON_HND,
    inv.QTY_COMMIT,
    inv.QTY_ON_ORD,
    inv.QTY_ON_LWY
FROM dbo.IM_INV inv
WHERE inv.ITEM_NO IN ('01-10100', '01-10102')
ORDER BY inv.ITEM_NO, inv.LOC_ID;

PRINT '';
PRINT 'Compare these values to the order quantities:';
PRINT '  - Order 101-000001: 01-10100 (qty 2), 01-10102 (qty 1)';
PRINT '  - If QTY_ON_SO reflects these quantities → CounterPoint auto-updates';
PRINT '';

GO

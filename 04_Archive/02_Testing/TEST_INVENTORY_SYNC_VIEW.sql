-- ============================================
-- TEST INVENTORY SYNC VIEW
-- ============================================
-- Purpose: Verify VI_INVENTORY_SYNC view is working correctly
-- ============================================

USE WOODYS_CP;
GO

-- Test 1: Check view exists and returns data
PRINT 'Test 1: Check view returns data';
SELECT TOP 10 
    SKU,
    WOO_PRODUCT_ID,
    STOCK_QTY,
    CP_STATUS,
    IS_ECOMM_ITEM
FROM dbo.VI_INVENTORY_SYNC
ORDER BY SKU;

-- Test 2: Count total products in view
PRINT '';
PRINT 'Test 2: Count total products';
SELECT 
    COUNT(*) AS TotalProducts,
    SUM(CASE WHEN STOCK_QTY > 0 THEN 1 ELSE 0 END) AS InStock,
    SUM(CASE WHEN STOCK_QTY = 0 THEN 1 ELSE 0 END) AS OutOfStock,
    SUM(CASE WHEN STOCK_QTY < 0 THEN 1 ELSE 0 END) AS OnBackorder
FROM dbo.VI_INVENTORY_SYNC;

-- Test 3: Check for products with no WooCommerce mapping
PRINT '';
PRINT 'Test 3: Products in CP but not mapped to WooCommerce';
SELECT TOP 10
    i.ITEM_NO AS SKU,
    i.DESCR,
    i.IS_ECOMM_ITEM,
    i.STAT AS CP_STATUS
FROM dbo.IM_ITEM i
WHERE i.IS_ECOMM_ITEM = 'Y'
  AND i.STAT IN ('A', 'V')
  AND NOT EXISTS (
      SELECT 1 
      FROM dbo.USER_PRODUCT_MAP m 
      WHERE m.SKU = i.ITEM_NO AND m.IS_ACTIVE = 1
  )
ORDER BY i.ITEM_NO;

-- Test 4: Sample inventory data by status
PRINT '';
PRINT 'Test 4: Sample products by stock status';
SELECT TOP 5 
    SKU,
    WOO_PRODUCT_ID,
    STOCK_QTY,
    CASE 
        WHEN STOCK_QTY > 0 THEN 'In Stock'
        WHEN STOCK_QTY = 0 THEN 'Out of Stock'
        ELSE 'On Backorder'
    END AS StockStatus
FROM dbo.VI_INVENTORY_SYNC
WHERE STOCK_QTY > 0
ORDER BY STOCK_QTY DESC;

PRINT '';
PRINT '============================================';
PRINT 'INVENTORY SYNC VIEW TEST COMPLETE';
PRINT '============================================';
GO

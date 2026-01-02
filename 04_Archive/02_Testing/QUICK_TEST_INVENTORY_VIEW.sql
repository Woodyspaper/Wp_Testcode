-- ============================================
-- QUICK TEST: INVENTORY SYNC VIEW
-- ============================================
-- Simple test to verify VI_INVENTORY_SYNC view works
-- ============================================

USE WOODYS_CP;
GO

-- Quick test: Get sample inventory data
SELECT TOP 20
    SKU,
    WOO_PRODUCT_ID,
    STOCK_QTY,
    STOCK_AVAIL,
    CP_STATUS,
    CASE 
        WHEN STOCK_QTY > 0 THEN 'In Stock'
        WHEN STOCK_QTY = 0 THEN 'Out of Stock'
        ELSE 'On Backorder'
    END AS StockStatus
FROM dbo.VI_INVENTORY_SYNC
ORDER BY SKU;

-- Summary counts
SELECT 
    COUNT(*) AS TotalProducts,
    SUM(CASE WHEN STOCK_QTY > 0 THEN 1 ELSE 0 END) AS InStock,
    SUM(CASE WHEN STOCK_QTY = 0 THEN 1 ELSE 0 END) AS OutOfStock,
    SUM(CASE WHEN STOCK_QTY < 0 THEN 1 ELSE 0 END) AS OnBackorder
FROM dbo.VI_INVENTORY_SYNC;

GO

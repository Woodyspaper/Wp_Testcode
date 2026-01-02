-- ============================================
-- CREATE INVENTORY SYNC VIEW (Phase 3)
-- ============================================
-- Purpose: Fast inventory-only view for Phase 3 sync
--          Optimized for frequent updates (every 5 minutes)
--          Only includes products that exist in WooCommerce
-- ============================================

USE WOODYS_CP;
GO

IF OBJECT_ID('dbo.VI_INVENTORY_SYNC', 'V') IS NOT NULL
    DROP VIEW dbo.VI_INVENTORY_SYNC;
GO

CREATE VIEW dbo.VI_INVENTORY_SYNC AS
SELECT 
    -- Product identification
    i.ITEM_NO AS SKU,
    m.WOO_PRODUCT_ID,
    
    -- Inventory quantities (summed across all locations)
    ISNULL(SUM(inv.QTY_ON_HND), 0) AS STOCK_QTY,
    ISNULL(SUM(inv.QTY_AVAIL), 0) AS STOCK_AVAIL,
    
    -- Status flags
    i.STAT AS CP_STATUS,  -- A=Active, V=Void, D=Discontinued
    i.IS_ECOMM_ITEM,
    
    -- Last modified (for incremental sync)
    i.LST_MAINT_DT AS ITEM_LAST_MODIFIED,
    MAX(inv.LST_MAINT_DT) AS INVENTORY_LAST_MODIFIED
    
FROM dbo.IM_ITEM i
INNER JOIN dbo.USER_PRODUCT_MAP m ON m.SKU = i.ITEM_NO AND m.IS_ACTIVE = 1
LEFT JOIN dbo.IM_INV inv ON inv.ITEM_NO = i.ITEM_NO
WHERE i.IS_ECOMM_ITEM = 'Y'  -- Only e-commerce items
  AND i.STAT IN ('A', 'V')    -- Active or Void (not Discontinued)
  AND m.WOO_PRODUCT_ID IS NOT NULL  -- Only products that exist in WooCommerce
GROUP BY 
    i.ITEM_NO,
    m.WOO_PRODUCT_ID,
    i.STAT,
    i.IS_ECOMM_ITEM,
    i.LST_MAINT_DT;
GO

PRINT '';
PRINT '============================================';
PRINT 'INVENTORY SYNC VIEW CREATED';
PRINT '============================================';
PRINT 'View Name: VI_INVENTORY_SYNC';
PRINT 'Purpose: Fast inventory-only sync for Phase 3';
PRINT '';
PRINT 'Columns:';
PRINT '  - SKU: Product SKU';
PRINT '  - WOO_PRODUCT_ID: WooCommerce product ID';
PRINT '  - STOCK_QTY: Total quantity on hand (summed)';
PRINT '  - STOCK_AVAIL: Available quantity (summed)';
PRINT '  - CP_STATUS: CounterPoint status (A/V/D)';
PRINT '  - IS_ECOMM_ITEM: E-commerce flag';
PRINT '  - ITEM_LAST_MODIFIED: Last item modification';
PRINT '  - INVENTORY_LAST_MODIFIED: Last inventory change';
PRINT '';
PRINT 'Usage:';
PRINT '  SELECT * FROM dbo.VI_INVENTORY_SYNC ORDER BY SKU;';
PRINT '============================================';
GO

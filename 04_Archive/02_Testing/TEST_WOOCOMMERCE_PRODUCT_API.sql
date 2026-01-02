-- ============================================
-- TEST WOOCOMMERCE PRODUCT API ACCESS
-- ============================================
-- Purpose: Verify product exists in WooCommerce before inventory sync
-- ============================================

USE WOODYS_CP;
GO

-- Check product mapping for test product
SELECT 
    m.SKU,
    m.WOO_PRODUCT_ID,
    m.IS_ACTIVE,
    m.CREATED_DT,
    m.UPDATED_DT
FROM dbo.USER_PRODUCT_MAP m
WHERE m.SKU = '01-10100'
  AND m.IS_ACTIVE = 1;

-- Check inventory data for test product
SELECT 
    SKU,
    WOO_PRODUCT_ID,
    STOCK_QTY,
    STOCK_AVAIL,
    CP_STATUS
FROM dbo.VI_INVENTORY_SYNC
WHERE SKU = '01-10100';

GO

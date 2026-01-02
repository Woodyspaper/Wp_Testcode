-- ============================================
-- GET TOP CATEGORIES FOR MAPPING
-- ============================================
-- Purpose: Identify top CounterPoint categories that need mapping
--          Shows categories with most e-commerce products
-- ============================================

USE WOODYS_CP;
GO

-- Get top categories by product count (e-commerce items only)
SELECT 
    i.CATEG_COD AS CP_CATEGORY_CODE,
    COUNT(*) AS PRODUCT_COUNT,
    COUNT(CASE WHEN i.STAT = 'A' THEN 1 END) AS ACTIVE_COUNT,
    COUNT(CASE WHEN i.STAT = 'V' THEN 1 END) AS VOID_COUNT,
    MIN(i.DESCR) AS SAMPLE_PRODUCT_NAME
FROM dbo.IM_ITEM i
WHERE i.IS_ECOMM_ITEM = 'Y'
GROUP BY i.CATEG_COD
HAVING COUNT(*) > 0
ORDER BY PRODUCT_COUNT DESC;

-- Alternative: Get categories from export view
SELECT 
    CATEGORY_CODE AS CP_CATEGORY_CODE,
    COUNT(*) AS PRODUCT_COUNT,
    COUNT(CASE WHEN ACTIVE = 1 THEN 1 END) AS ACTIVE_COUNT,
    COUNT(CASE WHEN ACTIVE = 0 THEN 1 END) AS INACTIVE_COUNT
FROM dbo.VI_EXPORT_PRODUCTS
WHERE CATEGORY_CODE IS NOT NULL
GROUP BY CATEGORY_CODE
ORDER BY PRODUCT_COUNT DESC;

-- Check current category mappings
SELECT 
    CP_CATEGORY_CODE,
    WOO_CATEGORY_ID,
    WOO_CATEGORY_SLUG,
    IS_ACTIVE,
    CREATED_DATE
FROM dbo.USER_CATEGORY_MAP
ORDER BY CP_CATEGORY_CODE;

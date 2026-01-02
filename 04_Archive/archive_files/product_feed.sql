-- ============================================
-- Official Website Feed SQL Query
-- CounterPoint → WooCommerce Integration
-- ============================================
-- 
-- This is the primary query used by the integration pipeline
-- to extract e-commerce products from CounterPoint.
--
-- Source Tables:
--   - VI_IM_ITEM_WITH_INV: Consolidated product + inventory view
--   - EC_ITEM_DESCR: Full HTML product descriptions
--   - EC_CATEG_ITEM: Product-to-category mapping
--   - EC_CATEG: Category master with hierarchy
--
-- Parameters:
--   @loc_id: Location ID filter (typically '01')
--
-- Usage:
--   Replace ? with your location ID (e.g., '01')
--   Or use as parameterized query in Python: run_query(sql, ('01',))
-- ============================================

SELECT
    v.ITEM_NO,
    v.DESCR,
    v.LONG_DESCR,
    v.PRC_1,
    v.REG_PRC,
    v.QTY_AVAIL,
    v.LOC_ID,
    v.IS_ECOMM_ITEM,
    v.ECOMM_IMG_FILE,
    v.URL,
    descr.HTML_DESCR,
    cat.CATEG_ID,
    cat.DESCR AS CATEG_DESCR,
    cat.PARENT_ID,
    cat.DISP_SEQ_NO
FROM VI_IM_ITEM_WITH_INV v
LEFT JOIN EC_ITEM_DESCR descr ON descr.ITEM_NO = v.ITEM_NO
LEFT JOIN EC_CATEG_ITEM ci ON ci.ITEM_NO = v.ITEM_NO
LEFT JOIN EC_CATEG cat ON cat.CATEG_ID = ci.CATEG_ID
WHERE v.LOC_ID = ?  -- Replace ? with location ID (e.g., '01')
  AND v.IS_ECOMM_ITEM = 'Y'
ORDER BY v.ITEM_NO, cat.DISP_SEQ_NO;

-- ============================================
-- Field Mapping Notes:
-- ============================================
-- ITEM_NO          → WooCommerce SKU
-- DESCR            → Product Name
-- LONG_DESCR       → Short Description
-- HTML_DESCR       → Full Description (preferred)
-- PRC_1            → Regular Price (fallback to REG_PRC if null)
-- REG_PRC          → Regular Price (fallback)
-- QTY_AVAIL        → Stock Quantity (capped at 0 minimum)
-- ECOMM_IMG_FILE   → Product Image URL (combined with IMAGE_BASE_URL)
-- URL              → Product Slug source
-- CATEG_DESCR      → WooCommerce Category Slug
-- CATEG_ID         → Category ID for hierarchy
-- PARENT_ID        → Parent category for tree structure
-- ============================================

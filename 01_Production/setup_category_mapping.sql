-- ============================================
-- SETUP CATEGORY MAPPING FOR PHASE 2
-- ============================================
-- Purpose: Helper script to set up category mappings
--          Run GET_TOP_CATEGORIES.sql first to see what needs mapping
-- ============================================

USE WOODYS_CP;
GO

-- Verify USER_CATEGORY_MAP table exists
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'USER_CATEGORY_MAP')
BEGIN
    PRINT 'ERROR: USER_CATEGORY_MAP table does not exist!';
    PRINT 'Run: 01_Production/staging_tables.sql to create it.';
    RETURN;
END

PRINT '============================================';
PRINT 'CATEGORY MAPPING SETUP';
PRINT '============================================';
PRINT '';

-- Show current mappings
PRINT 'Current Category Mappings:';
SELECT 
    CP_CATEGORY_CODE,
    WOO_CATEGORY_ID,
    WOO_CATEGORY_SLUG,
    CASE WHEN IS_ACTIVE = 1 THEN 'Active' ELSE 'Inactive' END AS STATUS
FROM dbo.USER_CATEGORY_MAP
ORDER BY CP_CATEGORY_CODE;

PRINT '';
PRINT 'Top Categories Needing Mapping:';
SELECT TOP 10
    CATEGORY_CODE AS CP_CATEGORY_CODE,
    COUNT(*) AS PRODUCT_COUNT
FROM dbo.VI_EXPORT_PRODUCTS
WHERE CATEGORY_CODE IS NOT NULL
  AND CATEGORY_CODE NOT IN (SELECT CP_CATEGORY_CODE FROM dbo.USER_CATEGORY_MAP WHERE IS_ACTIVE = 1)
GROUP BY CATEGORY_CODE
ORDER BY PRODUCT_COUNT DESC;

PRINT '';
PRINT '============================================';
PRINT 'TO ADD A MAPPING:';
PRINT '============================================';
PRINT '';
PRINT '1. Get WooCommerce category ID from WordPress admin';
PRINT '2. Run this SQL (replace values):';
PRINT '';
PRINT 'INSERT INTO dbo.USER_CATEGORY_MAP';
PRINT '    (CP_CATEGORY_CODE, WOO_CATEGORY_ID, WOO_CATEGORY_SLUG, IS_ACTIVE)';
PRINT 'VALUES';
PRINT '    (''PRINT AND'', 123, ''print-and-paper'', 1);';
PRINT '';
PRINT 'Or use the helper script: setup_category_mapping_helper.ps1';
PRINT '';

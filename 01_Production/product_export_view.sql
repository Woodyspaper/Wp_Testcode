USE WOODYS_CP;
GO

/*
View: VI_EXPORT_PRODUCTS
Purpose: Comprehensive CP product data export for WooCommerce sync.
Captures all available product information from CounterPoint Items UI.

Expected columns:
- Core: SKU, NAME, SHORT_DESC, LONG_DESC, ACTIVE, STOCK_QTY, CATEGORY_CODE
- Pricing: PRICE, MSRP, COST
- Physical: WEIGHT, DIMENSIONS (if available)
- E-Commerce: IMAGE_FILE, URL, ECOMM_NEW, ECOMM_ON_SPECIAL
- Status: CP_STATUS (A/V/D), TAXABLE, TAX_CODE
- Additional: BARCODE, VENDOR_NO, SUB_CATEGORY
*/

IF OBJECT_ID('dbo.VI_EXPORT_PRODUCTS', 'V') IS NOT NULL
    DROP VIEW dbo.VI_EXPORT_PRODUCTS;
GO

CREATE VIEW dbo.VI_EXPORT_PRODUCTS AS
SELECT
    -- ============================================
    -- CORE IDENTIFICATION
    -- ============================================
    i.ITEM_NO                       AS SKU,
    ISNULL(CAST(i.DESCR AS NVARCHAR(MAX)), CAST(i.SHORT_DESCR AS NVARCHAR(MAX))) AS NAME,
    ISNULL(CAST(i.SHORT_DESCR AS NVARCHAR(MAX)), CAST(i.DESCR AS NVARCHAR(MAX))) AS SHORT_DESC,
    -- Prefer HTML description from EC_ITEM_DESCR, fallback to LONG_DESCR
    ISNULL(CAST(ed.HTML_DESCR AS NVARCHAR(MAX)), CAST(i.LONG_DESCR AS NVARCHAR(MAX))) AS LONG_DESC,
    
    -- ============================================
    -- STATUS & E-COMMERCE FLAGS
    -- ============================================
    -- Active if e-commerce item (IS_ECOMM_ITEM = 'Y')
    CASE 
        WHEN i.IS_ECOMM_ITEM = 'Y' THEN 1
        ELSE 0
    END AS ACTIVE,
    i.STAT                          AS CP_STATUS,  -- A=Active, V=Void, D=Discontinued
    i.IS_ECOMM_ITEM                 AS IS_ECOMM_ITEM,  -- Y/N flag
    
    -- ============================================
    -- PRICING
    -- ============================================
    i.PRC_1                          AS PRICE,  -- WPC PRICE (primary price)
    i.REG_PRC                         AS MSRP,  -- Manufacturer's suggested retail price
    i.LST_COST                        AS COST,  -- Last cost (internal)
    i.DISC_ALLOW                      AS DISCOUNTABLE,  -- Y/N - whether discounts apply
    
    -- ============================================
    -- INVENTORY
    -- ============================================
    -- Sum stock across all locations
    ISNULL(SUM(inv.QTY_ON_HND), 0) AS STOCK_QTY,
    -- Available quantity (after reservations) - if available
    ISNULL(SUM(inv.QTY_AVAIL), 0) AS STOCK_AVAIL,
    
    -- ============================================
    -- CATEGORY & CLASSIFICATION
    -- ============================================
    i.CATEG_COD                     AS CATEGORY_CODE,
    i.SUB_CATEG_COD                 AS SUB_CATEGORY_CODE,
    i.ACCT_COD                      AS ACCOUNT_CODE,  -- GL account code
    
    -- ============================================
    -- PHYSICAL ATTRIBUTES
    -- ============================================
    i.WT                             AS WEIGHT,  -- Product weight
    i.CUBE                           AS CUBE,  -- Product volume/cube
    -- Note: Package dimensions (PKG_LENGTH, PKG_WIDTH, PKG_HEIGHT) may be in custom fields
    -- These would need to be added if available in your CP schema
    
    -- ============================================
    -- E-COMMERCE SPECIFIC
    -- ============================================
    i.ECOMM_IMG_FILE                 AS IMAGE_FILE,  -- Image filename (e.g., "01-10100.jpg")
    i.URL                             AS URL,  -- Product URL/slug
    i.ECOMM_NEW                       AS ECOMM_NEW,  -- New product flag
    i.ECOMM_ON_SPECIAL                AS ECOMM_ON_SPECIAL,  -- On sale flag
    i.ECOMM_SPECIAL_UNTIL             AS ECOMM_SPECIAL_UNTIL,  -- Sale end date
    i.ECOMM_PUB_DT                    AS ECOMM_LAST_PUBLISHED,  -- Last publish date
    i.ECOMM_PUB_STAT                  AS ECOMM_PUB_STATUS,  -- Publish status
    
    -- ============================================
    -- TAX & COMPLIANCE
    -- ============================================
    i.TAXABLE                         AS TAXABLE,  -- Y/N - whether product is taxable
    i.TAX_COD                         AS TAX_CODE,  -- Tax code reference
    
    -- ============================================
    -- VENDOR & BARCODE
    -- ============================================
    i.VEND_NO                         AS VENDOR_NO,  -- Primary vendor number
    i.VEND_ITEM_NO                    AS VENDOR_ITEM_NO,  -- Vendor's item number
    i.BARCOD                          AS BARCODE,  -- Primary barcode
    
    -- ============================================
    -- UNITS
    -- ============================================
    i.STK_UNIT                        AS STOCKING_UNIT,  -- Base stocking unit (PK, CT, etc.)
    i.PREF_UNIT                       AS PREFERRED_UNIT,  -- Preferred display unit
    
    -- ============================================
    -- METADATA
    -- ============================================
    -- Last maintenance date for incremental sync
    ISNULL(ed.LST_MAINT_DT, i.LST_MAINT_DT) AS LST_MAINT_DT,
    i.LST_MAINT_DT                    AS ITEM_LAST_MAINT_DT,  -- Item last modified
    ed.LST_MAINT_DT                   AS DESC_LAST_MAINT_DT  -- Description last modified
    
FROM dbo.IM_ITEM i
LEFT JOIN dbo.EC_ITEM_DESCR ed ON ed.ITEM_NO = i.ITEM_NO
LEFT JOIN dbo.IM_INV inv ON inv.ITEM_NO = i.ITEM_NO
WHERE i.ITEM_NO IS NOT NULL
GROUP BY 
    i.ITEM_NO,
    CAST(i.DESCR AS NVARCHAR(MAX)),
    CAST(i.SHORT_DESCR AS NVARCHAR(MAX)),
    CAST(i.LONG_DESCR AS NVARCHAR(MAX)),
    CAST(ed.HTML_DESCR AS NVARCHAR(MAX)),
    i.IS_ECOMM_ITEM,
    i.STAT,
    i.PRC_1,
    i.REG_PRC,
    i.LST_COST,
    i.DISC_ALLOW,
    i.CATEG_COD,
    i.SUB_CATEG_COD,
    i.ACCT_COD,
    i.WT,
    i.CUBE,
    i.ECOMM_IMG_FILE,
    i.URL,
    i.ECOMM_NEW,
    i.ECOMM_ON_SPECIAL,
    i.ECOMM_SPECIAL_UNTIL,
    i.ECOMM_PUB_DT,
    i.ECOMM_PUB_STAT,
    i.TAXABLE,
    i.TAX_COD,
    i.VEND_NO,
    i.VEND_ITEM_NO,
    i.BARCOD,
    i.STK_UNIT,
    i.PREF_UNIT,
    ISNULL(ed.LST_MAINT_DT, i.LST_MAINT_DT),
    i.LST_MAINT_DT,
    ed.LST_MAINT_DT;
GO


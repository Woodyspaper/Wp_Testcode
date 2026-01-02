-- ============================================
-- Deploy Product Mapping Tables
-- Database: WOODYS_CP
-- Purpose: Create USER_PRODUCT_MAP and USER_CATEGORY_MAP for Phase 2
-- ============================================

USE WOODYS_CP;
GO

PRINT '============================================';
PRINT 'Deploying Product Mapping Tables';
PRINT '============================================';
PRINT '';

-- ============================================
-- 1. USER_PRODUCT_MAP
-- ============================================
-- Maps CP SKU (ITEM_NO) to WooCommerce product_id

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'USER_PRODUCT_MAP')
BEGIN
    CREATE TABLE dbo.USER_PRODUCT_MAP (
        MAP_ID           INT IDENTITY(1,1) PRIMARY KEY,
        SKU              VARCHAR(50)   NOT NULL,  -- CP SKU (canonical)
        WOO_PRODUCT_ID   BIGINT        NOT NULL,  -- Woo product ID
        IS_ACTIVE        BIT           DEFAULT 1,
        CREATED_DT       DATETIME2     DEFAULT GETDATE(),
        CREATED_BY       VARCHAR(50)   DEFAULT SYSTEM_USER,
        UPDATED_DT       DATETIME2,
        UPDATED_BY       VARCHAR(50),
        NOTES            NVARCHAR(255)
    );

    CREATE UNIQUE INDEX IX_USER_PRODUCT_MAP_SKU_ACTIVE
        ON dbo.USER_PRODUCT_MAP(SKU)
        WHERE IS_ACTIVE = 1;

    CREATE UNIQUE INDEX IX_USER_PRODUCT_MAP_WOO_ACTIVE
        ON dbo.USER_PRODUCT_MAP(WOO_PRODUCT_ID)
        WHERE IS_ACTIVE = 1;

    PRINT '✅ Created USER_PRODUCT_MAP';
END
ELSE
BEGIN
    PRINT 'ℹ️  USER_PRODUCT_MAP already exists';
END
GO

-- ============================================
-- 2. USER_CATEGORY_MAP
-- ============================================
-- Maps CP category codes to WooCommerce category IDs

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'USER_CATEGORY_MAP')
BEGIN
    CREATE TABLE dbo.USER_CATEGORY_MAP (
        MAP_ID            INT IDENTITY(1,1) PRIMARY KEY,
        CP_CATEGORY_CODE  VARCHAR(50)  NOT NULL,
        WOO_CATEGORY_ID   BIGINT       NOT NULL,
        WOO_CATEGORY_SLUG VARCHAR(100) NULL,
        IS_ACTIVE         BIT          DEFAULT 1,
        CREATED_DT        DATETIME2    DEFAULT GETDATE(),
        CREATED_BY        VARCHAR(50)  DEFAULT SYSTEM_USER,
        UPDATED_DT        DATETIME2,
        UPDATED_BY        VARCHAR(50),
        NOTES             NVARCHAR(255)
    );

    CREATE UNIQUE INDEX IX_USER_CATEGORY_MAP_CP_ACTIVE
        ON dbo.USER_CATEGORY_MAP(CP_CATEGORY_CODE)
        WHERE IS_ACTIVE = 1;

    CREATE UNIQUE INDEX IX_USER_CATEGORY_MAP_WOO_ACTIVE
        ON dbo.USER_CATEGORY_MAP(WOO_CATEGORY_ID)
        WHERE IS_ACTIVE = 1;

    PRINT '✅ Created USER_CATEGORY_MAP';
END
ELSE
BEGIN
    PRINT 'ℹ️  USER_CATEGORY_MAP already exists';
END
GO

-- ============================================
-- Verification
-- ============================================

PRINT '';
PRINT '============================================';
PRINT 'Verification';
PRINT '============================================';

SELECT 
    name AS TableName,
    create_date AS CreatedDate
FROM sys.tables
WHERE name IN ('USER_PRODUCT_MAP', 'USER_CATEGORY_MAP')
ORDER BY name;

PRINT '';
PRINT '✅ Product mapping tables deployment complete!';
PRINT '';




USE WOODYS_CP;
GO

/*
Product and category mapping tables for CP → Woo sync.
Run this once in WOODYS_CP before enabling product/price export.
*/

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

    PRINT 'Created USER_PRODUCT_MAP';
END
ELSE
    PRINT 'USER_PRODUCT_MAP already exists';
GO

-- Optional: category mapping if you need explicit CP category → Woo category mapping.
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

    PRINT 'Created USER_CATEGORY_MAP';
END
ELSE
    PRINT 'USER_CATEGORY_MAP already exists';
GO



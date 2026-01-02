-- ============================================
-- Verify Product Sync Results
-- ============================================

USE WOODYS_CP;
GO

-- 1. Check latest sync log entry
SELECT TOP 1
    SYNC_ID,
    OPERATION_TYPE,
    DIRECTION,
    DRY_RUN,
    START_TIME,
    END_TIME,
    DURATION_SECONDS,
    RECORDS_INPUT,
    RECORDS_CREATED,
    RECORDS_UPDATED,
    RECORDS_FAILED,
    SUCCESS,
    ERROR_MESSAGE
FROM dbo.USER_SYNC_LOG
WHERE OPERATION_TYPE = 'product_sync'
ORDER BY START_TIME DESC;
GO

-- 2. Check product mappings
SELECT TOP 10
    SKU,
    WOO_PRODUCT_ID,
    IS_ACTIVE,
    CREATED_DT,
    UPDATED_DT
FROM dbo.USER_PRODUCT_MAP
ORDER BY CREATED_DT DESC;
GO

-- 3. Check specific SKU mapping
SELECT 
    SKU,
    WOO_PRODUCT_ID,
    IS_ACTIVE,
    CREATED_DT,
    UPDATED_DT,
    NOTES
FROM dbo.USER_PRODUCT_MAP
WHERE SKU = '01-10100';
GO


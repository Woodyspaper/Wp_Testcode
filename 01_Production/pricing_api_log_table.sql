-- ============================================
-- Pricing API Logging Table
-- ============================================
-- Purpose: Track contract pricing API requests for observability
-- Similar to USER_SYNC_LOG but for live pricing requests

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'USER_PRICING_API_LOG')
BEGIN
    CREATE TABLE dbo.USER_PRICING_API_LOG (
        LOG_ID              BIGINT IDENTITY(1,1) PRIMARY KEY,
        
        -- Request details
        REQUEST_DT          DATETIME2 DEFAULT GETDATE(),
        CLIENT_IP           VARCHAR(45) NULL,
        NCR_BID_NO          VARCHAR(15) NULL,
        ITEM_NO             VARCHAR(30) NULL,
        QUANTITY            DECIMAL(15,4) NULL,
        LOC_ID              VARCHAR(10) NULL,
        
        -- Response details
        RESPONSE_STATUS     INT NULL,                    -- HTTP status code (200, 404, 500, etc.)
        CONTRACT_PRICE      DECIMAL(15,4) NULL,
        REGULAR_PRICE       DECIMAL(15,4) NULL,
        DISCOUNT_PCT        DECIMAL(5,2) NULL,
        PRICING_METHOD      CHAR(1) NULL,                -- D, O, M, A
        RULE_DESCR          VARCHAR(50) NULL,
        
        -- Performance metrics
        RESPONSE_TIME_MS    INT NULL,                    -- Response time in milliseconds
        CACHE_HIT           BIT DEFAULT 0,               -- Was this a cache hit?
        DB_QUERY_TIME_MS    INT NULL,                    -- Database query time
        
        -- Error handling
        ERROR_MSG           NVARCHAR(MAX) NULL,
        ERROR_STACK         NVARCHAR(MAX) NULL,
        
        -- Batch request tracking
        IS_BATCH            BIT DEFAULT 0,
        BATCH_SIZE          INT NULL,
        BATCH_SUCCESS_COUNT INT NULL,
        BATCH_ERROR_COUNT   INT NULL,
        
        -- Indexes for common queries
        INDEX IX_PRICING_LOG_DT (REQUEST_DT),
        INDEX IX_PRICING_LOG_NCR_BID (NCR_BID_NO),
        INDEX IX_PRICING_LOG_ITEM (ITEM_NO),
        INDEX IX_PRICING_LOG_STATUS (RESPONSE_STATUS)
    );
    
    PRINT 'Created USER_PRICING_API_LOG table';
END
ELSE
    PRINT 'USER_PRICING_API_LOG already exists';
GO

-- ============================================
-- Stored Procedure: Log Pricing Request
-- ============================================

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'usp_LogPricingRequest')
    DROP PROCEDURE dbo.usp_LogPricingRequest;
GO

CREATE PROCEDURE dbo.usp_LogPricingRequest
    @CLIENT_IP           VARCHAR(45) = NULL,
    @NCR_BID_NO          VARCHAR(15) = NULL,
    @ITEM_NO             VARCHAR(30) = NULL,
    @QUANTITY            DECIMAL(15,4) = NULL,
    @LOC_ID              VARCHAR(10) = NULL,
    @RESPONSE_STATUS     INT = NULL,
    @CONTRACT_PRICE      DECIMAL(15,4) = NULL,
    @REGULAR_PRICE       DECIMAL(15,4) = NULL,
    @DISCOUNT_PCT        DECIMAL(5,2) = NULL,
    @PRICING_METHOD      CHAR(1) = NULL,
    @RULE_DESCR          VARCHAR(50) = NULL,
    @RESPONSE_TIME_MS    INT = NULL,
    @CACHE_HIT           BIT = 0,
    @DB_QUERY_TIME_MS    INT = NULL,
    @ERROR_MSG           NVARCHAR(MAX) = NULL,
    @ERROR_STACK         NVARCHAR(MAX) = NULL,
    @IS_BATCH            BIT = 0,
    @BATCH_SIZE          INT = NULL,
    @BATCH_SUCCESS_COUNT INT = NULL,
    @BATCH_ERROR_COUNT   INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO dbo.USER_PRICING_API_LOG (
        CLIENT_IP, NCR_BID_NO, ITEM_NO, QUANTITY, LOC_ID,
        RESPONSE_STATUS, CONTRACT_PRICE, REGULAR_PRICE, DISCOUNT_PCT,
        PRICING_METHOD, RULE_DESCR,
        RESPONSE_TIME_MS, CACHE_HIT, DB_QUERY_TIME_MS,
        ERROR_MSG, ERROR_STACK,
        IS_BATCH, BATCH_SIZE, BATCH_SUCCESS_COUNT, BATCH_ERROR_COUNT
    )
    VALUES (
        @CLIENT_IP, @NCR_BID_NO, @ITEM_NO, @QUANTITY, @LOC_ID,
        @RESPONSE_STATUS, @CONTRACT_PRICE, @REGULAR_PRICE, @DISCOUNT_PCT,
        @PRICING_METHOD, @RULE_DESCR,
        @RESPONSE_TIME_MS, @CACHE_HIT, @DB_QUERY_TIME_MS,
        @ERROR_MSG, @ERROR_STACK,
        @IS_BATCH, @BATCH_SIZE, @BATCH_SUCCESS_COUNT, @BATCH_ERROR_COUNT
    );
END;
GO

PRINT 'Created usp_LogPricingRequest stored procedure';
GO

-- ============================================
-- View: Pricing API Metrics
-- ============================================

IF EXISTS (SELECT * FROM sys.views WHERE name = 'VI_PRICING_API_METRICS')
    DROP VIEW dbo.VI_PRICING_API_METRICS;
GO

CREATE VIEW dbo.VI_PRICING_API_METRICS
AS
SELECT 
    CAST(REQUEST_DT AS DATE) AS METRIC_DATE,
    COUNT(*) AS TOTAL_REQUESTS,
    SUM(CASE WHEN RESPONSE_STATUS = 200 THEN 1 ELSE 0 END) AS SUCCESS_COUNT,
    SUM(CASE WHEN RESPONSE_STATUS != 200 THEN 1 ELSE 0 END) AS ERROR_COUNT,
    SUM(CASE WHEN CACHE_HIT = 1 THEN 1 ELSE 0 END) AS CACHE_HITS,
    SUM(CASE WHEN CACHE_HIT = 0 THEN 1 ELSE 0 END) AS CACHE_MISSES,
    AVG(RESPONSE_TIME_MS) AS AVG_RESPONSE_TIME_MS,
    MAX(RESPONSE_TIME_MS) AS MAX_RESPONSE_TIME_MS,
    AVG(DB_QUERY_TIME_MS) AS AVG_DB_QUERY_TIME_MS,
    COUNT(DISTINCT NCR_BID_NO) AS UNIQUE_CUSTOMERS,
    COUNT(DISTINCT ITEM_NO) AS UNIQUE_PRODUCTS
FROM dbo.USER_PRICING_API_LOG
WHERE REQUEST_DT >= DATEADD(DAY, -30, GETDATE())  -- Last 30 days
GROUP BY CAST(REQUEST_DT AS DATE)
GO

PRINT 'Created VI_PRICING_API_METRICS view';
GO


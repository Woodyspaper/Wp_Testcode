-- ============================================
-- Deployment Verification Script
-- ============================================
-- Run this in SSMS after executing deployment SQL scripts
-- Purpose: Verify all database objects were created successfully
-- ============================================

USE WOODYS_CP;
GO

PRINT '========================================';
PRINT 'Deployment Verification';
PRINT '========================================';
PRINT '';

-- 1. Verify Database
PRINT '1. Checking current database...';
SELECT DB_NAME() AS CurrentDatabase;
IF DB_NAME() != 'WOODYS_CP'
BEGIN
    PRINT 'WARNING: Not on WOODYS_CP database!';
    PRINT 'Please switch to WOODYS_CP before running deployment scripts.';
END
ELSE
BEGIN
    PRINT 'OK: Connected to WOODYS_CP database.';
END
PRINT '';

-- 2. Verify Views
PRINT '2. Checking views...';
SELECT 
    'View' AS ObjectType,
    name AS ObjectName,
    CASE 
        WHEN name IN ('VI_PRODUCT_NCR_TYPE', 'VI_PRICING_API_METRICS') THEN 'OK'
        ELSE 'UNEXPECTED'
    END AS Status
FROM sys.views
WHERE name IN ('VI_PRODUCT_NCR_TYPE', 'VI_PRICING_API_METRICS')
ORDER BY name;

IF NOT EXISTS (SELECT * FROM sys.views WHERE name = 'VI_PRODUCT_NCR_TYPE')
BEGIN
    PRINT 'ERROR: VI_PRODUCT_NCR_TYPE view not found!';
    PRINT 'Run: 01_Production/contract_price_calculation.sql';
END

IF NOT EXISTS (SELECT * FROM sys.views WHERE name = 'VI_PRICING_API_METRICS')
BEGIN
    PRINT 'ERROR: VI_PRICING_API_METRICS view not found!';
    PRINT 'Run: 01_Production/pricing_api_log_table.sql';
END
PRINT '';

-- 3. Verify Function
PRINT '3. Checking function...';
SELECT 
    'Function' AS ObjectType,
    name AS ObjectName,
    CASE 
        WHEN name = 'fn_GetContractPrice' THEN 'OK'
        ELSE 'UNEXPECTED'
    END AS Status
FROM sys.objects
WHERE type = 'TF' AND name = 'fn_GetContractPrice';

IF NOT EXISTS (SELECT * FROM sys.objects WHERE type = 'TF' AND name = 'fn_GetContractPrice')
BEGIN
    PRINT 'ERROR: fn_GetContractPrice function not found!';
    PRINT 'Run: 01_Production/contract_price_calculation.sql';
END
PRINT '';

-- 4. Verify Table
PRINT '4. Checking table...';
SELECT 
    'Table' AS ObjectType,
    name AS ObjectName,
    CASE 
        WHEN name = 'USER_PRICING_API_LOG' THEN 'OK'
        ELSE 'UNEXPECTED'
    END AS Status
FROM sys.tables
WHERE name = 'USER_PRICING_API_LOG';

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'USER_PRICING_API_LOG')
BEGIN
    PRINT 'ERROR: USER_PRICING_API_LOG table not found!';
    PRINT 'Run: 01_Production/pricing_api_log_table.sql';
END
PRINT '';

-- 5. Verify Stored Procedure
PRINT '5. Checking stored procedure...';
SELECT 
    'Procedure' AS ObjectType,
    name AS ObjectName,
    CASE 
        WHEN name = 'usp_LogPricingRequest' THEN 'OK'
        ELSE 'UNEXPECTED'
    END AS Status
FROM sys.procedures
WHERE name = 'usp_LogPricingRequest';

IF NOT EXISTS (SELECT * FROM sys.procedures WHERE name = 'usp_LogPricingRequest')
BEGIN
    PRINT 'ERROR: usp_LogPricingRequest procedure not found!';
    PRINT 'Run: 01_Production/pricing_api_log_table.sql';
END
PRINT '';

-- 6. Test View
PRINT '6. Testing VI_PRODUCT_NCR_TYPE view...';
SELECT TOP 5
    ITEM_NO,
    NCR_TYPE
FROM dbo.VI_PRODUCT_NCR_TYPE
WHERE NCR_TYPE != 'UNKNOWN';
PRINT '';

-- 7. Test Function
PRINT '7. Testing fn_GetContractPrice function...';
-- Use a test NCR BID and item (adjust as needed)
SELECT * 
FROM dbo.fn_GetContractPrice('144319', '01-10100', 10.0, '01');
PRINT '';

-- 8. Test Logging Table
PRINT '8. Testing USER_PRICING_API_LOG table...';
SELECT TOP 5
    LOG_ID,
    REQUEST_DT,
    NCR_BID_NO,
    ITEM_NO,
    SUCCESS
FROM dbo.USER_PRICING_API_LOG
ORDER BY REQUEST_DT DESC;
PRINT '';

-- 9. Summary
PRINT '========================================';
PRINT 'Verification Summary';
PRINT '========================================';

DECLARE @ViewCount INT = (SELECT COUNT(*) FROM sys.views WHERE name IN ('VI_PRODUCT_NCR_TYPE', 'VI_PRICING_API_METRICS'));
DECLARE @FunctionCount INT = (SELECT COUNT(*) FROM sys.objects WHERE type = 'TF' AND name = 'fn_GetContractPrice');
DECLARE @TableCount INT = (SELECT COUNT(*) FROM sys.tables WHERE name = 'USER_PRICING_API_LOG');
DECLARE @ProcCount INT = (SELECT COUNT(*) FROM sys.procedures WHERE name = 'usp_LogPricingRequest');

PRINT 'Views: ' + CAST(@ViewCount AS VARCHAR) + '/2';
PRINT 'Functions: ' + CAST(@FunctionCount AS VARCHAR) + '/1';
PRINT 'Tables: ' + CAST(@TableCount AS VARCHAR) + '/1';
PRINT 'Procedures: ' + CAST(@ProcCount AS VARCHAR) + '/1';
PRINT '';

IF @ViewCount = 2 AND @FunctionCount = 1 AND @TableCount = 1 AND @ProcCount = 1
BEGIN
    PRINT 'SUCCESS: All database objects created successfully!';
    PRINT 'Next step: Configure Python API and WordPress plugins.';
END
ELSE
BEGIN
    PRINT 'ERROR: Some objects are missing.';
    PRINT 'Please run the deployment SQL scripts in order:';
    PRINT '  1. 01_Production/contract_price_calculation.sql';
    PRINT '  2. 01_Production/pricing_api_log_table.sql';
END

PRINT '========================================';

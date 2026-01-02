-- ============================================
-- Verify Schema Deployment - Phase 1.5 Step 1
-- Run this AFTER deploying staging_tables.sql
-- ============================================

USE WOODYS_CP;
GO

PRINT '============================================================';
PRINT 'Verifying Schema Deployment';
PRINT '============================================================';
PRINT '';

-- 1. Check tables exist
PRINT '1. Checking tables...';
SELECT 
    CASE 
        WHEN COUNT(*) = 5 THEN '✅ All 5 tables exist'
        ELSE '❌ Missing tables: ' + CAST(5 - COUNT(*) AS VARCHAR) + ' not found'
    END AS Status
FROM sys.tables 
WHERE name IN (
    'USER_CUSTOMER_STAGING',
    'USER_SHIP_TO_STAGING', 
    'USER_CUSTOMER_NOTES_STAGING',
    'USER_CUSTOMER_MAP',
    'USER_SYNC_LOG'
);
GO

-- 2. List all tables
PRINT '';
PRINT '2. Tables found:';
SELECT name AS TableName, 
       create_date AS CreatedDate
FROM sys.tables 
WHERE name IN (
    'USER_CUSTOMER_STAGING',
    'USER_SHIP_TO_STAGING', 
    'USER_CUSTOMER_NOTES_STAGING',
    'USER_CUSTOMER_MAP',
    'USER_SYNC_LOG'
)
ORDER BY name;
GO

-- 3. Check procedures exist
PRINT '';
PRINT '3. Checking stored procedures...';
SELECT 
    CASE 
        WHEN COUNT(*) = 5 THEN '✅ All 5 procedures exist'
        ELSE '❌ Missing procedures: ' + CAST(5 - COUNT(*) AS VARCHAR) + ' not found'
    END AS Status
FROM sys.procedures
WHERE name IN (
    'usp_Preflight_Validate_Customer_Staging',
    'usp_Create_Customers_From_Staging',
    'usp_Create_ShipTo_From_Staging',
    'usp_Create_CustomerNotes_From_Staging',
    'usp_CP_Woo_Crosscheck'
);
GO

-- 4. List all procedures
PRINT '';
PRINT '4. Procedures found:';
SELECT name AS ProcedureName,
       create_date AS CreatedDate
FROM sys.procedures
WHERE name IN (
    'usp_Preflight_Validate_Customer_Staging',
    'usp_Create_Customers_From_Staging',
    'usp_Create_ShipTo_From_Staging',
    'usp_Create_CustomerNotes_From_Staging',
    'usp_CP_Woo_Crosscheck'
)
ORDER BY name;
GO

-- 5. Test procedure execution (should not error)
PRINT '';
PRINT '5. Testing procedure execution...';
BEGIN TRY
    EXEC dbo.usp_Preflight_Validate_Customer_Staging;
    PRINT '✅ Procedures execute successfully';
END TRY
BEGIN CATCH
    PRINT '❌ Error executing procedure:';
    PRINT ERROR_MESSAGE();
END CATCH
GO

PRINT '';
PRINT '============================================================';
PRINT 'Verification Complete';
PRINT '============================================================';
GO


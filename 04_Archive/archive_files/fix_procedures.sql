USE WOODYS_CP;
GO

-- ============================================
-- FIX: Drop and recreate procedures with fixes
-- ============================================

PRINT '============================================';
PRINT 'DROPPING OLD PROCEDURES';
PRINT '============================================';

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'usp_Preflight_Validate_Customer_Staging')
BEGIN
    DROP PROCEDURE dbo.usp_Preflight_Validate_Customer_Staging;
    PRINT 'Dropped usp_Preflight_Validate_Customer_Staging';
END
ELSE
    PRINT 'usp_Preflight_Validate_Customer_Staging does not exist';

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'usp_Create_Customers_From_Staging')
BEGIN
    DROP PROCEDURE dbo.usp_Create_Customers_From_Staging;
    PRINT 'Dropped usp_Create_Customers_From_Staging';
END
ELSE
    PRINT 'usp_Create_Customers_From_Staging does not exist';

GO

PRINT '';
PRINT '============================================';
PRINT 'RECREATING PROCEDURES FROM staging_tables.sql';
PRINT '============================================';
PRINT 'Please run staging_tables.sql now to recreate usp_Create_Customers_From_Staging';
PRINT 'Then run preflight_validation.sql to recreate usp_Preflight_Validate_Customer_Staging';
PRINT '============================================';
GO


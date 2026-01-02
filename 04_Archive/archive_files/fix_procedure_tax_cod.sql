-- ============================================
-- Fix Procedure: Update TAX_COD Default
-- This recreates the procedure with the correct default
-- ============================================

USE WOODYS_CP;  -- Make sure you're using the correct database!
GO

PRINT '============================================';
PRINT 'FIXING PROCEDURE: TAX_COD Default';
PRINT '============================================';
PRINT 'Current database: ' + DB_NAME();
PRINT '';

-- Drop the existing procedure
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'usp_Create_Customers_From_Staging')
BEGIN
    DROP PROCEDURE dbo.usp_Create_Customers_From_Staging;
    PRINT '✅ Dropped old procedure';
END
ELSE
BEGIN
    PRINT '⚠️ Procedure does not exist (will create new one)';
END
GO

PRINT '';
PRINT '============================================';
PRINT 'IMPORTANT:';
PRINT 'You need to run the procedure definition from staging_tables.sql';
PRINT 'Starting at line 1253 (CREATE PROCEDURE...)';
PRINT 'Ending at line 1707 (END; GO)';
PRINT '';
PRINT 'Or simply run the entire staging_tables.sql file';
PRINT '(make sure line 32 says: USE WOODYS_CP; not USE CPPractice;)';
PRINT '============================================';
GO


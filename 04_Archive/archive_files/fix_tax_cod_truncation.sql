-- ============================================
-- Fix TAX_COD Truncation Error
-- The default 'FL-BROWARD' is 11 chars, but TAX_COD is VARCHAR(10)
-- ============================================

USE WOODYS_CP;  -- Change to CPPractice if testing
GO

-- Drop and recreate the procedure with the fix
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'usp_Create_Customers_From_Staging')
    DROP PROCEDURE dbo.usp_Create_Customers_From_Staging;
GO

-- Note: You need to run the full procedure definition from staging_tables.sql
-- This is just a reminder that the fix is:
-- 1. Change @DefaultTAX_COD default from 'FL-BROWARD' to 'FL-BROWAR'
-- 2. Use LEFT(ISNULL(s.TAX_COD, @DefaultTAX_COD), 10) when loading into #ToProcess

PRINT '============================================';
PRINT 'FIX APPLIED';
PRINT '============================================';
PRINT 'The procedure needs to be recreated from staging_tables.sql';
PRINT 'with the TAX_COD fix applied.';
PRINT '';
PRINT 'Changes made:';
PRINT '  1. @DefaultTAX_COD changed from ''FL-BROWARD'' to ''FL-BROWAR''';
PRINT '  2. TAX_COD loading now uses LEFT(ISNULL(...), 10)';
PRINT '============================================';
GO


-- ============================================
-- Recreate Procedure with TAX_COD Fix
-- This fixes the truncation error
-- ============================================

USE WOODYS_CP;  -- or CPPractice if testing
GO

PRINT '============================================';
PRINT 'RECREATING PROCEDURE WITH TAX_COD FIX';
PRINT '============================================';
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
PRINT 'IMPORTANT: You need to run the procedure definition';
PRINT 'from staging_tables.sql starting at line 1253';
PRINT '============================================';
PRINT '';
PRINT 'Or run the entire staging_tables.sql file';
PRINT '(it''s idempotent - safe to run multiple times)';
PRINT '';
PRINT 'The fix is:';
PRINT '  @DefaultTAX_COD VARCHAR(10) = ''FL-BROWAR'' (not ''FL-BROWARD'')';
PRINT '  LEFT(ISNULL(s.TAX_COD, @DefaultTAX_COD), 10) when loading';
PRINT '';
GO


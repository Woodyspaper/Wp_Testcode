USE WOODYS_CP;
GO

-- ============================================
-- PREFLIGHT VALIDATION FOR WOOCOMMERCE BATCH
-- ============================================
-- Run this to validate the WooCommerce customers before creating them in CP
-- ============================================

DECLARE @BatchID VARCHAR(50) = 'WOO_PULL_20251222_144151';

PRINT '============================================';
PRINT 'PREFLIGHT VALIDATION';
PRINT 'Batch ID: ' + @BatchID;
PRINT '============================================';
PRINT '';

-- Run preflight validation
EXEC dbo.usp_Preflight_Validate_Customer_Staging @BatchID = @BatchID;

PRINT '';
PRINT '============================================';
PRINT 'NEXT STEPS:';
PRINT '============================================';
PRINT '';
PRINT 'If validation PASSED:';
PRINT '  1. Run DRY RUN first:';
PRINT '     EXEC dbo.usp_Create_Customers_From_Staging @BatchID = ''' + @BatchID + ''', @DryRun = 1;';
PRINT '';
PRINT '  2. If DRY RUN looks good, run LIVE:';
PRINT '     EXEC dbo.usp_Create_Customers_From_Staging @BatchID = ''' + @BatchID + ''', @DryRun = 0;';
PRINT '';
PRINT 'If validation FAILED:';
PRINT '  Review the errors above and fix them in USER_CUSTOMER_STAGING';
PRINT '  Then re-run this validation script';
PRINT '';

GO


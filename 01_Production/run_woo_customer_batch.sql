/*
run_woo_customer_batch.sql
Runs: Preflight validation -> Create customers -> Cross-check/mappings hook
Usage (sqlcmd):
  sqlcmd -S SERVER -d WOODYS_CP -E -b -i run_woo_customer_batch.sql -v BatchID="BATCH123" DoDryRun="0" ApplyMappings="0"
Notes:
  - Requires: usp_Preflight_Validate_Customer_Staging, usp_Create_Customers_From_Staging
  - Cross-check is a hook; convert cp_woo_crosscheck.sql to a proc and call it here if desired.
*/

:setvar BatchID ""
:setvar DoDryRun "0"
:setvar ApplyMappings "0"

-- Accept BatchID as parameter (can be passed via -v or set as :setvar)
DECLARE @BatchID       VARCHAR(64);
DECLARE @DoDryRun      BIT;
DECLARE @ApplyMappings BIT;

-- Try to get from :setvar first, then check if passed as parameter
SET @BatchID = '$(BatchID)';
SET @DoDryRun = CASE WHEN '$(DoDryRun)' IN ('1','true','TRUE','True') THEN 1 ELSE 0 END;
SET @ApplyMappings = CASE WHEN '$(ApplyMappings)' IN ('1','true','TRUE','True') THEN 1 ELSE 0 END;

-- If BatchID is still empty, try to get from a stored procedure parameter
-- (This allows calling directly with EXEC as well)
IF @BatchID = '' OR @BatchID IS NULL
BEGIN
    RAISERROR('BatchID is required. Pass -v BatchID="..." when using sqlcmd, or pass @BatchID when calling directly', 16, 1);
    RETURN;
END;

PRINT '============================================================';
PRINT 'Woo -> CounterPoint Customer Batch Runner';
PRINT 'BatchID       : ' + @BatchID;
PRINT 'DoDryRun      : ' + CAST(@DoDryRun AS VARCHAR(10));
PRINT 'ApplyMappings : ' + CAST(@ApplyMappings AS VARCHAR(10));
PRINT 'Started       : ' + CONVERT(VARCHAR(30), SYSDATETIMEOFFSET());
PRINT '============================================================';

BEGIN TRY
    -------------------------------------------------------------------------
    -- 1) Preflight validation (throws on failure inside proc)
    -------------------------------------------------------------------------
    PRINT 'Step 1: Preflight validation...';
    EXEC dbo.usp_Preflight_Validate_Customer_Staging @BatchID = @BatchID;
    PRINT 'Step 1: OK';

    -------------------------------------------------------------------------
    -- 2) Create customers
    -------------------------------------------------------------------------
    PRINT 'Step 2: Create customers...';
    EXEC dbo.usp_Create_Customers_From_Staging @BatchID = @BatchID, @DryRun = @DoDryRun;
    PRINT 'Step 2: OK';

    -------------------------------------------------------------------------
    -- 3) Cross-check / mapping hook (optional)
    -- Convert cp_woo_crosscheck.sql into a stored proc and call it here, e.g.:
    -- EXEC dbo.usp_CP_Woo_Crosscheck @BatchID=@BatchID, @ApplyMappings=@ApplyMappings;
    -------------------------------------------------------------------------
    PRINT 'Step 3: Cross-check/mappings...';
    IF @ApplyMappings = 1
        PRINT 'ApplyMappings=1 (crosscheck proc will attempt mapping).';
    ELSE
        PRINT 'ApplyMappings=0 (report-only).';

    -- Call cross-check proc (created from cp_woo_crosscheck.sql)
    EXEC dbo.usp_CP_Woo_Crosscheck @BatchID = @BatchID, @ApplyMappings = @ApplyMappings;

    PRINT '============================================================';
    PRINT 'SUCCESS: Batch completed: ' + @BatchID;
    PRINT 'Finished: ' + CONVERT(VARCHAR(30), SYSDATETIMEOFFSET());
    PRINT '============================================================';
END TRY
BEGIN CATCH
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @Num INT = ERROR_NUMBER();
    DECLARE @State INT = ERROR_STATE();
    DECLARE @Sev INT = ERROR_SEVERITY();
    DECLARE @Line INT = ERROR_LINE();
    DECLARE @Proc SYSNAME = ERROR_PROCEDURE();

    PRINT '============================================================';
    PRINT 'FAILURE';
    PRINT 'BatchID : ' + @BatchID;
    PRINT 'Error   : ' + @Err;
    PRINT 'Number  : ' + CAST(@Num AS VARCHAR(20));
    PRINT 'Severity: ' + CAST(@Sev AS VARCHAR(20));
    PRINT 'State   : ' + CAST(@State AS VARCHAR(20));
    PRINT 'Line    : ' + CAST(@Line AS VARCHAR(20));
    PRINT 'Proc    : ' + ISNULL(@Proc, '(adhoc)');
    PRINT '============================================================';

    RAISERROR(@Err, 16, 1);
END CATCH;


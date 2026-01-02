-- ============================================
-- CREATE SCHEDULED SYNC JOB
-- SQL Server Agent Job for Daily Customer Sync
-- ============================================
-- This creates a job that:
--   1. Runs Python script to pull customers from WooCommerce
--   2. Runs preflight validation
--   3. Creates customers in CounterPoint
--
-- Schedule: Daily at 2:00 AM (adjustable)
-- ============================================

USE msdb;
GO

-- Drop job if it exists
IF EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE name = 'WP_WooCommerce_Customer_Sync')
BEGIN
    EXEC dbo.sp_delete_job @job_name = 'WP_WooCommerce_Customer_Sync';
    PRINT 'Deleted existing job';
END
GO

-- Create the job
EXEC dbo.sp_add_job
    @job_name = N'WP_WooCommerce_Customer_Sync',
    @enabled = 1,
    @description = N'Daily sync of WooCommerce customers to CounterPoint. Pulls new customers, validates, and creates in AR_CUST.';
GO

-- Step 1: Run Python script to pull customers
EXEC dbo.sp_add_jobstep
    @job_name = N'WP_WooCommerce_Customer_Sync',
    @step_name = N'1. Pull Customers from WooCommerce',
    @subsystem = N'CmdExec',
    @command = N'python.exe "C:\Users\Administrator.ADWPC-MAIN\OneDrive - woodyspaper.com\Desktop\WP_Testcode\woo_customers.py" pull --apply',
    @on_success_action = 3,  -- Go to next step
    @on_fail_action = 2;     -- Quit with failure
GO

-- Step 2: Preflight Validation
EXEC dbo.sp_add_jobstep
    @job_name = N'WP_WooCommerce_Customer_Sync',
    @step_name = N'2. Preflight Validation',
    @subsystem = N'TSQL',
    @command = N'
        USE WOODYS_CP;
        GO
        
        -- Validate all unprocessed staging records
        EXEC dbo.usp_Preflight_Validate_Customer_Staging @BatchID = NULL;
        GO
    ',
    @database_name = N'WOODYS_CP',
    @on_success_action = 3,  -- Go to next step
    @on_fail_action = 2;     -- Quit with failure
GO

-- Step 3: Create Customers (only if validation passed)
EXEC dbo.sp_add_jobstep
    @job_name = N'WP_WooCommerce_Customer_Sync',
    @step_name = N'3. Create Customers in CounterPoint',
    @subsystem = N'TSQL',
    @command = N'
        USE WOODYS_CP;
        GO
        
        -- Create customers from validated staging records
        DECLARE @CreatedCount INT, @ErrorCount INT;
        EXEC dbo.usp_Create_Customers_From_Staging 
            @BatchID = NULL, 
            @DryRun = 0,
            @CreatedCount = @CreatedCount OUTPUT,
            @ErrorCount = @ErrorCount OUTPUT;
        
        PRINT ''Created '' + CAST(@CreatedCount AS VARCHAR) + '' customers'';
        PRINT ''Errors: '' + CAST(@ErrorCount AS VARCHAR);
        GO
    ',
    @database_name = N'WOODYS_CP',
    @on_success_action = 1,  -- Quit with success
    @on_fail_action = 2;     -- Quit with failure
GO

-- Create schedule: Daily at 2:00 AM
EXEC dbo.sp_add_schedule
    @schedule_name = N'Daily_2AM',
    @freq_type = 4,  -- Daily
    @freq_interval = 1,
    @active_start_time = 020000;  -- 2:00 AM
GO

-- Attach schedule to job
EXEC dbo.sp_attach_schedule
    @job_name = N'WP_WooCommerce_Customer_Sync',
    @schedule_name = N'Daily_2AM';
GO

-- Assign job to server
EXEC dbo.sp_add_jobserver
    @job_name = N'WP_WooCommerce_Customer_Sync',
    @server_name = N'(LOCAL)';
GO

PRINT '';
PRINT '============================================';
PRINT 'SCHEDULED JOB CREATED';
PRINT '============================================';
PRINT 'Job Name: WP_WooCommerce_Customer_Sync';
PRINT 'Schedule: Daily at 2:00 AM';
PRINT '';
PRINT 'Steps:';
PRINT '  1. Pull customers from WooCommerce (Python)';
PRINT '  2. Preflight validation (SQL)';
PRINT '  3. Create customers in CounterPoint (SQL)';
PRINT '';
PRINT 'To modify schedule:';
PRINT '  - Right-click job in SQL Server Agent';
PRINT '  - Properties > Schedules';
PRINT '  - Edit or add new schedule';
PRINT '';
PRINT 'To test job:';
PRINT '  - Right-click job > Start Job at Step...';
PRINT '  - Or: EXEC msdb.dbo.sp_start_job @job_name = ''WP_WooCommerce_Customer_Sync'';';
PRINT '============================================';
GO


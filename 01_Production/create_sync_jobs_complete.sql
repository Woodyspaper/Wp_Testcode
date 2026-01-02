-- ============================================
-- CREATE SCHEDULED SYNC JOBS - COMPLETE SETUP
-- SQL Server Agent Jobs for Customer and Order Sync
-- ============================================
-- This creates THREE jobs:
--   1. Customer Sync: Daily at 2:00 AM
--   2. Order Sync: Every 5 minutes (pulls orders to staging)
--   3. Order Processing: Every 5 minutes (processes staged orders - smart/event-driven)
--
-- Prerequisites:
--   - SQL Server Agent must be running
--   - Python must be accessible from SQL Server Agent
--   - Scripts must be in correct path
-- ============================================

USE msdb;
GO

-- ============================================
-- JOB 1: CUSTOMER SYNC (Daily)
-- ============================================

-- Drop job if it exists
IF EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE name = 'WP_WooCommerce_Customer_Sync')
BEGIN
    EXEC dbo.sp_delete_job @job_name = 'WP_WooCommerce_Customer_Sync';
    PRINT 'Deleted existing customer sync job';
END
GO

-- Create the customer sync job
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
    @command = N'"C:\Program Files\Python314\python.exe" "C:\Users\Administrator.ADWPC-MAIN\OneDrive - woodyspaper.com\Desktop\WP_Testcode\woo_customers.py" pull --apply',
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
IF EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE name = 'Daily_2AM')
BEGIN
    EXEC dbo.sp_detach_schedule @job_name = N'WP_WooCommerce_Customer_Sync', @schedule_name = N'Daily_2AM';
    EXEC dbo.sp_delete_schedule @schedule_name = N'Daily_2AM';
END
GO

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
PRINT 'CUSTOMER SYNC JOB CREATED';
PRINT '============================================';
PRINT 'Job Name: WP_WooCommerce_Customer_Sync';
PRINT 'Schedule: Daily at 2:00 AM';
PRINT '';
PRINT 'Steps:';
PRINT '  1. Pull customers from WooCommerce (Python)';
PRINT '  2. Preflight validation (SQL)';
PRINT '  3. Create customers in CounterPoint (SQL)';
PRINT '';
GO

-- ============================================
-- JOB 2: ORDER SYNC (Every 5 minutes)
-- ============================================

-- Drop job if it exists
IF EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE name = 'WP_WooCommerce_Order_Sync')
BEGIN
    EXEC dbo.sp_delete_job @job_name = 'WP_WooCommerce_Order_Sync';
    PRINT 'Deleted existing order sync job';
END
GO

-- Create the order sync job
EXEC dbo.sp_add_job
    @job_name = N'WP_WooCommerce_Order_Sync',
    @enabled = 1,
    @description = N'Frequent sync of WooCommerce orders to CounterPoint staging. Pulls new orders every 5 minutes and stages them for processing.';
GO

-- Step 1: Run Python script to pull orders
EXEC dbo.sp_add_jobstep
    @job_name = N'WP_WooCommerce_Order_Sync',
    @step_name = N'1. Pull Orders from WooCommerce',
    @subsystem = N'CmdExec',
    @command = N'"C:\Program Files\Python314\python.exe" "C:\Users\Administrator.ADWPC-MAIN\OneDrive - woodyspaper.com\Desktop\WP_Testcode\woo_orders.py" pull --apply --days 1',
    @on_success_action = 1,  -- Quit with success
    @on_fail_action = 2;     -- Quit with failure
GO

-- Create schedule: Every 5 minutes
IF EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE name = 'Every_5_Minutes')
BEGIN
    EXEC dbo.sp_detach_schedule @job_name = N'WP_WooCommerce_Order_Sync', @schedule_name = N'Every_5_Minutes';
    EXEC dbo.sp_delete_schedule @schedule_name = N'Every_5_Minutes';
END
GO

EXEC dbo.sp_add_schedule
    @schedule_name = N'Every_5_Minutes',
    @freq_type = 4,  -- Daily
    @freq_interval = 1,
    @freq_subday_type = 4,  -- Minutes
    @freq_subday_interval = 5,  -- Every 5 minutes
    @active_start_time = 000000,  -- Start at midnight
    @active_end_time = 235959;  -- End at 11:59 PM
GO

-- Attach schedule to job
EXEC dbo.sp_attach_schedule
    @job_name = N'WP_WooCommerce_Order_Sync',
    @schedule_name = N'Every_5_Minutes';
GO

-- Assign job to server
EXEC dbo.sp_add_jobserver
    @job_name = N'WP_WooCommerce_Order_Sync',
    @server_name = N'(LOCAL)';
GO

PRINT '';
PRINT '============================================';
PRINT 'ORDER SYNC JOB CREATED';
PRINT '============================================';
PRINT 'Job Name: WP_WooCommerce_Order_Sync';
PRINT 'Schedule: Every 5 minutes';
PRINT '';
PRINT 'Steps:';
PRINT '  1. Pull orders from WooCommerce (Python)';
PRINT '  Note: Orders are staged only (Phase 5 not implemented yet)';
PRINT '';
GO

-- ============================================
-- JOB 3: ORDER PROCESSING (Smart - Every 5 minutes)
-- ============================================
-- Processes staged orders into CounterPoint
-- Uses smart check: only processes when orders are pending

-- Drop job if it exists
IF EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE name = 'WP_WooCommerce_Order_Processing')
BEGIN
    EXEC dbo.sp_delete_job @job_name = 'WP_WooCommerce_Order_Processing';
    PRINT 'Deleted existing order processing job';
END
GO

-- Create the order processing job
EXEC dbo.sp_add_job
    @job_name = N'WP_WooCommerce_Order_Processing',
    @enabled = 1,
    @description = N'Smart order processing: Processes staged orders into CounterPoint. Only runs when orders are pending (event-driven). Checks every 5 minutes.';
GO

-- Step 1: Run PowerShell script (which does smart check + processing)
EXEC dbo.sp_add_jobstep
    @job_name = N'WP_WooCommerce_Order_Processing',
    @step_name = N'1. Process Staged Orders (Smart Check)',
    @subsystem = N'PowerShell',
    @command = N'powershell.exe -ExecutionPolicy Bypass -File "C:\Users\Administrator.ADWPC-MAIN\OneDrive - woodyspaper.com\Desktop\WP_Testcode\Run-WooOrderProcessing-Scheduled.ps1"',
    @on_success_action = 1,  -- Quit with success
    @on_fail_action = 2;     -- Quit with failure
GO

-- Create schedule: Every 5 minutes (check frequency - actual processing only when needed)
IF EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE name = 'Every_5_Minutes_Order_Processing')
BEGIN
    EXEC dbo.sp_detach_schedule @job_name = N'WP_WooCommerce_Order_Processing', @schedule_name = N'Every_5_Minutes_Order_Processing';
    EXEC dbo.sp_delete_schedule @schedule_name = N'Every_5_Minutes_Order_Processing';
END
GO

EXEC dbo.sp_add_schedule
    @schedule_name = N'Every_5_Minutes_Order_Processing',
    @freq_type = 4,  -- Daily
    @freq_interval = 1,
    @freq_subday_type = 4,  -- Minutes
    @freq_subday_interval = 5,  -- Every 5 minutes
    @active_start_time = 000000,  -- Start at midnight
    @active_end_time = 235959;  -- End at 11:59 PM
GO

-- Attach schedule to job
EXEC dbo.sp_attach_schedule
    @job_name = N'WP_WooCommerce_Order_Processing',
    @schedule_name = N'Every_5_Minutes_Order_Processing';
GO

-- Assign job to server
EXEC dbo.sp_add_jobserver
    @job_name = N'WP_WooCommerce_Order_Processing',
    @server_name = N'(LOCAL)';
GO

PRINT '';
PRINT '============================================';
PRINT 'ORDER PROCESSING JOB CREATED';
PRINT '============================================';
PRINT 'Job Name: WP_WooCommerce_Order_Processing';
PRINT 'Schedule: Every 5 minutes (smart check)';
PRINT '';
PRINT 'How it works:';
PRINT '  1. Checks if orders are pending in staging';
PRINT '  2. Only processes if orders are waiting';
PRINT '  3. Falls back to periodic check every 2-3 hours';
PRINT '  4. Processes orders into CounterPoint (PS_DOC_HDR/PS_DOC_LIN)';
PRINT '  5. Syncs order status back to WooCommerce';
PRINT '';
GO

-- ============================================
-- SUMMARY
-- ============================================

PRINT '';
PRINT '============================================';
PRINT 'SCHEDULED JOBS SETUP COMPLETE';
PRINT '============================================';
PRINT '';
PRINT 'Jobs Created:';
PRINT '  1. WP_WooCommerce_Customer_Sync (Daily at 2:00 AM)';
PRINT '  2. WP_WooCommerce_Order_Sync (Every 5 minutes) - Pulls orders to staging';
PRINT '  3. WP_WooCommerce_Order_Processing (Every 5 minutes) - Processes staged orders';
PRINT '';
PRINT 'To verify jobs:';
PRINT '  - Open SQL Server Management Studio';
PRINT '  - Expand: SQL Server Agent > Jobs';
PRINT '  - Right-click job > View History';
PRINT '';
PRINT 'To test jobs manually:';
PRINT '  - Right-click job > Start Job at Step...';
PRINT '  - Or: EXEC msdb.dbo.sp_start_job @job_name = ''WP_WooCommerce_Customer_Sync'';';
PRINT '';
PRINT 'To modify schedules:';
PRINT '  - Right-click job > Properties > Schedules';
PRINT '  - Edit or add new schedule';
PRINT '';
PRINT 'IMPORTANT:';
PRINT '  - Ensure SQL Server Agent is running';
PRINT '  - Verify Python path is correct in job steps';
PRINT '  - Check job history for errors';
PRINT '';
PRINT '============================================';
GO

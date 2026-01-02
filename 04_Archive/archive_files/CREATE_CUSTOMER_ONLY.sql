-- ============================================
-- CREATE CUSTOMER ONLY - Quick Script
-- Use this if you just want to create a customer
-- without running the full test
-- ============================================

USE WOODYS_CP;  -- Change to CPPractice if testing
GO

-- IMPORTANT: Run preflight validation first!
PRINT '============================================';
PRINT 'IMPORTANT: Run preflight validation first!';
PRINT '============================================';
PRINT '';
PRINT 'Before creating customers, run:';
PRINT '  EXEC dbo.usp_Preflight_Validate_Customer_Staging @BatchID = ''YOUR_BATCH_ID'';';
PRINT '';
PRINT 'Only proceed if validation PASSED!';
PRINT '';
GO

-- Replace 'TEST_BATCH_001' with your actual batch ID
DECLARE @BatchID VARCHAR(50) = 'TEST_BATCH_001';

PRINT 'Creating customers from staging...';
PRINT 'Batch ID: ' + @BatchID;
PRINT '';

EXEC dbo.usp_Create_Customers_From_Staging @BatchID = @BatchID;
GO

PRINT '';
PRINT '============================================';
PRINT 'Customer creation complete!';
PRINT 'Check Step 4 in MASTER_TEST_SCRIPT.sql to verify';
PRINT '============================================';
GO


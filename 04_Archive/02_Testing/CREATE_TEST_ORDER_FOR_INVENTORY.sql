-- ============================================
-- CREATE TEST ORDER FOR INVENTORY TESTING
-- ============================================
-- Purpose: Create a test order in staging, then process it
--          to verify inventory updates work correctly
-- ============================================
-- Instructions:
-- 1. Run this script to create a test order
-- 2. Check inventory BEFORE (see PART 1)
-- 3. Process the order (see PART 2)
-- 4. Check inventory AFTER (see PART 3)
-- ============================================

USE WOODYS_CP;
GO

-- ============================================
-- SETUP: Define test data
-- ============================================

-- Test items (use items that exist in your system)
DECLARE @TestItem1 VARCHAR(20) = '01-10100';  -- Replace with actual item
DECLARE @TestItem2 VARCHAR(20) = '01-10102';  -- Replace with actual item

-- Test customer (use an existing customer number)
DECLARE @TestCustNo VARCHAR(15);
SELECT TOP 1 @TestCustNo = CUST_NO 
FROM dbo.AR_CUST 
WHERE IS_ECOMM_CUST = 'Y'
ORDER BY CUST_NO;

IF @TestCustNo IS NULL
BEGIN
    PRINT 'ERROR: No e-commerce customers found. Please create a customer first.';
    RETURN;
END

PRINT 'Using test customer: ' + @TestCustNo;
PRINT 'Using test items: ' + @TestItem1 + ', ' + @TestItem2;
PRINT '';

-- ============================================
-- PART 1: CHECK INVENTORY BEFORE
-- ============================================

PRINT '============================================';
PRINT 'PART 1: INVENTORY BEFORE ORDER';
PRINT '============================================';
PRINT '';

SELECT 
    inv.ITEM_NO,
    inv.LOC_ID,
    inv.QTY_ON_SO AS QtyOnSalesOrder_Before,
    inv.QTY_AVAIL AS QtyAvailable_Before,
    inv.QTY_ON_HND AS QtyOnHand_Before
FROM dbo.IM_INV inv
WHERE inv.ITEM_NO IN (@TestItem1, @TestItem2)
ORDER BY inv.ITEM_NO, inv.LOC_ID;

PRINT '';
PRINT 'Note these values - we will compare after order creation';
PRINT '';

-- ============================================
-- PART 2: CREATE TEST ORDER IN STAGING
-- ============================================

PRINT '============================================';
PRINT 'PART 2: CREATING TEST ORDER IN STAGING';
PRINT '============================================';
PRINT '';

-- Clean up any previous test orders
DELETE FROM dbo.USER_ORDER_STAGING 
WHERE BATCH_ID = 'TEST_INVENTORY_CHECK' OR WOO_ORDER_ID = 999998;

-- Create line items JSON
DECLARE @LineItemsJSON NVARCHAR(MAX);
SET @LineItemsJSON = '[' +
    '{"sku":"' + @TestItem1 + '","name":"Test Product 1","quantity":2,"price":10.50,"total":21.00},' +
    '{"sku":"' + @TestItem2 + '","name":"Test Product 2","quantity":1,"price":15.75,"total":15.75}' +
']';

-- Insert test order into staging
INSERT INTO dbo.USER_ORDER_STAGING (
    BATCH_ID,
    WOO_ORDER_ID,
    WOO_ORDER_NO,
    CUST_NO,
    CUST_EMAIL,
    ORD_DAT,
    ORD_STATUS,
    PMT_METH,
    SHIP_VIA,
    SUBTOT,
    SHIP_AMT,
    TAX_AMT,
    DISC_AMT,
    TOT_AMT,
    SHIP_NAM,
    SHIP_ADRS_1,
    SHIP_CITY,
    SHIP_STATE,
    SHIP_ZIP_COD,
    SHIP_CNTRY,
    LINE_ITEMS_JSON,
    IS_VALIDATED,
    IS_APPLIED
)
VALUES (
    'TEST_INVENTORY_CHECK',
    999998,
    'TEST-999998',
    @TestCustNo,
    'test@example.com',
    CAST(GETDATE() AS DATE),
    'processing',
    'Credit Card',
    'Standard Shipping',
    36.75,  -- Subtotal (21.00 + 15.75)
    5.00,   -- Shipping
    2.50,   -- Tax
    0.00,   -- Discount
    44.25,  -- Total
    'Test Customer',
    '123 Test Street',
    'Miami',
    'FL',
    '33101',
    'US',
    @LineItemsJSON,
    0,  -- Not validated yet
    0   -- Not applied yet
);

DECLARE @TestStagingID INT;
SET @TestStagingID = SCOPE_IDENTITY();

PRINT '✅ Test order created in staging';
PRINT '   STAGING_ID: ' + CAST(@TestStagingID AS VARCHAR);
PRINT '   CUST_NO: ' + @TestCustNo;
PRINT '   Total: $44.25';
PRINT '   Items: ' + @TestItem1 + ' (qty 2), ' + @TestItem2 + ' (qty 1)';
PRINT '';

-- ============================================
-- PART 3: VALIDATE THE ORDER
-- ============================================

PRINT '============================================';
PRINT 'PART 3: VALIDATING ORDER';
PRINT '============================================';
PRINT '';

DECLARE @IsValid BIT;
DECLARE @ValidationError NVARCHAR(500);

EXEC dbo.sp_ValidateStagedOrder
    @StagingID = @TestStagingID,
    @IsValid = @IsValid OUTPUT,
    @ErrorMessage = @ValidationError OUTPUT;

IF @IsValid = 1
BEGIN
    PRINT '✅ VALIDATION PASSED';
    PRINT '   Order is valid and ready to process';
END
ELSE
BEGIN
    PRINT '❌ VALIDATION FAILED';
    PRINT '   Error: ' + ISNULL(@ValidationError, 'Unknown error');
    PRINT '';
    PRINT 'Cannot proceed with order creation. Please fix validation errors.';
    RETURN;
END
PRINT '';

-- ============================================
-- PART 4: CREATE ORDER IN COUNTERPOINT
-- ============================================

PRINT '============================================';
PRINT 'PART 4: CREATING ORDER IN COUNTERPOINT';
PRINT '============================================';
PRINT '';

DECLARE @DocID BIGINT;
DECLARE @TktNo VARCHAR(15);
DECLARE @Success BIT;
DECLARE @ErrorMessage NVARCHAR(500);

EXEC dbo.sp_CreateOrderFromStaging
    @StagingID = @TestStagingID,
    @DocID = @DocID OUTPUT,
    @TktNo = @TktNo OUTPUT,
    @Success = @Success OUTPUT,
    @ErrorMessage = @ErrorMessage OUTPUT;

IF @Success = 1
BEGIN
    PRINT '✅ ORDER CREATED SUCCESSFULLY';
    PRINT '   DOC_ID: ' + CAST(@DocID AS VARCHAR);
    PRINT '   TKT_NO: ' + @TktNo;
    PRINT '';
    PRINT 'Inventory should now be updated!';
END
ELSE
BEGIN
    PRINT '❌ ORDER CREATION FAILED';
    PRINT '   Error: ' + ISNULL(@ErrorMessage, 'Unknown error');
    RETURN;
END
PRINT '';

-- ============================================
-- PART 5: CHECK INVENTORY AFTER
-- ============================================

PRINT '============================================';
PRINT 'PART 5: INVENTORY AFTER ORDER';
PRINT '============================================';
PRINT '';

SELECT 
    inv.ITEM_NO,
    inv.LOC_ID,
    inv.QTY_ON_SO AS QtyOnSalesOrder_After,
    inv.QTY_AVAIL AS QtyAvailable_After,
    inv.QTY_ON_HND AS QtyOnHand_After,
    -- Calculate changes
    inv.QTY_ON_SO - 
        (SELECT ISNULL(SUM(QTY_ON_SO), 0) 
         FROM dbo.IM_INV inv2 
         WHERE inv2.ITEM_NO = inv.ITEM_NO 
           AND inv2.LOC_ID = inv.LOC_ID 
           AND inv2.ITEM_NO IN (@TestItem1, @TestItem2)
         GROUP BY inv2.ITEM_NO, inv2.LOC_ID) AS QtyOnSO_Change
FROM dbo.IM_INV inv
WHERE inv.ITEM_NO IN (@TestItem1, @TestItem2)
ORDER BY inv.ITEM_NO, inv.LOC_ID;

PRINT '';
PRINT '============================================';
PRINT 'EXPECTED RESULTS:';
PRINT '============================================';
PRINT 'For ' + @TestItem1 + ' (ordered qty 2):';
PRINT '  - QTY_ON_SO should INCREASE by 2';
PRINT '  - QTY_AVAIL should DECREASE (recalculated automatically)';
PRINT '';
PRINT 'For ' + @TestItem2 + ' (ordered qty 1):';
PRINT '  - QTY_ON_SO should INCREASE by 1';
PRINT '  - QTY_AVAIL should DECREASE (recalculated automatically)';
PRINT '';
PRINT 'If QTY_ON_SO increased correctly → ✅ Inventory update working!';
PRINT 'If QTY_ON_SO is still 0 → ❌ Inventory update not working';
PRINT '';

-- ============================================
-- PART 6: VERIFY ORDER WAS CREATED
-- ============================================

PRINT '============================================';
PRINT 'PART 6: VERIFY ORDER IN COUNTERPOINT';
PRINT '============================================';
PRINT '';

SELECT 
    h.TKT_NO,
    h.DOC_ID,
    h.TKT_DT,
    h.CUST_NO,
    l.ITEM_NO,
    l.QTY_SOLD,
    l.PRC
FROM dbo.PS_DOC_HDR h
INNER JOIN dbo.PS_DOC_LIN l ON l.DOC_ID = h.DOC_ID
WHERE h.DOC_ID = @DocID
ORDER BY l.LIN_SEQ_NO;

PRINT '';
PRINT '============================================';
PRINT 'TEST COMPLETE';
PRINT '============================================';
PRINT '';
PRINT 'To clean up this test order, run:';
PRINT '  DELETE FROM dbo.USER_ORDER_STAGING WHERE STAGING_ID = ' + CAST(@TestStagingID AS VARCHAR) + ';';
PRINT '  -- Note: Order in PS_DOC_HDR/PS_DOC_LIN will remain (manual cleanup if needed)';
PRINT '';

GO

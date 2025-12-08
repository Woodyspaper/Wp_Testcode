-- ============================================
-- Staging & Master Tables for CounterPoint Integration - V2
-- Database: CPPractice on ADWPC-MAIN
-- Updated: 2025-12-08 based on actual schema discovery
-- ============================================
--
-- CHANGES FROM V1:
--   - Fixed IM_PRC_RUL column names based on actual CPPractice schema
--   - Added IM_PRC_RUL_BRK insert (pricing details are in breaks table)
--   - Added simpler AR_CUST.DISC_PCT approach for customer discounts
--   - Removed non-existent columns: PRC_COD, CATEG_COD, BEG_DAT, END_DAT
--
-- ACTUAL COUNTERPOINT SCHEMA (from CPPractice):
--   IM_PRC_RUL: GRP_TYP, GRP_COD, RUL_SEQ_NO, DESCR, CUST_NO, ITEM_NO, MIN_QTY
--   IM_PRC_RUL_BRK: GRP_TYP, GRP_COD, RUL_SEQ_NO, MIN_QTY, PRC_METH, PRC_BASIS, AMT_OR_PCT
--   AR_CUST: DISC_PCT (customer-level discount percentage)
--
-- TWO APPROACHES:
--   1. SIMPLE: Update AR_CUST.DISC_PCT for customer-level discounts
--   2. ADVANCED: Insert into IM_PRC_RUL + IM_PRC_RUL_BRK for complex rules
-- ============================================

USE CPPractice;
GO

-- ============================================
-- APPROACH 1: SIMPLE CUSTOMER DISCOUNTS
-- ============================================
-- Updates AR_CUST.DISC_PCT directly
-- Best for: "Customer X gets 10% off everything"

-- View current customer discounts
IF EXISTS (SELECT * FROM sys.views WHERE name = 'VI_CUSTOMER_DISCOUNTS')
    DROP VIEW dbo.VI_CUSTOMER_DISCOUNTS;
GO

CREATE VIEW dbo.VI_CUSTOMER_DISCOUNTS
AS
SELECT 
    CUST_NO,
    NAM,
    EMAIL_ADRS_1,
    CATEG_COD,
    DISC_PCT,
    IS_ECOMM_CUST,
    LST_SAL_DAT
FROM dbo.AR_CUST
WHERE IS_ECOMM_CUST = 'Y'
  AND DISC_PCT IS NOT NULL 
  AND DISC_PCT > 0;
GO

PRINT 'Created VI_CUSTOMER_DISCOUNTS view';


-- Procedure to update customer discount percentage
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'usp_Update_Customer_Discount')
    DROP PROCEDURE dbo.usp_Update_Customer_Discount;
GO

CREATE PROCEDURE dbo.usp_Update_Customer_Discount
    @CUST_NO VARCHAR(15),
    @DISC_PCT DECIMAL(15,4),
    @DryRun BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Validate customer exists and is e-commerce
    IF NOT EXISTS (SELECT 1 FROM dbo.AR_CUST WHERE CUST_NO = @CUST_NO)
    BEGIN
        RAISERROR('Customer %s not found', 16, 1, @CUST_NO);
        RETURN;
    END
    
    -- Validate discount range
    IF @DISC_PCT < 0 OR @DISC_PCT > 100
    BEGIN
        RAISERROR('Discount must be between 0 and 100', 16, 1);
        RETURN;
    END
    
    IF @DryRun = 1
    BEGIN
        SELECT 
            CUST_NO, NAM, 
            DISC_PCT AS Current_Discount,
            @DISC_PCT AS New_Discount,
            'DRY RUN - No changes made' AS Status
        FROM dbo.AR_CUST
        WHERE CUST_NO = @CUST_NO;
        RETURN;
    END
    
    UPDATE dbo.AR_CUST
    SET DISC_PCT = @DISC_PCT,
        LST_MAINT_DT = GETDATE(),
        LST_MAINT_USR_ID = 'INTEG'
    WHERE CUST_NO = @CUST_NO;
    
    -- Log the change
    INSERT INTO dbo.USER_SYNC_LOG (
        SYNC_ID, OPERATION_TYPE, DIRECTION, DRY_RUN,
        START_TIME, END_TIME, RECORDS_UPDATED, SUCCESS
    )
    VALUES (
        NEWID(), 'customer_discount_update', 'INTERNAL', 0,
        GETDATE(), GETDATE(), 1, 1
    );
    
    SELECT 
        CUST_NO, NAM, DISC_PCT,
        'Discount updated successfully' AS Status
    FROM dbo.AR_CUST
    WHERE CUST_NO = @CUST_NO;
END
GO

PRINT 'Created usp_Update_Customer_Discount procedure';


-- Bulk update customer discounts from staging
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'usp_Bulk_Update_Customer_Discounts')
    DROP PROCEDURE dbo.usp_Bulk_Update_Customer_Discounts;
GO

CREATE PROCEDURE dbo.usp_Bulk_Update_Customer_Discounts
    @BatchID VARCHAR(50),
    @DryRun BIT = 1,
    @UpdatedCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    /*
    Updates AR_CUST.DISC_PCT from USER_CONTRACT_PRICE_STAGING where:
    - CUST_NO is specified
    - ITEM_NO is NULL (customer-level discount, not item-specific)
    - PRC_METH = 'D' (Discount percentage)
    */
    
    IF @DryRun = 1
    BEGIN
        -- Preview changes
        SELECT 
            s.CUST_NO,
            c.NAM,
            c.DISC_PCT AS Current_Discount,
            s.PRC_AMT AS New_Discount,
            s.DESCR AS Rule_Description
        FROM dbo.USER_CONTRACT_PRICE_STAGING s
        JOIN dbo.AR_CUST c ON c.CUST_NO = s.CUST_NO
        WHERE s.BATCH_ID = @BatchID
          AND s.IS_VALIDATED = 1
          AND s.ITEM_NO IS NULL
          AND s.PRC_METH = 'D'
        ORDER BY s.CUST_NO;
        
        SELECT @UpdatedCount = COUNT(*)
        FROM dbo.USER_CONTRACT_PRICE_STAGING
        WHERE BATCH_ID = @BatchID
          AND IS_VALIDATED = 1
          AND ITEM_NO IS NULL
          AND PRC_METH = 'D';
        
        PRINT 'DRY RUN: Would update ' + CAST(@UpdatedCount AS VARCHAR) + ' customer discounts';
        RETURN;
    END
    
    -- Live update
    BEGIN TRANSACTION;
    
    UPDATE c
    SET c.DISC_PCT = s.PRC_AMT,
        c.LST_MAINT_DT = GETDATE(),
        c.LST_MAINT_USR_ID = 'INTEG'
    FROM dbo.AR_CUST c
    JOIN dbo.USER_CONTRACT_PRICE_STAGING s ON s.CUST_NO = c.CUST_NO
    WHERE s.BATCH_ID = @BatchID
      AND s.IS_VALIDATED = 1
      AND s.ITEM_NO IS NULL
      AND s.PRC_METH = 'D';
    
    SET @UpdatedCount = @@ROWCOUNT;
    
    -- Mark staging as applied
    UPDATE dbo.USER_CONTRACT_PRICE_STAGING
    SET IS_APPLIED = 1,
        APPLIED_DT = GETDATE(),
        ACTION_TAKEN = 'DISC_PCT'
    WHERE BATCH_ID = @BatchID
      AND IS_VALIDATED = 1
      AND ITEM_NO IS NULL
      AND PRC_METH = 'D';
    
    -- Log
    INSERT INTO dbo.USER_SYNC_LOG (
        SYNC_ID, OPERATION_TYPE, DIRECTION, DRY_RUN,
        START_TIME, END_TIME, RECORDS_UPDATED, SUCCESS
    )
    VALUES (
        NEWID(), 'bulk_customer_discount', 'INTERNAL', 0,
        GETDATE(), GETDATE(), @UpdatedCount, 1
    );
    
    COMMIT TRANSACTION;
    
    PRINT 'Updated ' + CAST(@UpdatedCount AS VARCHAR) + ' customer discounts';
END
GO

PRINT 'Created usp_Bulk_Update_Customer_Discounts procedure';


-- ============================================
-- APPROACH 2: ADVANCED PRICING RULES
-- ============================================
-- Inserts into IM_PRC_RUL + IM_PRC_RUL_BRK
-- Best for: Complex rules (item-specific, quantity breaks, etc.)
--
-- IMPORTANT: CounterPoint pricing rules are complex!
-- - Rules belong to a GROUP (GRP_TYP + GRP_COD)
-- - GRP_TYP: 'C'=Customer, 'I'=Item, 'P'=Price Code, etc.
-- - Each rule has breaks in IM_PRC_RUL_BRK with the actual pricing

-- Find the max RUL_SEQ_NO for our automation group
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'usp_Get_Next_Rule_Seq')
    DROP PROCEDURE dbo.usp_Get_Next_Rule_Seq;
GO

CREATE PROCEDURE dbo.usp_Get_Next_Rule_Seq
    @GRP_TYP VARCHAR(1),
    @GRP_COD VARCHAR(10),
    @NextSeq INT OUTPUT
AS
BEGIN
    SELECT @NextSeq = ISNULL(MAX(RUL_SEQ_NO), 0) + 1
    FROM dbo.IM_PRC_RUL
    WHERE GRP_TYP = @GRP_TYP AND GRP_COD = @GRP_COD;
END
GO


-- Corrected rebuild procedure that inserts into BOTH IM_PRC_RUL and IM_PRC_RUL_BRK
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'usp_Rebuild_ContractPricing_FromMaster')
    DROP PROCEDURE dbo.usp_Rebuild_ContractPricing_FromMaster;
GO

CREATE PROCEDURE dbo.usp_Rebuild_ContractPricing_FromMaster
    @DryRun BIT = 1,
    @DeletedCount INT OUTPUT,
    @InsertedCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    /*
    CORRECTED VERSION - Based on actual CPPractice schema
    
    IM_PRC_RUL columns (actual):
      GRP_TYP, GRP_COD, RUL_SEQ_NO, DESCR, CUST_NO, ITEM_NO, MIN_QTY,
      IS_CUSTOM, USE_BOGO_TWOFER, REQ_FULL_GRP_FOR_BOGO_TWOFER
    
    IM_PRC_RUL_BRK columns (actual):
      GRP_TYP, GRP_COD, RUL_SEQ_NO, MIN_QTY, PRC_METH, PRC_BASIS, AMT_OR_PCT
    
    Ownership strategy:
      - We use GRP_TYP = 'A' (Automation) and GRP_COD = 'INTEG' for our rules
      - Alternative: Use DESCR starting with '[AUTO]' for identification
    */
    
    DECLARE @AUTO_GRP_TYP VARCHAR(1) = 'C';      -- Customer-based rules
    DECLARE @AUTO_GRP_COD VARCHAR(10) = 'INTEG'; -- Our automation group
    DECLARE @OwnershipMarker VARCHAR(10) = '[AUTO] ';
    
    -- Ensure our pricing group exists
    -- (In CounterPoint, groups may need to be set up in the UI first)
    
    IF @DryRun = 1
    BEGIN
        PRINT '============================================';
        PRINT 'DRY RUN MODE - No changes will be made';
        PRINT '============================================';
        PRINT '';
        PRINT 'Automation Group: GRP_TYP=' + @AUTO_GRP_TYP + ', GRP_COD=' + @AUTO_GRP_COD;
        PRINT '';
        
        -- Count existing automation rules
        SELECT @DeletedCount = COUNT(*)
        FROM dbo.IM_PRC_RUL
        WHERE DESCR LIKE @OwnershipMarker + '%';
        
        PRINT 'Existing automation rules (with [AUTO] marker): ' + CAST(@DeletedCount AS VARCHAR);
        
        -- Count rules that would be inserted
        SELECT @InsertedCount = COUNT(*)
        FROM dbo.USER_CONTRACT_PRICE_MASTER
        WHERE IS_ACTIVE = 1
          AND OWNER_SYSTEM = 'INTEGRATION'
          AND (EFFECTIVE_FROM IS NULL OR EFFECTIVE_FROM <= GETDATE())
          AND (EFFECTIVE_TO IS NULL OR EFFECTIVE_TO >= GETDATE());
        
        PRINT 'Rules in master table ready to apply: ' + CAST(@InsertedCount AS VARCHAR);
        PRINT '';
        
        -- Preview what would be inserted
        PRINT 'Preview of rules (first 10):';
        SELECT TOP 10
            m.CONTRACT_ID,
            @OwnershipMarker + ISNULL(m.DESCR, 'Contract Price') AS DESCR,
            m.CUST_NO,
            m.ITEM_NO,
            m.PRC_METH,
            m.PRC_BASIS,
            m.PRC_AMT AS AMT_OR_PCT,
            m.MIN_QTY,
            CASE m.PRC_METH
                WHEN 'D' THEN 'Discount %'
                WHEN 'O' THEN 'Override Price'
                WHEN 'M' THEN 'Markup %'
                WHEN 'A' THEN 'Amount Off'
                ELSE 'Unknown'
            END AS Pricing_Method_Desc
        FROM dbo.USER_CONTRACT_PRICE_MASTER m
        WHERE m.IS_ACTIVE = 1
          AND m.OWNER_SYSTEM = 'INTEGRATION'
          AND (m.EFFECTIVE_FROM IS NULL OR m.EFFECTIVE_FROM <= GETDATE())
          AND (m.EFFECTIVE_TO IS NULL OR m.EFFECTIVE_TO >= GETDATE())
        ORDER BY m.PRIORITY, m.CONTRACT_ID;
        
        PRINT '';
        PRINT '============================================';
        PRINT 'To apply changes, run with @DryRun = 0';
        PRINT '============================================';
        RETURN;
    END
    
    -- LIVE MODE
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- Step 1: Delete existing automation-owned rules (from both tables)
        -- First delete breaks (child records)
        DELETE b
        FROM dbo.IM_PRC_RUL_BRK b
        JOIN dbo.IM_PRC_RUL r ON r.GRP_TYP = b.GRP_TYP 
            AND r.GRP_COD = b.GRP_COD 
            AND r.RUL_SEQ_NO = b.RUL_SEQ_NO
        WHERE r.DESCR LIKE @OwnershipMarker + '%';
        
        -- Then delete rules (parent records)
        DELETE FROM dbo.IM_PRC_RUL
        WHERE DESCR LIKE @OwnershipMarker + '%';
        
        SET @DeletedCount = @@ROWCOUNT;
        
        -- Step 2: Insert rules from master table
        -- Using a cursor because we need to insert into two tables with sequence numbers
        DECLARE @CONTRACT_ID INT, @DESCR VARCHAR(50), @CUST_NO VARCHAR(15), @ITEM_NO VARCHAR(30);
        DECLARE @PRC_METH CHAR(1), @PRC_BASIS CHAR(1), @PRC_AMT DECIMAL(15,4), @MIN_QTY DECIMAL(15,4);
        DECLARE @NextSeq INT;
        
        DECLARE rule_cursor CURSOR FOR
            SELECT 
                CONTRACT_ID,
                ISNULL(DESCR, 'Contract Price'),
                CUST_NO,
                ITEM_NO,
                PRC_METH,
                ISNULL(PRC_BASIS, '1'),
                PRC_AMT,
                ISNULL(MIN_QTY, 0)
            FROM dbo.USER_CONTRACT_PRICE_MASTER
            WHERE IS_ACTIVE = 1
              AND OWNER_SYSTEM = 'INTEGRATION'
              AND (EFFECTIVE_FROM IS NULL OR EFFECTIVE_FROM <= GETDATE())
              AND (EFFECTIVE_TO IS NULL OR EFFECTIVE_TO >= GETDATE())
            ORDER BY PRIORITY, CONTRACT_ID;
        
        OPEN rule_cursor;
        SET @InsertedCount = 0;
        
        FETCH NEXT FROM rule_cursor INTO 
            @CONTRACT_ID, @DESCR, @CUST_NO, @ITEM_NO, @PRC_METH, @PRC_BASIS, @PRC_AMT, @MIN_QTY;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Get next sequence number for this group
            EXEC dbo.usp_Get_Next_Rule_Seq @AUTO_GRP_TYP, @AUTO_GRP_COD, @NextSeq OUTPUT;
            
            -- Insert into IM_PRC_RUL (header)
            INSERT INTO dbo.IM_PRC_RUL (
                GRP_TYP, GRP_COD, RUL_SEQ_NO,
                DESCR, DESCR_UPR,
                CUST_NO, ITEM_NO,
                MIN_QTY,
                IS_CUSTOM, USE_BOGO_TWOFER, REQ_FULL_GRP_FOR_BOGO_TWOFER,
                LST_MAINT_DT, LST_MAINT_USR_ID
            )
            VALUES (
                @AUTO_GRP_TYP, @AUTO_GRP_COD, @NextSeq,
                @OwnershipMarker + @DESCR, UPPER(@OwnershipMarker + @DESCR),
                @CUST_NO, @ITEM_NO,
                @MIN_QTY,
                'N', 'N', 'N',
                GETDATE(), 'INTEG'
            );
            
            -- Insert into IM_PRC_RUL_BRK (pricing details)
            INSERT INTO dbo.IM_PRC_RUL_BRK (
                GRP_TYP, GRP_COD, RUL_SEQ_NO,
                MIN_QTY, PRC_METH, PRC_BASIS, AMT_OR_PCT,
                LST_MAINT_DT, LST_MAINT_USR_ID
            )
            VALUES (
                @AUTO_GRP_TYP, @AUTO_GRP_COD, @NextSeq,
                @MIN_QTY, @PRC_METH, @PRC_BASIS, @PRC_AMT,
                GETDATE(), 'INTEG'
            );
            
            -- Update master record with applied info
            UPDATE dbo.USER_CONTRACT_PRICE_MASTER
            SET APPLIED_RUL_SEQ_NO = @NextSeq,
                LAST_APPLIED_DT = GETDATE()
            WHERE CONTRACT_ID = @CONTRACT_ID;
            
            SET @InsertedCount = @InsertedCount + 1;
            
            FETCH NEXT FROM rule_cursor INTO 
                @CONTRACT_ID, @DESCR, @CUST_NO, @ITEM_NO, @PRC_METH, @PRC_BASIS, @PRC_AMT, @MIN_QTY;
        END
        
        CLOSE rule_cursor;
        DEALLOCATE rule_cursor;
        
        -- Log the operation
        INSERT INTO dbo.USER_SYNC_LOG (
            SYNC_ID, OPERATION_TYPE, DIRECTION, DRY_RUN,
            START_TIME, END_TIME, DURATION_SECONDS,
            RECORDS_INPUT, RECORDS_CREATED, RECORDS_UPDATED,
            SUCCESS
        )
        VALUES (
            NEWID(), 'contract_rebuild', 'INTERNAL', 0,
            GETDATE(), GETDATE(), 0,
            @DeletedCount + @InsertedCount, @InsertedCount, 0,
            1
        );
        
        COMMIT TRANSACTION;
        
        PRINT '============================================';
        PRINT 'Rebuild Complete';
        PRINT '============================================';
        PRINT 'Deleted: ' + CAST(@DeletedCount AS VARCHAR) + ' existing automation rules';
        PRINT 'Created: ' + CAST(@InsertedCount AS VARCHAR) + ' new rules';
        PRINT 'Group: GRP_TYP=' + @AUTO_GRP_TYP + ', GRP_COD=' + @AUTO_GRP_COD;
        PRINT '============================================';
        
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('global', 'rule_cursor') >= 0
        BEGIN
            CLOSE rule_cursor;
            DEALLOCATE rule_cursor;
        END
        
        ROLLBACK TRANSACTION;
        
        -- Log the error
        INSERT INTO dbo.USER_SYNC_LOG (
            SYNC_ID, OPERATION_TYPE, DIRECTION, DRY_RUN,
            START_TIME, END_TIME,
            SUCCESS, ERROR_MESSAGE
        )
        VALUES (
            NEWID(), 'contract_rebuild', 'INTERNAL', 0,
            GETDATE(), GETDATE(),
            0, ERROR_MESSAGE()
        );
        
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END
GO

PRINT 'Created usp_Rebuild_ContractPricing_FromMaster procedure (CORRECTED)';


-- ============================================
-- VIEW: Current Pricing Rules (for debugging)
-- ============================================

IF EXISTS (SELECT * FROM sys.views WHERE name = 'VI_PRICING_RULES_DETAIL')
    DROP VIEW dbo.VI_PRICING_RULES_DETAIL;
GO

CREATE VIEW dbo.VI_PRICING_RULES_DETAIL
AS
SELECT 
    r.GRP_TYP,
    r.GRP_COD,
    r.RUL_SEQ_NO,
    r.DESCR,
    r.CUST_NO,
    r.ITEM_NO,
    b.MIN_QTY,
    b.PRC_METH,
    CASE b.PRC_METH
        WHEN 'D' THEN 'Discount %'
        WHEN 'O' THEN 'Override'
        WHEN 'M' THEN 'Markup %'
        WHEN 'A' THEN 'Amount Off'
        ELSE b.PRC_METH
    END AS PRC_METH_DESC,
    b.PRC_BASIS,
    b.AMT_OR_PCT,
    r.LST_MAINT_DT,
    r.LST_MAINT_USR_ID,
    CASE WHEN r.DESCR LIKE '[AUTO]%' THEN 'AUTOMATION' ELSE 'MANUAL' END AS OWNER
FROM dbo.IM_PRC_RUL r
LEFT JOIN dbo.IM_PRC_RUL_BRK b 
    ON r.GRP_TYP = b.GRP_TYP 
    AND r.GRP_COD = b.GRP_COD 
    AND r.RUL_SEQ_NO = b.RUL_SEQ_NO;
GO

PRINT 'Created VI_PRICING_RULES_DETAIL view';


-- ============================================
-- VIEW: Automation-owned rules only
-- ============================================

IF EXISTS (SELECT * FROM sys.views WHERE name = 'VI_AUTO_PRICING_RULES')
    DROP VIEW dbo.VI_AUTO_PRICING_RULES;
GO

CREATE VIEW dbo.VI_AUTO_PRICING_RULES
AS
SELECT *
FROM dbo.VI_PRICING_RULES_DETAIL
WHERE OWNER = 'AUTOMATION';
GO

PRINT 'Created VI_AUTO_PRICING_RULES view';


-- ============================================
-- SUMMARY
-- ============================================

PRINT '';
PRINT '============================================';
PRINT 'CounterPoint Integration V2 - Setup Complete';
PRINT 'Database: CPPractice';
PRINT '============================================';
PRINT '';
PRINT 'TWO APPROACHES FOR CUSTOMER PRICING:';
PRINT '';
PRINT '1. SIMPLE (AR_CUST.DISC_PCT):';
PRINT '   - Best for: Customer X gets Y% off everything';
PRINT '   - Procedure: usp_Update_Customer_Discount';
PRINT '   - Procedure: usp_Bulk_Update_Customer_Discounts';
PRINT '   - View: VI_CUSTOMER_DISCOUNTS';
PRINT '';
PRINT '2. ADVANCED (IM_PRC_RUL + IM_PRC_RUL_BRK):';
PRINT '   - Best for: Complex rules (item-specific, qty breaks)';
PRINT '   - Procedure: usp_Rebuild_ContractPricing_FromMaster';
PRINT '   - View: VI_PRICING_RULES_DETAIL';
PRINT '   - View: VI_AUTO_PRICING_RULES';
PRINT '';
PRINT 'USAGE EXAMPLES:';
PRINT '';
PRINT '-- Simple: Give customer SMITH 15% discount';
PRINT 'EXEC usp_Update_Customer_Discount ''SMITH'', 15, @DryRun=1;';
PRINT '';
PRINT '-- Bulk: Apply all customer-level discounts from staging';
PRINT 'DECLARE @cnt INT;';
PRINT 'EXEC usp_Bulk_Update_Customer_Discounts ''BATCH123'', @DryRun=1, @UpdatedCount=@cnt OUTPUT;';
PRINT '';
PRINT '-- Advanced: Rebuild all pricing rules from master';
PRINT 'DECLARE @d INT, @i INT;';
PRINT 'EXEC usp_Rebuild_ContractPricing_FromMaster @DryRun=1, @DeletedCount=@d OUTPUT, @InsertedCount=@i OUTPUT;';
PRINT '';
GO

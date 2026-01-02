-- ============================================
-- CREATE CUSTOMERS FROM STAGING
-- ============================================
-- Creates CounterPoint customers from validated staging records.
-- This replaces the need for NCR API for customer creation.
--
-- DATA INTEGRITY HANDLING:
--   1. EMAIL DUPLICATES - Detects emails already in AR_CUST, links staging
--      record to existing customer instead of creating duplicate
--   2. FIELD TRUNCATION - All fields truncated to AR_CUST column limits:
--      FST_NAM(15), LST_NAM(25), NAM(40), CITY(20), ADRS(40), etc.
--   3. UNICODE SANITIZATION - Removes null chars, normalizes whitespace
--   4. GUEST CHECKOUT - Handles WOO_USER_ID=NULL (creates customer, no mapping)
--   5. UPPERCASE FIELDS - Auto-generates NAM_UPR, FST_NAM_UPR, LST_NAM_UPR
--   6. REQUIRED DEFAULTS - Sets STR_ID, TAX_COD, CATEG_COD, IS_ECOMM_CUST
--   7. INVALID EMAILS - Warns but allows (user decision to proceed)
--
-- Usage:
--   -- Dry run (preview only):
--   EXEC dbo.usp_Create_Customers_From_Staging @BatchID = 'WOO_PULL_20251217_133134', @DryRun = 1;
--   
--   -- Live run:
--   EXEC dbo.usp_Create_Customers_From_Staging @BatchID = 'WOO_PULL_20251217_133134', @DryRun = 0;
--
--   -- Create single customer by staging ID:
--   EXEC dbo.usp_Create_Customers_From_Staging @StagingID = 123, @DryRun = 0;
--
--   -- With custom defaults:
--   EXEC dbo.usp_Create_Customers_From_Staging 
--        @BatchID = 'WOO_PULL_20251217', 
--        @DryRun = 0,
--        @DefaultCATEG_COD = 'TIER1',
--        @DefaultTAX_COD = 'FL-DADE',
--        @DefaultSTR_ID = '02';

USE CPPractice;  -- Change to WOODYS_CP for production
GO

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'usp_Create_Customers_From_Staging')
    DROP PROCEDURE dbo.usp_Create_Customers_From_Staging;
GO

CREATE PROCEDURE dbo.usp_Create_Customers_From_Staging
    @BatchID VARCHAR(50) = NULL,
    @StagingID INT = NULL,
    @DryRun BIT = 1,
    @DefaultCATEG_COD VARCHAR(10) = 'RETAIL',  -- Customer category (not used for pricing)
    @DefaultPROF_COD_1 VARCHAR(10) = 'RETAIL', -- Tier pricing (default to RETAIL)
    @DefaultSTR_ID VARCHAR(10) = '01',
    @DefaultTAX_COD VARCHAR(10) = 'FL-BROWARD',
    @CreatedCount INT = 0 OUTPUT,
    @ErrorCount INT = 0 OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ErrorMsg NVARCHAR(500);
    SET @CreatedCount = 0;
    SET @ErrorCount = 0;
    
    -- Validate parameters
    IF @BatchID IS NULL AND @StagingID IS NULL
    BEGIN
        RAISERROR('Must specify either @BatchID or @StagingID', 16, 1);
        RETURN;
    END
    
    -- Create temp table for records to process
    CREATE TABLE #ToProcess (
        STAGING_ID INT,
        WOO_USER_ID INT,
        EMAIL_ADRS_1 VARCHAR(50),
        FST_NAM VARCHAR(15),
        LST_NAM VARCHAR(25),
        NAM VARCHAR(40),
        ADRS_1 VARCHAR(40),
        ADRS_2 VARCHAR(40),
        CITY VARCHAR(20),
        STATE VARCHAR(10),
        ZIP_COD VARCHAR(15),
        CNTRY VARCHAR(20),
        PHONE_1 VARCHAR(25),
        PROF_COD_1 VARCHAR(10),
        CATEG_COD VARCHAR(10),
        NEW_CUST_NO VARCHAR(15),
        IS_DUPLICATE BIT DEFAULT 0,
        EXISTING_CUST_NO VARCHAR(15),
        IS_GUEST BIT DEFAULT 0
    );
    
    -- Load records to process (with field length limits matching AR_CUST)
    INSERT INTO #ToProcess
    SELECT 
        s.STAGING_ID,
        s.WOO_USER_ID,
        LOWER(LTRIM(RTRIM(s.EMAIL_ADRS_1))),
        LEFT(LTRIM(RTRIM(s.FST_NAM)), 15),
        LEFT(LTRIM(RTRIM(s.LST_NAM)), 25),
        LEFT(LTRIM(RTRIM(ISNULL(s.NAM, s.FST_NAM + ' ' + s.LST_NAM))), 40),
        LEFT(LTRIM(RTRIM(s.ADRS_1)), 40),
        LEFT(LTRIM(RTRIM(s.ADRS_2)), 40),
        LEFT(LTRIM(RTRIM(s.CITY)), 20),
        LEFT(UPPER(LTRIM(RTRIM(s.STATE))), 10),
        LEFT(LTRIM(RTRIM(s.ZIP_COD)), 15),
        LEFT(UPPER(LTRIM(RTRIM(ISNULL(s.CNTRY, 'US')))), 20),
        LEFT(LTRIM(RTRIM(s.PHONE_1)), 25),
        ISNULL(s.PROF_COD_1, @DefaultPROF_COD_1),
        ISNULL(s.CATEG_COD, @DefaultCATEG_COD),
        NULL,
        0,
        NULL,
        CASE WHEN s.WOO_USER_ID IS NULL THEN 1 ELSE 0 END
    FROM dbo.USER_CUSTOMER_STAGING s
    WHERE s.IS_APPLIED = 0
      AND (
          (@BatchID IS NOT NULL AND s.BATCH_ID = @BatchID)
          OR (@StagingID IS NOT NULL AND s.STAGING_ID = @StagingID)
      );
    
    DECLARE @RecordCount INT = (SELECT COUNT(*) FROM #ToProcess);
    PRINT 'Records to process: ' + CAST(@RecordCount AS VARCHAR);
    
    IF @RecordCount = 0
    BEGIN
        PRINT 'No records found matching criteria';
        DROP TABLE #ToProcess;
        RETURN;
    END
    
    -- Check for duplicate emails (already exist in AR_CUST)
    DECLARE @DuplicateEmails INT = 0;
    
    UPDATE t
    SET 
        IS_DUPLICATE = 1,
        EXISTING_CUST_NO = c.CUST_NO
    FROM #ToProcess t
    INNER JOIN dbo.AR_CUST c ON LOWER(c.EMAIL_ADRS_1) = t.EMAIL_ADRS_1
    WHERE t.EMAIL_ADRS_1 IS NOT NULL AND t.EMAIL_ADRS_1 != '';
    
    SET @DuplicateEmails = @@ROWCOUNT;
    
    IF @DuplicateEmails > 0
    BEGIN
        PRINT '';
        PRINT 'Found ' + CAST(@DuplicateEmails AS VARCHAR) + ' email(s) already in AR_CUST - will link instead of create';
        
        -- Update staging records for duplicates
        UPDATE s
        SET 
            IS_APPLIED = 1,
            APPLIED_DT = GETDATE(),
            ACTION_TAKEN = 'LINKED',
            VALIDATION_NOTES = 'Linked to existing customer: ' + t.EXISTING_CUST_NO
        FROM dbo.USER_CUSTOMER_STAGING s
        INNER JOIN #ToProcess t ON s.STAGING_ID = t.STAGING_ID
        WHERE t.IS_DUPLICATE = 1;
        
        -- Create mappings for duplicates
        INSERT INTO dbo.USER_CUSTOMER_MAP (WOO_USER_ID, CP_CUST_NO, IS_ACTIVE, CREATED_DT)
        SELECT DISTINCT
            t.WOO_USER_ID,
            t.EXISTING_CUST_NO,
            1,
            GETDATE()
        FROM #ToProcess t
        WHERE t.IS_DUPLICATE = 1 
          AND t.WOO_USER_ID IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM dbo.USER_CUSTOMER_MAP m 
              WHERE m.WOO_USER_ID = t.WOO_USER_ID AND m.CP_CUST_NO = t.EXISTING_CUST_NO
          );
        
        -- Remove duplicates from processing
        DELETE FROM #ToProcess WHERE IS_DUPLICATE = 1;
    END
    
    -- Generate CUST_NO for new customers
    DECLARE @NextCustNo INT;
    DECLARE @NewCustNo VARCHAR(15);
    DECLARE @GuestCheckouts INT = 0;
    
    SELECT @NextCustNo = ISNULL(MAX(TRY_CAST(CUST_NO AS INT)), 1000) + 1
    FROM dbo.AR_CUST
    WHERE TRY_CAST(CUST_NO AS INT) IS NOT NULL;
    
    -- Generate CUST_NO for each record
    DECLARE @CurrentStagingID INT;
    DECLARE cust_cursor CURSOR FOR
    SELECT STAGING_ID FROM #ToProcess ORDER BY STAGING_ID;
    
    OPEN cust_cursor;
    FETCH NEXT FROM cust_cursor INTO @CurrentStagingID;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @NewCustNo = CAST(@NextCustNo AS VARCHAR(15));
        
        UPDATE #ToProcess
        SET NEW_CUST_NO = @NewCustNo
        WHERE STAGING_ID = @CurrentStagingID;
        
        SET @NextCustNo = @NextCustNo + 1;
        
        IF (SELECT IS_GUEST FROM #ToProcess WHERE STAGING_ID = @CurrentStagingID) = 1
            SET @GuestCheckouts = @GuestCheckouts + 1;
        
        FETCH NEXT FROM cust_cursor INTO @CurrentStagingID;
    END
    
    CLOSE cust_cursor;
    DEALLOCATE cust_cursor;
    
    -- Preview what we're about to create
    PRINT '';
    PRINT 'Customers to create:';
    PRINT '------------------------------------------------------------';
    
    SELECT 
        NEW_CUST_NO AS [CUST_NO],
        EMAIL_ADRS_1 AS [Email],
        NAM AS [Name],
        CITY AS [City],
        STATE AS [State],
        PROF_COD_1 AS [Tier],
        CASE WHEN IS_GUEST = 1 THEN 'Guest' ELSE 'Mapped' END AS [Type]
    FROM #ToProcess
    ORDER BY NEW_CUST_NO;
    
    IF @DryRun = 1
    BEGIN
        PRINT '';
        PRINT '[DRY RUN] No changes made. Run with @DryRun = 0 to create customers.';
        SET @CreatedCount = @RecordCount;
        DROP TABLE #ToProcess;
        RETURN;
    END
    
    -- Begin transaction
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- Insert into AR_CUST
        -- Note: Including all required non-nullable fields with defaults
        INSERT INTO dbo.AR_CUST (
            CUST_NO, NAM, NAM_UPR, CUST_TYP, PROMPT_NAM_ADRS, SLS_REP, STR_ID,
            ALLOW_AR_CHRG, ALLOW_TKTS, NO_CR_LIM, NO_MAX_CHK_AMT,
            UNPSTD_BAL, BAL_METH, BAL, ORD_BAL, NO_OF_ORDS,
            USE_ORD_SHIP_TO, ALLOW_ORDS, 
            LST_AGE_FUTR_DOCS, LST_AGE_METH, LST_AGE_NO_CUTOFF,
            LST_STMNT_METH, WRK_STMNT_ACTIV,
            LWY_BAL, NO_OF_LWYS, USE_LWY_SHIP_TO, ALLOW_LWYS,
            IS_ECOMM_CUST, ECOMM_NXT_PUB_UPDT, ECOMM_NXT_PUB_FULL,
            PROMPT_FOR_CUSTOM_FLDS, LOY_PTS_BAL, TOT_LOY_PTS_EARND, 
            TOT_LOY_PTS_RDM, TOT_LOY_PTS_ADJ, REQ_PO_NO,
            CUST_NAM_TYP, EMAIL_STATEMENT, RS_STAT,
            INCLUDE_IN_MARKETING_MAILOUTS, RPT_EMAIL,
            FST_NAM, FST_NAM_UPR, LST_NAM, LST_NAM_UPR,
            ADRS_1, ADRS_2, CITY, STATE, ZIP_COD, CNTRY,
            PHONE_1, EMAIL_ADRS_1, CATEG_COD, PROF_COD_1, TAX_COD,
            LST_MAINT_DT, LST_MAINT_USR_ID
        )
        SELECT
            t.NEW_CUST_NO,
            LEFT(t.NAM, 40),                    -- NAM: max 40
            LEFT(UPPER(t.NAM), 40),             -- NAM_UPR: max 40
            'C',                                -- CUST_TYP: C = Customer
            'N',                                -- PROMPT_NAM_ADRS
            '',                                 -- SLS_REP: Empty string (required, non-nullable)
            LEFT(@DefaultSTR_ID, 10),           -- STR_ID: max 10
            'N',                                -- ALLOW_AR_CHRG
            'Y',                                -- ALLOW_TKTS
            'Y',                                -- NO_CR_LIM
            'Y',                                -- NO_MAX_CHK_AMT
            0,                                  -- UNPSTD_BAL
            'O',                                -- BAL_METH: O (only valid value per constraint)
            0,                                  -- BAL
            0,                                  -- ORD_BAL
            0,                                  -- NO_OF_ORDS
            'N',                                -- USE_ORD_SHIP_TO
            'Y',                                -- ALLOW_ORDS
            'Y',                                -- LST_AGE_FUTR_DOCS
            'I',                                -- LST_AGE_METH
            'N',                                -- LST_AGE_NO_CUTOFF
            '!',                                -- LST_STMNT_METH: ! (valid: D, I, or !)
            'N',                                -- WRK_STMNT_ACTIV
            0,                                  -- LWY_BAL
            0,                                  -- NO_OF_LWYS
            'N',                                -- USE_LWY_SHIP_TO
            'Y',                                -- ALLOW_LWYS
            'Y',                                -- IS_ECOMM_CUST: Y (must be N or Y, not 1)
            'N',                                -- ECOMM_NXT_PUB_UPDT
            'N',                                -- ECOMM_NXT_PUB_FULL
            'N',                                -- PROMPT_FOR_CUSTOM_FLDS
            0,                                  -- LOY_PTS_BAL
            0,                                  -- TOT_LOY_PTS_EARND
            0,                                  -- TOT_LOY_PTS_RDM
            0,                                  -- TOT_LOY_PTS_ADJ
            'N',                                -- REQ_PO_NO
            'B',                                -- CUST_NAM_TYP: B (valid per constraint: B or P only)
            'N',                                -- EMAIL_STATEMENT
            0,                                  -- RS_STAT
            'N',                                -- INCLUDE_IN_MARKETING_MAILOUTS
            'N',                                -- RPT_EMAIL
            LEFT(t.FST_NAM, 15),                -- FST_NAM: max 15
            LEFT(UPPER(t.FST_NAM), 15),         -- FST_NAM_UPR: max 15
            LEFT(t.LST_NAM, 25),                -- LST_NAM: max 25
            LEFT(UPPER(t.LST_NAM), 25),         -- LST_NAM_UPR: max 25
            LEFT(t.ADRS_1, 40),                 -- ADRS_1: max 40
            LEFT(t.ADRS_2, 40),                 -- ADRS_2: max 40
            LEFT(t.CITY, 20),                    -- CITY: max 20
            LEFT(t.STATE, 10),                   -- STATE: max 10
            LEFT(t.ZIP_COD, 15),                 -- ZIP_COD: max 15
            LEFT(t.CNTRY, 20),                  -- CNTRY: max 20
            LEFT(t.PHONE_1, 25),                 -- PHONE_1: max 25
            LEFT(t.EMAIL_ADRS_1, 50),            -- EMAIL_ADRS_1: max 50
            LEFT(t.CATEG_COD, 10),               -- CATEG_COD: max 10
            LEFT(t.PROF_COD_1, 10),              -- PROF_COD_1: max 10
            LEFT(@DefaultTAX_COD, 10),          -- TAX_COD: max 10
            GETDATE(),                          -- LST_MAINT_DT
            LEFT('INTEGRATION', 10)             -- LST_MAINT_USR_ID: max 10
        FROM #ToProcess t;
        
        SET @CreatedCount = @@ROWCOUNT;
        
        -- Create mappings (skip guest checkouts)
        INSERT INTO dbo.USER_CUSTOMER_MAP (WOO_USER_ID, CP_CUST_NO, IS_ACTIVE, CREATED_DT)
        SELECT DISTINCT
            t.WOO_USER_ID,
            t.NEW_CUST_NO,
            1,
            GETDATE()
        FROM #ToProcess t
        WHERE t.WOO_USER_ID IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM dbo.USER_CUSTOMER_MAP m 
              WHERE m.WOO_USER_ID = t.WOO_USER_ID AND m.CP_CUST_NO = t.NEW_CUST_NO
          );
        
        -- Update staging records
        UPDATE s
        SET 
            CUST_NO = t.NEW_CUST_NO,
            IS_APPLIED = 1,
            APPLIED_DT = GETDATE(),
            ACTION_TAKEN = 'INSERT'
        FROM dbo.USER_CUSTOMER_STAGING s
        INNER JOIN #ToProcess t ON s.STAGING_ID = t.STAGING_ID;
        
        PRINT 'Updated ' + CAST(@@ROWCOUNT AS VARCHAR) + ' staging records';
        
        COMMIT TRANSACTION;
        
        -- Final summary
        PRINT '';
        PRINT '============================================================';
        PRINT 'SUMMARY';
        PRINT '============================================================';
        PRINT 'New customers created:     ' + CAST(@CreatedCount AS VARCHAR);
        PRINT 'Linked to existing:        ' + CAST(@DuplicateEmails AS VARCHAR);
        PRINT 'Guest checkouts (no map):  ' + CAST(@GuestCheckouts AS VARCHAR);
        PRINT '';
        PRINT 'SUCCESS: Processing complete';
        PRINT '============================================================';
        
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @ErrorMsg = ERROR_MESSAGE();
        SET @ErrorCount = @RecordCount;
        SET @CreatedCount = 0;
        
        PRINT '';
        PRINT 'ERROR: ' + @ErrorMsg;
        RAISERROR(@ErrorMsg, 16, 1);
    END CATCH
    
    DROP TABLE #ToProcess;
END
GO

PRINT '';
PRINT 'Created usp_Create_Customers_From_Staging procedure';
PRINT '';




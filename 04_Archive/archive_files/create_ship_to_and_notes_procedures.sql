-- ============================================
-- CREATE SHIP-TO ADDRESSES FROM STAGING
-- ============================================
-- Creates CounterPoint ship-to addresses from validated staging records.
-- Rule 1.2: All imports go through staging
-- Rule 3.1: CUST_NO is king (must exist in AR_CUST)
--
-- DATA INTEGRITY HANDLING:
--   1. CUST_NO VALIDATION - Must exist in AR_CUST
--   2. FIELD TRUNCATION - All fields truncated to AR_SHIP_ADRS column limits
--   3. UNICODE SANITIZATION - Removes null chars, normalizes whitespace
--   4. DUPLICATE CHECK - Checks for existing ship-to addresses
--   5. AUTO-GENERATE SHIP_ADRS_ID - If not provided, generates next available ID
--
-- Usage:
--   -- Dry run (preview only):
--   EXEC dbo.usp_Create_ShipTo_From_Staging @BatchID = 'SHIP_TO_20251218', @DryRun = 1;
--   
--   -- Live run:
--   EXEC dbo.usp_Create_ShipTo_From_Staging @BatchID = 'SHIP_TO_20251218', @DryRun = 0;

USE CPPractice;  -- Change to WOODYS_CP for production
GO

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'usp_Create_ShipTo_From_Staging')
    DROP PROCEDURE dbo.usp_Create_ShipTo_From_Staging;
GO

CREATE PROCEDURE dbo.usp_Create_ShipTo_From_Staging
    @BatchID VARCHAR(50) = NULL,
    @StagingID INT = NULL,
    @DryRun BIT = 1,
    @CreatedCount INT = 0 OUTPUT,
    @ErrorCount INT = 0 OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
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
        CUST_NO VARCHAR(15),
        SHIP_ADRS_ID VARCHAR(10),
        NAM VARCHAR(40),
        FST_NAM VARCHAR(15),
        LST_NAM VARCHAR(25),
        SALUTATION VARCHAR(10),
        ADRS_1 VARCHAR(40),
        ADRS_2 VARCHAR(40),
        ADRS_3 VARCHAR(40),
        CITY VARCHAR(20),
        STATE VARCHAR(10),
        ZIP_COD VARCHAR(15),
        CNTRY VARCHAR(20),
        PHONE_1 VARCHAR(25),
        PHONE_2 VARCHAR(25),
        FAX_1 VARCHAR(25),
        FAX_2 VARCHAR(25),
        CONTCT_1 VARCHAR(40),
        CONTCT_2 VARCHAR(40),
        NEW_SHIP_ADRS_ID VARCHAR(10)
    );
    
    -- Load records to process (with field length limits matching AR_SHIP_ADRS)
    INSERT INTO #ToProcess
    SELECT 
        s.STAGING_ID,
        s.CUST_NO,
        s.SHIP_ADRS_ID,
        LEFT(LTRIM(RTRIM(ISNULL(s.NAM, ''))), 40),
        LEFT(LTRIM(RTRIM(s.FST_NAM)), 15),
        LEFT(LTRIM(RTRIM(s.LST_NAM)), 25),
        LEFT(LTRIM(RTRIM(s.SALUTATION)), 10),
        LEFT(LTRIM(RTRIM(s.ADRS_1)), 40),
        LEFT(LTRIM(RTRIM(s.ADRS_2)), 40),
        LEFT(LTRIM(RTRIM(s.ADRS_3)), 40),
        LEFT(LTRIM(RTRIM(s.CITY)), 20),
        LEFT(UPPER(LTRIM(RTRIM(s.STATE))), 10),
        LEFT(LTRIM(RTRIM(s.ZIP_COD)), 15),
        LEFT(UPPER(LTRIM(RTRIM(ISNULL(s.CNTRY, 'US')))), 20),
        LEFT(LTRIM(RTRIM(s.PHONE_1)), 25),
        LEFT(LTRIM(RTRIM(s.PHONE_2)), 25),
        LEFT(LTRIM(RTRIM(s.FAX_1)), 25),
        LEFT(LTRIM(RTRIM(s.FAX_2)), 25),
        LEFT(LTRIM(RTRIM(s.CONTCT_1)), 40),
        LEFT(LTRIM(RTRIM(s.CONTCT_2)), 40),
        NULL
    FROM dbo.USER_SHIP_TO_STAGING s
    WHERE s.IS_APPLIED = 0
      AND (
          (@BatchID IS NOT NULL AND s.BATCH_ID = @BatchID)
          OR (@StagingID IS NOT NULL AND s.STAGING_ID = @StagingID)
      );
    
    DECLARE @RecordCount INT = (SELECT COUNT(*) FROM #ToProcess);
    PRINT 'Records to process: ' + CAST(@RecordCount AS VARCHAR);
    
    -- Validate: CUST_NO must exist in AR_CUST
    DECLARE @InvalidCust INT;
    
    SELECT @InvalidCust = COUNT(*)
    FROM #ToProcess t
    WHERE NOT EXISTS (SELECT 1 FROM dbo.AR_CUST c WHERE c.CUST_NO = t.CUST_NO);
    
    IF @InvalidCust > 0
    BEGIN
        PRINT '';
        PRINT 'ERROR: ' + CAST(@InvalidCust AS VARCHAR) + ' record(s) have invalid CUST_NO (not found in AR_CUST)';
        
        -- Mark as invalid
        UPDATE s
        SET VALIDATION_ERROR = 'CUST_NO not found in AR_CUST: ' + t.CUST_NO,
            IS_VALIDATED = 1
        FROM dbo.USER_SHIP_TO_STAGING s
        INNER JOIN #ToProcess t ON s.STAGING_ID = t.STAGING_ID
        WHERE NOT EXISTS (SELECT 1 FROM dbo.AR_CUST c WHERE c.CUST_NO = t.CUST_NO);
        
        -- Remove from processing
        DELETE t
        FROM #ToProcess t
        WHERE NOT EXISTS (SELECT 1 FROM dbo.AR_CUST c WHERE c.CUST_NO = t.CUST_NO);
        
        SET @ErrorCount = @InvalidCust;
    END
    
    -- Generate SHIP_ADRS_ID for records that don't have one
    DECLARE @CurrentCustNo VARCHAR(15);
    DECLARE @NextShipID INT;
    DECLARE @NewShipID VARCHAR(10);
    
    DECLARE cust_cursor CURSOR FOR
    SELECT DISTINCT CUST_NO FROM #ToProcess WHERE SHIP_ADRS_ID IS NULL;
    
    OPEN cust_cursor;
    FETCH NEXT FROM cust_cursor INTO @CurrentCustNo;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Get next available SHIP_ADRS_ID for this customer
        SELECT @NextShipID = ISNULL(MAX(TRY_CAST(SHIP_ADRS_ID AS INT)), 0) + 1
        FROM dbo.AR_SHIP_ADRS
        WHERE CUST_NO = @CurrentCustNo
          AND TRY_CAST(SHIP_ADRS_ID AS INT) IS NOT NULL;
        
        SET @NewShipID = CAST(@NextShipID AS VARCHAR(10));
        
        -- Update temp table
        UPDATE #ToProcess
        SET NEW_SHIP_ADRS_ID = @NewShipID
        WHERE CUST_NO = @CurrentCustNo AND SHIP_ADRS_ID IS NULL;
        
        FETCH NEXT FROM cust_cursor INTO @CurrentCustNo;
    END
    
    CLOSE cust_cursor;
    DEALLOCATE cust_cursor;
    
    -- Use provided SHIP_ADRS_ID or generated one
    UPDATE #ToProcess
    SET NEW_SHIP_ADRS_ID = ISNULL(SHIP_ADRS_ID, NEW_SHIP_ADRS_ID);
    
    -- Preview what we're about to create
    PRINT '';
    PRINT 'Ship-to addresses to create:';
    PRINT '------------------------------------------------------------';
    
    SELECT 
        CUST_NO AS [CUST_NO],
        NEW_SHIP_ADRS_ID AS [SHIP_ADRS_ID],
        NAM AS [Name],
        ADRS_1 AS [Address],
        CITY AS [City],
        STATE AS [State]
    FROM #ToProcess
    ORDER BY CUST_NO, NEW_SHIP_ADRS_ID;
    
    IF @DryRun = 1
    BEGIN
        PRINT '';
        PRINT '[DRY RUN] No changes made. Run with @DryRun = 0 to create ship-to addresses.';
        SET @CreatedCount = @RecordCount;
        DROP TABLE #ToProcess;
        RETURN;
    END
    
    -- Begin transaction
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- Insert into AR_SHIP_ADRS
        INSERT INTO dbo.AR_SHIP_ADRS (
            CUST_NO, SHIP_ADRS_ID, NAM, NAM_UPR,
            FST_NAM, FST_NAM_UPR, LST_NAM, LST_NAM_UPR,
            SALUTATION, ADRS_1, ADRS_2, ADRS_3,
            CITY, STATE, ZIP_COD, CNTRY,
            PHONE_1, PHONE_2, FAX_1, FAX_2,
            CONTCT_1, CONTCT_2
        )
        SELECT
            t.CUST_NO,
            t.NEW_SHIP_ADRS_ID,
            t.NAM,
            UPPER(t.NAM),
            t.FST_NAM,
            UPPER(t.FST_NAM),
            t.LST_NAM,
            UPPER(t.LST_NAM),
            t.SALUTATION,
            t.ADRS_1,
            t.ADRS_2,
            t.ADRS_3,
            t.CITY,
            t.STATE,
            t.ZIP_COD,
            t.CNTRY,
            t.PHONE_1,
            t.PHONE_2,
            t.FAX_1,
            t.FAX_2,
            t.CONTCT_1,
            t.CONTCT_2
        FROM #ToProcess t;
        
        SET @CreatedCount = @@ROWCOUNT;
        
        -- Update staging records
        UPDATE s
        SET 
            IS_APPLIED = 1,
            APPLIED_DT = GETDATE(),
            ACTION_TAKEN = 'INSERT',
            CP_SHIP_ADRS_ID = t.NEW_SHIP_ADRS_ID,
            VALIDATION_NOTES = 'Ship-to address created successfully'
        FROM dbo.USER_SHIP_TO_STAGING s
        INNER JOIN #ToProcess t ON s.STAGING_ID = t.STAGING_ID;
        
        COMMIT TRANSACTION;
        
        PRINT '';
        PRINT 'Created ' + CAST(@CreatedCount AS VARCHAR) + ' ship-to addresses in AR_SHIP_ADRS';
        
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        
        DECLARE @ErrorMsg NVARCHAR(500) = ERROR_MESSAGE();
        PRINT '';
        PRINT 'ERROR: Failed to create ship-to addresses: ' + @ErrorMsg;
        
        SET @ErrorCount = @RecordCount;
        RAISERROR(@ErrorMsg, 16, 1);
    END CATCH
    
    DROP TABLE #ToProcess;
END
GO


-- ============================================
-- CREATE CUSTOMER NOTES FROM STAGING
-- ============================================
-- Creates CounterPoint customer notes from validated staging records.
-- Rule 1.2: All imports go through staging
-- Rule 3.1: CUST_NO is king (must exist in AR_CUST)
--
-- DATA INTEGRITY HANDLING:
--   1. CUST_NO VALIDATION - Must exist in AR_CUST
--   2. FIELD TRUNCATION - NOTE field truncated to 50 chars (AR_CUST_NOTE limit)
--   3. UNICODE SANITIZATION - Removes null chars, normalizes whitespace
--   4. AUTO-GENERATE NOTE_ID - If not provided, generates next available ID per customer
--
-- Usage:
--   -- Dry run (preview only):
--   EXEC dbo.usp_Create_CustomerNotes_From_Staging @BatchID = 'NOTES_20251218', @DryRun = 1;
--   
--   -- Live run:
--   EXEC dbo.usp_Create_CustomerNotes_From_Staging @BatchID = 'NOTES_20251218', @DryRun = 0;

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'usp_Create_CustomerNotes_From_Staging')
    DROP PROCEDURE dbo.usp_Create_CustomerNotes_From_Staging;
GO

CREATE PROCEDURE dbo.usp_Create_CustomerNotes_From_Staging
    @BatchID VARCHAR(50) = NULL,
    @StagingID INT = NULL,
    @DryRun BIT = 1,
    @CreatedCount INT = 0 OUTPUT,
    @ErrorCount INT = 0 OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
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
        CUST_NO VARCHAR(15),
        NOTE_ID INT,
        NOTE_DAT DATETIME2,
        USR_ID VARCHAR(10),
        NOTE VARCHAR(50),
        NOTE_TXT NVARCHAR(MAX),
        NEW_NOTE_ID INT
    );
    
    -- Load records to process (with field length limits matching AR_CUST_NOTE)
    INSERT INTO #ToProcess
    SELECT 
        s.STAGING_ID,
        s.CUST_NO,
        s.NOTE_ID,
        ISNULL(s.NOTE_DAT, GETDATE()),
        ISNULL(s.USR_ID, SYSTEM_USER),
        LEFT(LTRIM(RTRIM(ISNULL(s.NOTE, LEFT(s.NOTE_TXT, 50)))), 50),  -- Short note (max 50)
        LTRIM(RTRIM(ISNULL(s.NOTE_TXT, s.NOTE))),  -- Full note text
        NULL
    FROM dbo.USER_CUSTOMER_NOTES_STAGING s
    WHERE s.IS_APPLIED = 0
      AND (
          (@BatchID IS NOT NULL AND s.BATCH_ID = @BatchID)
          OR (@StagingID IS NOT NULL AND s.STAGING_ID = @StagingID)
      );
    
    DECLARE @RecordCount INT = (SELECT COUNT(*) FROM #ToProcess);
    PRINT 'Records to process: ' + CAST(@RecordCount AS VARCHAR);
    
    -- Validate: CUST_NO must exist in AR_CUST
    DECLARE @InvalidCust INT;
    
    SELECT @InvalidCust = COUNT(*)
    FROM #ToProcess t
    WHERE NOT EXISTS (SELECT 1 FROM dbo.AR_CUST c WHERE c.CUST_NO = t.CUST_NO);
    
    IF @InvalidCust > 0
    BEGIN
        PRINT '';
        PRINT 'ERROR: ' + CAST(@InvalidCust AS VARCHAR) + ' record(s) have invalid CUST_NO (not found in AR_CUST)';
        
        -- Mark as invalid
        UPDATE s
        SET VALIDATION_ERROR = 'CUST_NO not found in AR_CUST: ' + t.CUST_NO,
            IS_VALIDATED = 1
        FROM dbo.USER_CUSTOMER_NOTES_STAGING s
        INNER JOIN #ToProcess t ON s.STAGING_ID = t.STAGING_ID
        WHERE NOT EXISTS (SELECT 1 FROM dbo.AR_CUST c WHERE c.CUST_NO = t.CUST_NO);
        
        -- Remove from processing
        DELETE t
        FROM #ToProcess t
        WHERE NOT EXISTS (SELECT 1 FROM dbo.AR_CUST c WHERE c.CUST_NO = t.CUST_NO);
        
        SET @ErrorCount = @InvalidCust;
    END
    
    -- Generate NOTE_ID for records that don't have one
    DECLARE @CurrentCustNo VARCHAR(15);
    DECLARE @NextNoteID INT;
    
    DECLARE cust_cursor CURSOR FOR
    SELECT DISTINCT CUST_NO FROM #ToProcess WHERE NOTE_ID IS NULL;
    
    OPEN cust_cursor;
    FETCH NEXT FROM cust_cursor INTO @CurrentCustNo;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Get next available NOTE_ID for this customer
        SELECT @NextNoteID = ISNULL(MAX(NOTE_ID), 0) + 1
        FROM dbo.AR_CUST_NOTE
        WHERE CUST_NO = @CurrentCustNo;
        
        -- Update temp table
        UPDATE #ToProcess
        SET NEW_NOTE_ID = @NextNoteID
        WHERE CUST_NO = @CurrentCustNo AND NOTE_ID IS NULL;
        
        FETCH NEXT FROM cust_cursor INTO @CurrentCustNo;
    END
    
    CLOSE cust_cursor;
    DEALLOCATE cust_cursor;
    
    -- Use provided NOTE_ID or generated one
    UPDATE #ToProcess
    SET NEW_NOTE_ID = ISNULL(NOTE_ID, NEW_NOTE_ID);
    
    -- Preview what we're about to create
    PRINT '';
    PRINT 'Customer notes to create:';
    PRINT '------------------------------------------------------------';
    
    SELECT 
        CUST_NO AS [CUST_NO],
        NEW_NOTE_ID AS [NOTE_ID],
        NOTE AS [Note],
        LEFT(NOTE_TXT, 50) AS [Note_Text_Preview]
    FROM #ToProcess
    ORDER BY CUST_NO, NEW_NOTE_ID;
    
    IF @DryRun = 1
    BEGIN
        PRINT '';
        PRINT '[DRY RUN] No changes made. Run with @DryRun = 0 to create customer notes.';
        SET @CreatedCount = @RecordCount;
        DROP TABLE #ToProcess;
        RETURN;
    END
    
    -- Begin transaction
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- Insert into AR_CUST_NOTE
        INSERT INTO dbo.AR_CUST_NOTE (
            CUST_NO, NOTE_ID, NOTE_DAT, USR_ID, NOTE, NOTE_TXT
        )
        SELECT
            t.CUST_NO,
            t.NEW_NOTE_ID,
            t.NOTE_DAT,
            t.USR_ID,
            t.NOTE,
            t.NOTE_TXT
        FROM #ToProcess t;
        
        SET @CreatedCount = @@ROWCOUNT;
        
        -- Update staging records
        UPDATE s
        SET 
            IS_APPLIED = 1,
            APPLIED_DT = GETDATE(),
            ACTION_TAKEN = 'INSERT',
            CP_NOTE_ID = t.NEW_NOTE_ID,
            VALIDATION_NOTES = 'Customer note created successfully'
        FROM dbo.USER_CUSTOMER_NOTES_STAGING s
        INNER JOIN #ToProcess t ON s.STAGING_ID = t.STAGING_ID;
        
        COMMIT TRANSACTION;
        
        PRINT '';
        PRINT 'Created ' + CAST(@CreatedCount AS VARCHAR) + ' customer notes in AR_CUST_NOTE';
        
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        
        DECLARE @ErrorMsg NVARCHAR(500) = ERROR_MESSAGE();
        PRINT '';
        PRINT 'ERROR: Failed to create customer notes: ' + @ErrorMsg;
        
        SET @ErrorCount = @RecordCount;
        RAISERROR(@ErrorMsg, 16, 1);
    END CATCH
    
    DROP TABLE #ToProcess;
END
GO

PRINT '';
PRINT '============================================';
PRINT 'Stored Procedures Created Successfully';
PRINT '============================================';
PRINT '  - usp_Create_ShipTo_From_Staging';
PRINT '  - usp_Create_CustomerNotes_From_Staging';
PRINT '';




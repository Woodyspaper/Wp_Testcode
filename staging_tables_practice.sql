-- ============================================
-- Staging & Master Tables for CounterPoint Integration
-- Database: CPPractice on ADWPC-MAIN
-- ============================================
--
-- Rules Applied:
--   - Rule 1.2: All imports go through staging (USER_*_STAGING)
--   - Rule 1.3: Don't destroy vendor or manual data
--   - Rule 2.1: One master for contract rules (USER_CONTRACT_PRICE_MASTER)
--   - Rule 6.2: Log every sync (USER_SYNC_LOG)
--   - Rule 7.3: Document ownership
--
-- Key CounterPoint Tables Referenced:
--   - AR_CUST: Customer master (CUST_NO is primary key)
--   - IM_ITEM: Item master
--   - IM_PRC: Base prices
--   - IM_PRC_RUL: Pricing rules
--   - IM_PRC_RUL_BRK: Pricing rule breaks (quantity-based)
--
-- Workflow:
--   1. Data lands in USER_*_STAGING tables
--   2. Validation stored procedures check data
--   3. Master tables (USER_CONTRACT_PRICE_MASTER) hold business logic
--   4. usp_Rebuild_* procedures push to real CP tables
--
-- IMPORTANT: 
--   - Run on WOODYS_CP database
--   - Backup and test on dev instance first
--   - Only modifies USER_* tables (safe for CounterPoint)
-- ============================================

USE CPPractice;
GO

-- ============================================
-- 1. SYNC LOG TABLE
-- ============================================
-- Tracks all sync operations for audit trail
-- Rule 6.2: Log every sync

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'USER_SYNC_LOG')
BEGIN
    CREATE TABLE dbo.USER_SYNC_LOG (
        LOG_ID              INT IDENTITY(1,1) PRIMARY KEY,
        SYNC_ID             VARCHAR(50) NOT NULL,
        OPERATION_TYPE      VARCHAR(50) NOT NULL,      -- product_sync, customer_sync, contract_rebuild, etc.
        DIRECTION           VARCHAR(20) NOT NULL,      -- CP_TO_WOO, WOO_TO_CP, INTERNAL
        DRY_RUN             BIT DEFAULT 1,
        START_TIME          DATETIME2 NOT NULL,
        END_TIME            DATETIME2,
        DURATION_SECONDS    DECIMAL(10,2),
        RECORDS_INPUT       INT DEFAULT 0,
        RECORDS_CREATED     INT DEFAULT 0,
        RECORDS_UPDATED     INT DEFAULT 0,
        RECORDS_SKIPPED     INT DEFAULT 0,
        RECORDS_FAILED      INT DEFAULT 0,
        SUCCESS             BIT DEFAULT 0,
        ERROR_MESSAGE       NVARCHAR(MAX),
        CREATED_DT          DATETIME2 DEFAULT GETDATE(),
        CREATED_BY          VARCHAR(50) DEFAULT SYSTEM_USER
    );

    CREATE INDEX IX_USER_SYNC_LOG_SYNC_ID ON dbo.USER_SYNC_LOG(SYNC_ID);
    CREATE INDEX IX_USER_SYNC_LOG_OPERATION ON dbo.USER_SYNC_LOG(OPERATION_TYPE, START_TIME DESC);
    
    PRINT 'Created USER_SYNC_LOG table';
END
ELSE
    PRINT 'USER_SYNC_LOG already exists';
GO


-- ============================================
-- 2. CONTRACT PRICE MASTER TABLE
-- ============================================
-- THE source of truth for contract pricing rules managed by automation
-- Rule 2.1: One master for contract rules
-- This table feeds IM_PRC_RUL via stored procedures

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'USER_CONTRACT_PRICE_MASTER')
BEGIN
    CREATE TABLE dbo.USER_CONTRACT_PRICE_MASTER (
        CONTRACT_ID         INT IDENTITY(1,1) PRIMARY KEY,
        
        -- Customer targeting (one of these should be set)
        CUST_NO             VARCHAR(15) NULL,          -- Specific customer (FK to AR_CUST)
        CUST_GRP_COD        VARCHAR(10) NULL,          -- Customer group/category
        PRC_COD             VARCHAR(10) NULL,          -- Price code from AR_CUST.PRC_COD
        
        -- Item targeting (one of these should be set)
        ITEM_NO             VARCHAR(30) NULL,          -- Specific item (FK to IM_ITEM)
        ITEM_CATEG_COD      VARCHAR(10) NULL,          -- Item category
        ITEM_PROF_COD       VARCHAR(10) NULL,          -- Item profile code
        
        -- Pricing rule
        DESCR               VARCHAR(50),               -- Description for this rule
        PRC_METH            CHAR(1) NOT NULL,          -- D=Discount%, O=Override, M=Markup%, A=AmountOff
        PRC_BASIS           CHAR(1) DEFAULT '1',       -- 1=PRC_1, 2=PRC_2, 3=PRC_3, R=REG_PRC
        PRC_AMT             DECIMAL(15,4) NOT NULL,    -- The discount %, markup %, or fixed price
        
        -- Quantity breaks
        MIN_QTY             DECIMAL(15,4) DEFAULT 0,
        MAX_QTY             DECIMAL(15,4) NULL,
        
        -- Effective dates
        EFFECTIVE_FROM      DATE NULL,
        EFFECTIVE_TO        DATE NULL,
        
        -- Control flags
        IS_ACTIVE           BIT DEFAULT 1,
        PRIORITY            INT DEFAULT 100,           -- Lower = higher priority for overlapping rules
        
        -- Ownership & audit (Rule 1.3: Tag automated rows)
        OWNER_SYSTEM        VARCHAR(20) DEFAULT 'INTEGRATION',  -- INTEGRATION, MANUAL, VENDOR
        SOURCE_REF          VARCHAR(50) NULL,          -- External reference if imported
        
        -- Audit trail
        CREATED_DT          DATETIME2 DEFAULT GETDATE(),
        CREATED_BY          VARCHAR(50) DEFAULT SYSTEM_USER,
        UPDATED_DT          DATETIME2,
        UPDATED_BY          VARCHAR(50),
        
        -- Link to IM_PRC_RUL after rebuild
        APPLIED_RUL_SEQ_NO  INT NULL,                  -- IM_PRC_RUL.RUL_SEQ_NO after applied
        LAST_APPLIED_DT     DATETIME2 NULL,
        
        CONSTRAINT CK_CONTRACT_PRC_METH CHECK (PRC_METH IN ('D', 'O', 'M', 'A')),
        CONSTRAINT CK_CONTRACT_OWNER CHECK (OWNER_SYSTEM IN ('INTEGRATION', 'MANUAL', 'VENDOR'))
    );

    -- Indexes for common lookups
    CREATE INDEX IX_CONTRACT_MASTER_CUST ON dbo.USER_CONTRACT_PRICE_MASTER(CUST_NO) WHERE CUST_NO IS NOT NULL;
    CREATE INDEX IX_CONTRACT_MASTER_ITEM ON dbo.USER_CONTRACT_PRICE_MASTER(ITEM_NO) WHERE ITEM_NO IS NOT NULL;
    CREATE INDEX IX_CONTRACT_MASTER_PRC_COD ON dbo.USER_CONTRACT_PRICE_MASTER(PRC_COD) WHERE PRC_COD IS NOT NULL;
    CREATE INDEX IX_CONTRACT_MASTER_ACTIVE ON dbo.USER_CONTRACT_PRICE_MASTER(IS_ACTIVE, EFFECTIVE_FROM, EFFECTIVE_TO);
    
    PRINT 'Created USER_CONTRACT_PRICE_MASTER table';
END
ELSE
    PRINT 'USER_CONTRACT_PRICE_MASTER already exists';
GO


-- ============================================
-- 3. CONTRACT PRICE STAGING TABLE
-- ============================================
-- For importing contract pricing rules before applying to master
-- Rule 1.2: All imports go through staging

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'USER_CONTRACT_PRICE_STAGING')
BEGIN
    CREATE TABLE dbo.USER_CONTRACT_PRICE_STAGING (
        STAGING_ID          INT IDENTITY(1,1) PRIMARY KEY,
        BATCH_ID            VARCHAR(50) NOT NULL,       -- Groups related imports
        
        -- Same structure as master table
        CUST_NO             VARCHAR(15) NULL,
        CUST_GRP_COD        VARCHAR(10) NULL,
        PRC_COD             VARCHAR(10) NULL,
        ITEM_NO             VARCHAR(30) NULL,
        ITEM_CATEG_COD      VARCHAR(10) NULL,
        ITEM_PROF_COD       VARCHAR(10) NULL,
        
        DESCR               VARCHAR(50),
        PRC_METH            CHAR(1),
        PRC_BASIS           CHAR(1) DEFAULT '1',
        PRC_AMT             DECIMAL(15,4),
        MIN_QTY             DECIMAL(15,4) DEFAULT 0,
        MAX_QTY             DECIMAL(15,4),
        EFFECTIVE_FROM      DATE,
        EFFECTIVE_TO        DATE,
        PRIORITY            INT DEFAULT 100,
        
        -- Validation status
        IS_VALIDATED        BIT DEFAULT 0,
        VALIDATION_ERROR    NVARCHAR(500),
        IS_APPLIED          BIT DEFAULT 0,
        APPLIED_DT          DATETIME2,
        TARGET_CONTRACT_ID  INT NULL,                   -- USER_CONTRACT_PRICE_MASTER.CONTRACT_ID after merge
        ACTION_TAKEN        VARCHAR(10) NULL,           -- INSERT, UPDATE, SKIP
        
        -- Audit
        SOURCE_FILE         VARCHAR(255) NULL,
        SOURCE_SYSTEM       VARCHAR(50) DEFAULT 'IMPORT',
        CREATED_DT          DATETIME2 DEFAULT GETDATE(),
        CREATED_BY          VARCHAR(50) DEFAULT SYSTEM_USER
    );

    CREATE INDEX IX_CONTRACT_STAGING_BATCH ON dbo.USER_CONTRACT_PRICE_STAGING(BATCH_ID);
    CREATE INDEX IX_CONTRACT_STAGING_STATUS ON dbo.USER_CONTRACT_PRICE_STAGING(IS_VALIDATED, IS_APPLIED);
    
    PRINT 'Created USER_CONTRACT_PRICE_STAGING table';
END
ELSE
    PRINT 'USER_CONTRACT_PRICE_STAGING already exists';
GO


-- ============================================
-- 4. CUSTOMER STAGING TABLE
-- ============================================
-- For importing/updating customer data before applying to AR_CUST
-- Note: We typically don't write to AR_CUST directly from Woo,
--       but this supports customer data imports from other sources

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'USER_CUSTOMER_STAGING')
BEGIN
    CREATE TABLE dbo.USER_CUSTOMER_STAGING (
        STAGING_ID          INT IDENTITY(1,1) PRIMARY KEY,
        BATCH_ID            VARCHAR(50) NOT NULL,
        
        -- Customer identifiers
        CUST_NO             VARCHAR(15) NULL,           -- May be null for new customers
        EMAIL_ADRS_1        VARCHAR(100) NULL,
        WOO_USER_ID         INT NULL,
        
        -- Customer data (matching AR_CUST columns)
        NAM                 VARCHAR(40),
        FST_NAM             VARCHAR(15),
        LST_NAM             VARCHAR(20),
        PHONE_1             VARCHAR(25),
        ADRS_1              VARCHAR(40),
        ADRS_2              VARCHAR(40),
        CITY                VARCHAR(20),
        STATE               VARCHAR(3),
        ZIP_COD             VARCHAR(15),
        CNTRY               VARCHAR(3) DEFAULT 'US',
        
        -- Classification (matching AR_CUST columns)
        CUST_TYP            VARCHAR(10),
        CATEG_COD           VARCHAR(10),
        PRC_COD             VARCHAR(10),                -- Price code for contract pricing
        TERMS_COD           VARCHAR(10),
        TAX_COD             VARCHAR(10),
        STR_ID              VARCHAR(15),
        
        -- Flags
        IS_ECOMM_CUST       CHAR(1) DEFAULT 'Y',
        ALLOW_AR_CHRG       CHAR(1) DEFAULT 'N',
        
        -- Validation status
        IS_VALIDATED        BIT DEFAULT 0,
        VALIDATION_ERROR    NVARCHAR(500),
        IS_APPLIED          BIT DEFAULT 0,
        APPLIED_DT          DATETIME2,
        ACTION_TAKEN        VARCHAR(10) NULL,
        
        -- Audit
        SOURCE_SYSTEM       VARCHAR(50) DEFAULT 'WOOCOMMERCE',
        CREATED_DT          DATETIME2 DEFAULT GETDATE(),
        CREATED_BY          VARCHAR(50) DEFAULT SYSTEM_USER
    );

    CREATE INDEX IX_CUSTOMER_STAGING_BATCH ON dbo.USER_CUSTOMER_STAGING(BATCH_ID);
    CREATE INDEX IX_CUSTOMER_STAGING_CUST ON dbo.USER_CUSTOMER_STAGING(CUST_NO);
    CREATE INDEX IX_CUSTOMER_STAGING_STATUS ON dbo.USER_CUSTOMER_STAGING(IS_VALIDATED, IS_APPLIED);
    
    PRINT 'Created USER_CUSTOMER_STAGING table';
END
ELSE
    PRINT 'USER_CUSTOMER_STAGING already exists';
GO


-- ============================================
-- 5. CUSTOMER MAPPING TABLE
-- ============================================
-- Explicit mapping between WooCommerce users and CounterPoint customers
-- Rule 3.3: Keep mappings explicit
-- Rule 3.1: CUST_NO is king

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'USER_CUSTOMER_MAP')
BEGIN
    CREATE TABLE dbo.USER_CUSTOMER_MAP (
        MAP_ID              INT IDENTITY(1,1) PRIMARY KEY,
        CUST_NO             VARCHAR(15) NOT NULL,       -- AR_CUST.CUST_NO
        WOO_USER_ID         INT NOT NULL,               -- WordPress user ID
        WOO_EMAIL           VARCHAR(100) NULL,          -- For reference only (not for matching!)
        BOOKKEEPING_ID      VARCHAR(50) NULL,           -- External accounting system ID
        
        MAPPING_SOURCE      VARCHAR(20) DEFAULT 'AUTO', -- AUTO, MANUAL, IMPORT
        IS_ACTIVE           BIT DEFAULT 1,
        
        CREATED_DT          DATETIME2 DEFAULT GETDATE(),
        CREATED_BY          VARCHAR(50) DEFAULT SYSTEM_USER,
        UPDATED_DT          DATETIME2,
        UPDATED_BY          VARCHAR(50),
        NOTES               NVARCHAR(255)
    );

    -- Unique constraints: one active mapping per customer / per Woo user
    CREATE UNIQUE INDEX IX_CUSTOMER_MAP_CUST ON dbo.USER_CUSTOMER_MAP(CUST_NO) WHERE IS_ACTIVE = 1;
    CREATE UNIQUE INDEX IX_CUSTOMER_MAP_WOO ON dbo.USER_CUSTOMER_MAP(WOO_USER_ID) WHERE IS_ACTIVE = 1;
    
    PRINT 'Created USER_CUSTOMER_MAP table';
END
ELSE
    PRINT 'USER_CUSTOMER_MAP already exists';
GO


-- ============================================
-- 6. ORDER STAGING TABLE
-- ============================================
-- For importing WooCommerce orders before creating in PS_DOC_HDR
-- This is for Woo â†’ CP order flow

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'USER_ORDER_STAGING')
BEGIN
    CREATE TABLE dbo.USER_ORDER_STAGING (
        STAGING_ID          INT IDENTITY(1,1) PRIMARY KEY,
        BATCH_ID            VARCHAR(50) NOT NULL,
        
        -- WooCommerce identifiers
        WOO_ORDER_ID        INT NOT NULL,
        WOO_ORDER_NO        VARCHAR(50) NULL,
        
        -- Customer (Rule 3.1: Key on CUST_NO)
        CUST_NO             VARCHAR(15) NULL,           -- Resolved AR_CUST.CUST_NO
        CUST_EMAIL          VARCHAR(100) NULL,          -- For reference/fallback lookup
        
        -- Order header (matching PS_DOC_HDR patterns)
        ORD_DAT             DATE,
        ORD_STATUS          VARCHAR(20),
        PMT_METH            VARCHAR(50),
        SHIP_VIA            VARCHAR(100),
        
        -- Totals
        SUBTOT              DECIMAL(15,4),
        SHIP_AMT            DECIMAL(15,4),
        TAX_AMT             DECIMAL(15,4),
        DISC_AMT            DECIMAL(15,4),
        TOT_AMT             DECIMAL(15,4),
        
        -- Shipping address
        SHIP_NAM            VARCHAR(40),
        SHIP_ADRS_1         VARCHAR(40),
        SHIP_ADRS_2         VARCHAR(40),
        SHIP_CITY           VARCHAR(20),
        SHIP_STATE          VARCHAR(3),
        SHIP_ZIP_COD        VARCHAR(15),
        SHIP_CNTRY          VARCHAR(3),
        SHIP_PHONE          VARCHAR(25),
        
        -- Line items as JSON (will be parsed into PS_DOC_LIN)
        LINE_ITEMS_JSON     NVARCHAR(MAX),
        
        -- Validation status
        IS_VALIDATED        BIT DEFAULT 0,
        VALIDATION_ERROR    NVARCHAR(500),
        IS_APPLIED          BIT DEFAULT 0,
        APPLIED_DT          DATETIME2,
        CP_DOC_ID           VARCHAR(15) NULL,           -- PS_DOC_HDR.DOC_ID after creation
        
        -- Audit
        SOURCE_SYSTEM       VARCHAR(50) DEFAULT 'WOOCOMMERCE',
        CREATED_DT          DATETIME2 DEFAULT GETDATE(),
        CREATED_BY          VARCHAR(50) DEFAULT SYSTEM_USER
    );

    CREATE INDEX IX_ORDER_STAGING_BATCH ON dbo.USER_ORDER_STAGING(BATCH_ID);
    CREATE INDEX IX_ORDER_STAGING_WOO ON dbo.USER_ORDER_STAGING(WOO_ORDER_ID);
    CREATE INDEX IX_ORDER_STAGING_CUST ON dbo.USER_ORDER_STAGING(CUST_NO);
    CREATE INDEX IX_ORDER_STAGING_STATUS ON dbo.USER_ORDER_STAGING(IS_VALIDATED, IS_APPLIED);
    
    PRINT 'Created USER_ORDER_STAGING table';
END
ELSE
    PRINT 'USER_ORDER_STAGING already exists';
GO


-- ============================================
-- VALIDATION STORED PROCEDURE: Contract Staging
-- ============================================
-- Validates staging records before merge to master
-- Rule 2.3: Validate before apply

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'usp_Validate_ContractPricing_Staging')
    DROP PROCEDURE dbo.usp_Validate_ContractPricing_Staging;
GO

CREATE PROCEDURE dbo.usp_Validate_ContractPricing_Staging
    @BatchID VARCHAR(50),
    @ValidCount INT OUTPUT,
    @InvalidCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Clear previous validation errors for this batch
    UPDATE dbo.USER_CONTRACT_PRICE_STAGING
    SET IS_VALIDATED = 0, VALIDATION_ERROR = NULL
    WHERE BATCH_ID = @BatchID AND IS_APPLIED = 0;
    
    -- Validate: Discount range (0-90%)
    UPDATE dbo.USER_CONTRACT_PRICE_STAGING
    SET VALIDATION_ERROR = 'Discount percentage out of range (must be 0-90%)'
    WHERE BATCH_ID = @BatchID
      AND IS_APPLIED = 0
      AND PRC_METH = 'D'
      AND (PRC_AMT < 0 OR PRC_AMT > 90);
    
    -- Validate: Date range
    UPDATE dbo.USER_CONTRACT_PRICE_STAGING
    SET VALIDATION_ERROR = 'Begin date is after end date'
    WHERE BATCH_ID = @BatchID
      AND IS_APPLIED = 0
      AND VALIDATION_ERROR IS NULL
      AND EFFECTIVE_FROM IS NOT NULL
      AND EFFECTIVE_TO IS NOT NULL
      AND EFFECTIVE_FROM > EFFECTIVE_TO;
    
    -- Validate: Customer exists in AR_CUST (if specified)
    UPDATE s
    SET VALIDATION_ERROR = 'Customer not found in AR_CUST: ' + s.CUST_NO
    FROM dbo.USER_CONTRACT_PRICE_STAGING s
    WHERE s.BATCH_ID = @BatchID
      AND s.IS_APPLIED = 0
      AND s.VALIDATION_ERROR IS NULL
      AND s.CUST_NO IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM dbo.AR_CUST c WHERE c.CUST_NO = s.CUST_NO);
    
    -- Validate: Item exists in IM_ITEM (if specified)
    UPDATE s
    SET VALIDATION_ERROR = 'Item not found in IM_ITEM: ' + s.ITEM_NO
    FROM dbo.USER_CONTRACT_PRICE_STAGING s
    WHERE s.BATCH_ID = @BatchID
      AND s.IS_APPLIED = 0
      AND s.VALIDATION_ERROR IS NULL
      AND s.ITEM_NO IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM dbo.IM_ITEM i WHERE i.ITEM_NO = s.ITEM_NO);
    
    -- Validate: Price code exists (if specified)
    -- TODO: Confirm price code table name - using IM_PRC_COD
    UPDATE s
    SET VALIDATION_ERROR = 'Price code not found: ' + s.PRC_COD
    FROM dbo.USER_CONTRACT_PRICE_STAGING s
    WHERE s.BATCH_ID = @BatchID
      AND s.IS_APPLIED = 0
      AND s.VALIDATION_ERROR IS NULL
      AND s.PRC_COD IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM dbo.IM_PRC_COD p WHERE p.PRC_COD = s.PRC_COD);
    
    -- Validate: Must have at least one target
    UPDATE dbo.USER_CONTRACT_PRICE_STAGING
    SET VALIDATION_ERROR = 'Rule must target customer, price code, item, or category'
    WHERE BATCH_ID = @BatchID
      AND IS_APPLIED = 0
      AND VALIDATION_ERROR IS NULL
      AND CUST_NO IS NULL
      AND CUST_GRP_COD IS NULL
      AND PRC_COD IS NULL
      AND ITEM_NO IS NULL
      AND ITEM_CATEG_COD IS NULL
      AND ITEM_PROF_COD IS NULL;
    
    -- Validate: PRC_METH is valid
    UPDATE dbo.USER_CONTRACT_PRICE_STAGING
    SET VALIDATION_ERROR = 'Invalid PRC_METH (must be D, O, M, or A)'
    WHERE BATCH_ID = @BatchID
      AND IS_APPLIED = 0
      AND VALIDATION_ERROR IS NULL
      AND PRC_METH NOT IN ('D', 'O', 'M', 'A');
    
    -- Mark validated records
    UPDATE dbo.USER_CONTRACT_PRICE_STAGING
    SET IS_VALIDATED = 1
    WHERE BATCH_ID = @BatchID
      AND IS_APPLIED = 0
      AND VALIDATION_ERROR IS NULL;
    
    -- Set output counts
    SELECT @ValidCount = COUNT(*) FROM dbo.USER_CONTRACT_PRICE_STAGING
    WHERE BATCH_ID = @BatchID AND IS_VALIDATED = 1 AND IS_APPLIED = 0;
    
    SELECT @InvalidCount = COUNT(*) FROM dbo.USER_CONTRACT_PRICE_STAGING
    WHERE BATCH_ID = @BatchID AND VALIDATION_ERROR IS NOT NULL AND IS_APPLIED = 0;
    
    -- Return summary
    SELECT 
        @ValidCount AS ValidRecords,
        @InvalidCount AS InvalidRecords,
        @ValidCount + @InvalidCount AS TotalRecords;
    
    -- Return errors for review
    IF @InvalidCount > 0
    BEGIN
        SELECT STAGING_ID, CUST_NO, PRC_COD, ITEM_NO, PRC_METH, PRC_AMT, VALIDATION_ERROR
        FROM dbo.USER_CONTRACT_PRICE_STAGING
        WHERE BATCH_ID = @BatchID
          AND VALIDATION_ERROR IS NOT NULL
        ORDER BY STAGING_ID;
    END
END
GO

PRINT 'Created usp_Validate_ContractPricing_Staging procedure';


-- ============================================
-- MERGE STORED PROCEDURE: Staging â†’ Master
-- ============================================
-- Merges validated staging records into master table

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'usp_Merge_ContractPricing_StagingToMaster')
    DROP PROCEDURE dbo.usp_Merge_ContractPricing_StagingToMaster;
GO

CREATE PROCEDURE dbo.usp_Merge_ContractPricing_StagingToMaster
    @BatchID VARCHAR(50),
    @InsertCount INT OUTPUT,
    @UpdateCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRANSACTION;
    
    BEGIN TRY
        DECLARE @MergeOutput TABLE (
            ACTION_TYPE VARCHAR(10),
            CONTRACT_ID INT
        );
        
        -- MERGE validated staging records into master
        MERGE dbo.USER_CONTRACT_PRICE_MASTER AS target
        USING (
            SELECT 
                CUST_NO, CUST_GRP_COD, PRC_COD,
                ITEM_NO, ITEM_CATEG_COD, ITEM_PROF_COD,
                DESCR, PRC_METH, PRC_BASIS, PRC_AMT,
                MIN_QTY, MAX_QTY,
                EFFECTIVE_FROM, EFFECTIVE_TO,
                PRIORITY, STAGING_ID
            FROM dbo.USER_CONTRACT_PRICE_STAGING
            WHERE BATCH_ID = @BatchID
              AND IS_VALIDATED = 1
              AND IS_APPLIED = 0
        ) AS source
        ON (
            -- Match on customer + item + price code combination
            ISNULL(target.CUST_NO, '') = ISNULL(source.CUST_NO, '')
            AND ISNULL(target.ITEM_NO, '') = ISNULL(source.ITEM_NO, '')
            AND ISNULL(target.PRC_COD, '') = ISNULL(source.PRC_COD, '')
            AND ISNULL(target.CUST_GRP_COD, '') = ISNULL(source.CUST_GRP_COD, '')
            AND target.OWNER_SYSTEM = 'INTEGRATION'  -- Only touch our rows!
        )
        WHEN MATCHED THEN
            UPDATE SET
                ITEM_CATEG_COD = source.ITEM_CATEG_COD,
                ITEM_PROF_COD = source.ITEM_PROF_COD,
                DESCR = source.DESCR,
                PRC_METH = source.PRC_METH,
                PRC_BASIS = source.PRC_BASIS,
                PRC_AMT = source.PRC_AMT,
                MIN_QTY = source.MIN_QTY,
                MAX_QTY = source.MAX_QTY,
                EFFECTIVE_FROM = source.EFFECTIVE_FROM,
                EFFECTIVE_TO = source.EFFECTIVE_TO,
                PRIORITY = source.PRIORITY,
                UPDATED_DT = GETDATE(),
                UPDATED_BY = SYSTEM_USER
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (
                CUST_NO, CUST_GRP_COD, PRC_COD,
                ITEM_NO, ITEM_CATEG_COD, ITEM_PROF_COD,
                DESCR, PRC_METH, PRC_BASIS, PRC_AMT,
                MIN_QTY, MAX_QTY,
                EFFECTIVE_FROM, EFFECTIVE_TO,
                PRIORITY, OWNER_SYSTEM
            )
            VALUES (
                source.CUST_NO, source.CUST_GRP_COD, source.PRC_COD,
                source.ITEM_NO, source.ITEM_CATEG_COD, source.ITEM_PROF_COD,
                source.DESCR, source.PRC_METH, source.PRC_BASIS, source.PRC_AMT,
                source.MIN_QTY, source.MAX_QTY,
                source.EFFECTIVE_FROM, source.EFFECTIVE_TO,
                source.PRIORITY, 'INTEGRATION'
            )
        OUTPUT $action, INSERTED.CONTRACT_ID INTO @MergeOutput;
        
        -- Count actions
        SELECT @InsertCount = COUNT(*) FROM @MergeOutput WHERE ACTION_TYPE = 'INSERT';
        SELECT @UpdateCount = COUNT(*) FROM @MergeOutput WHERE ACTION_TYPE = 'UPDATE';
        
        -- Mark staging records as applied
        UPDATE dbo.USER_CONTRACT_PRICE_STAGING
        SET IS_APPLIED = 1,
            APPLIED_DT = GETDATE(),
            ACTION_TAKEN = CASE 
                WHEN EXISTS (SELECT 1 FROM @MergeOutput WHERE ACTION_TYPE = 'INSERT') THEN 'INSERT'
                ELSE 'UPDATE'
            END
        WHERE BATCH_ID = @BatchID
          AND IS_VALIDATED = 1
          AND IS_APPLIED = 0;
        
        COMMIT TRANSACTION;
        
        -- Return summary
        SELECT 
            @InsertCount AS Inserted,
            @UpdateCount AS Updated,
            @InsertCount + @UpdateCount AS TotalMerged;
            
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END
GO

PRINT 'Created usp_Merge_ContractPricing_StagingToMaster procedure';


-- ============================================
-- REBUILD STORED PROCEDURE: Master â†’ IM_PRC_RUL
-- ============================================
-- Rebuilds IM_PRC_RUL from our master table
-- Rule 1.3: Only touches rows we own (specific GRP_TYP or flag)

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
    IMPORTANT: This procedure modifies IM_PRC_RUL!
    
    Safety measures:
      1. Only deletes rules with specific ownership markers
      2. Uses transaction for atomicity
      3. DryRun mode by default
      
    TODO: Confirm the exact columns in IM_PRC_RUL for your CounterPoint version:
      - RUL_SEQ_NO (identity/sequence)
      - DESCR (description)
      - PRC_COD (price code)
      - CUST_NO (customer number)
      - ITEM_NO (item number)
      - CATEG_COD (category code)
      - PRC_METH (pricing method)
      - PRC_BASIS (price basis)
      - PRC_AMT (price/discount amount)
      - MIN_QTY, MAX_QTY (quantity breaks)
      - BEG_DAT, END_DAT (effective dates)
      
    We use DESCR starting with '[AUTO]' as our ownership marker.
    */
    
    DECLARE @OwnershipMarker VARCHAR(10) = '[AUTO] ';
    
    IF @DryRun = 1
    BEGIN
        -- DRY RUN: Show what would happen
        PRINT 'DRY RUN MODE - No changes will be made';
        
        -- Count rules that would be deleted
        SELECT @DeletedCount = COUNT(*)
        FROM dbo.IM_PRC_RUL
        WHERE DESCR LIKE @OwnershipMarker + '%';
        
        PRINT 'Would delete ' + CAST(@DeletedCount AS VARCHAR) + ' existing automation-owned rules';
        
        -- Count rules that would be inserted
        SELECT @InsertedCount = COUNT(*)
        FROM dbo.USER_CONTRACT_PRICE_MASTER
        WHERE IS_ACTIVE = 1
          AND OWNER_SYSTEM = 'INTEGRATION'
          AND (EFFECTIVE_FROM IS NULL OR EFFECTIVE_FROM <= GETDATE())
          AND (EFFECTIVE_TO IS NULL OR EFFECTIVE_TO >= GETDATE());
        
        PRINT 'Would insert ' + CAST(@InsertedCount AS VARCHAR) + ' rules from master';
        
        -- Preview what would be inserted
        SELECT TOP 10
            @OwnershipMarker + ISNULL(m.DESCR, 'Contract Price') AS DESCR,
            m.PRC_COD,
            m.CUST_NO,
            m.ITEM_NO,
            m.ITEM_CATEG_COD AS CATEG_COD,
            m.PRC_METH,
            m.PRC_BASIS,
            m.PRC_AMT,
            m.MIN_QTY,
            m.MAX_QTY,
            m.EFFECTIVE_FROM AS BEG_DAT,
            m.EFFECTIVE_TO AS END_DAT
        FROM dbo.USER_CONTRACT_PRICE_MASTER m
        WHERE m.IS_ACTIVE = 1
          AND m.OWNER_SYSTEM = 'INTEGRATION'
          AND (m.EFFECTIVE_FROM IS NULL OR m.EFFECTIVE_FROM <= GETDATE())
          AND (m.EFFECTIVE_TO IS NULL OR m.EFFECTIVE_TO >= GETDATE())
        ORDER BY m.PRIORITY, m.CONTRACT_ID;
        
        RETURN;
    END
    
    -- LIVE MODE
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- Step 1: Delete existing automation-owned rules
        DELETE FROM dbo.IM_PRC_RUL
        WHERE DESCR LIKE @OwnershipMarker + '%';
        
        SET @DeletedCount = @@ROWCOUNT;
        
        -- Step 2: Insert from master table
        INSERT INTO dbo.IM_PRC_RUL (
            DESCR,
            PRC_COD,
            CUST_NO,
            ITEM_NO,
            CATEG_COD,
            PRC_METH,
            PRC_BASIS,
            PRC_AMT,
            MIN_QTY,
            MAX_QTY,
            BEG_DAT,
            END_DAT
            -- TODO: Add other required columns based on your IM_PRC_RUL schema
        )
        SELECT
            @OwnershipMarker + ISNULL(m.DESCR, 'Contract Price'),
            m.PRC_COD,
            m.CUST_NO,
            m.ITEM_NO,
            m.ITEM_CATEG_COD,
            m.PRC_METH,
            m.PRC_BASIS,
            m.PRC_AMT,
            m.MIN_QTY,
            m.MAX_QTY,
            m.EFFECTIVE_FROM,
            m.EFFECTIVE_TO
        FROM dbo.USER_CONTRACT_PRICE_MASTER m
        WHERE m.IS_ACTIVE = 1
          AND m.OWNER_SYSTEM = 'INTEGRATION'
          AND (m.EFFECTIVE_FROM IS NULL OR m.EFFECTIVE_FROM <= GETDATE())
          AND (m.EFFECTIVE_TO IS NULL OR m.EFFECTIVE_TO >= GETDATE());
        
        SET @InsertedCount = @@ROWCOUNT;
        
        -- Step 3: Update master with applied info
        UPDATE dbo.USER_CONTRACT_PRICE_MASTER
        SET LAST_APPLIED_DT = GETDATE()
        WHERE IS_ACTIVE = 1
          AND OWNER_SYSTEM = 'INTEGRATION'
          AND (EFFECTIVE_FROM IS NULL OR EFFECTIVE_FROM <= GETDATE())
          AND (EFFECTIVE_TO IS NULL OR EFFECTIVE_TO >= GETDATE());
        
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
        
        PRINT 'Rebuild complete: Deleted ' + CAST(@DeletedCount AS VARCHAR) + 
              ', Inserted ' + CAST(@InsertedCount AS VARCHAR);
              
    END TRY
    BEGIN CATCH
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

PRINT 'Created usp_Rebuild_ContractPricing_FromMaster procedure';


-- ============================================
-- EXPORT VIEW: Contract Prices for WooCommerce
-- ============================================
-- Provides contract prices in a format ready for Woo sync

IF EXISTS (SELECT * FROM sys.views WHERE name = 'VI_EXPORT_CONTRACT_PRICES')
    DROP VIEW dbo.VI_EXPORT_CONTRACT_PRICES;
GO

CREATE VIEW dbo.VI_EXPORT_CONTRACT_PRICES
AS
SELECT
    m.CONTRACT_ID,
    m.CUST_NO,
    c.NAM AS CUST_NAME,
    c.PRC_COD AS CUST_PRC_COD,
    m.PRC_COD AS RULE_PRC_COD,
    m.ITEM_NO,
    i.DESCR AS ITEM_DESCR,
    p.PRC_1 AS BASE_PRICE,
    m.PRC_METH,
    m.PRC_AMT,
    -- Calculate effective price
    CASE 
        WHEN m.PRC_METH = 'D' THEN p.PRC_1 * (1 - m.PRC_AMT / 100)  -- Discount %
        WHEN m.PRC_METH = 'O' THEN m.PRC_AMT                        -- Override
        WHEN m.PRC_METH = 'M' THEN p.PRC_1 * (1 + m.PRC_AMT / 100)  -- Markup %
        WHEN m.PRC_METH = 'A' THEN p.PRC_1 - m.PRC_AMT              -- Amount off
        ELSE p.PRC_1
    END AS CONTRACT_PRICE,
    m.MIN_QTY,
    m.MAX_QTY,
    m.EFFECTIVE_FROM,
    m.EFFECTIVE_TO,
    m.PRIORITY,
    m.DESCR AS RULE_DESCR
FROM dbo.USER_CONTRACT_PRICE_MASTER m
LEFT JOIN dbo.AR_CUST c ON c.CUST_NO = m.CUST_NO
LEFT JOIN dbo.IM_ITEM i ON i.ITEM_NO = m.ITEM_NO
LEFT JOIN dbo.IM_PRC p ON p.ITEM_NO = m.ITEM_NO
WHERE m.IS_ACTIVE = 1
  AND (m.EFFECTIVE_FROM IS NULL OR m.EFFECTIVE_FROM <= GETDATE())
  AND (m.EFFECTIVE_TO IS NULL OR m.EFFECTIVE_TO >= GETDATE());
GO

PRINT 'Created VI_EXPORT_CONTRACT_PRICES view';


-- ============================================
-- EXPORT VIEW: Customers for WooCommerce
-- ============================================

IF EXISTS (SELECT * FROM sys.views WHERE name = 'VI_EXPORT_ECOMM_CUSTOMERS')
    DROP VIEW dbo.VI_EXPORT_ECOMM_CUSTOMERS;
GO

CREATE VIEW dbo.VI_EXPORT_ECOMM_CUSTOMERS
AS
SELECT
    c.CUST_NO,
    c.NAM,
    c.FST_NAM,
    c.LST_NAM,
    c.EMAIL_ADRS_1,
    c.PHONE_1,
    c.ADRS_1,
    c.ADRS_2,
    c.CITY,
    c.STATE,
    c.ZIP_COD,
    c.CNTRY,
    c.CUST_TYP,
    c.CATEG_COD,
    c.PRC_COD,
    c.TERMS_COD,
    c.TAX_COD,
    c.ALLOW_AR_CHRG,
    c.LST_SAL_DAT,
    c.LST_MAINT_DT,
    m.WOO_USER_ID,
    m.BOOKKEEPING_ID
FROM dbo.AR_CUST c
LEFT JOIN dbo.USER_CUSTOMER_MAP m ON m.CUST_NO = c.CUST_NO AND m.IS_ACTIVE = 1
WHERE c.IS_ECOMM_CUST = 'Y';
GO

PRINT 'Created VI_EXPORT_ECOMM_CUSTOMERS view';


-- ============================================
-- CLEANUP PROCEDURE
-- ============================================

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'usp_Cleanup_StagingTables')
    DROP PROCEDURE dbo.usp_Cleanup_StagingTables;
GO

CREATE PROCEDURE dbo.usp_Cleanup_StagingTables
    @DaysToKeep INT = 30
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CutoffDate DATETIME2 = DATEADD(DAY, -@DaysToKeep, GETDATE());
    DECLARE @Deleted INT;
    
    -- Cleanup applied contract staging
    DELETE FROM dbo.USER_CONTRACT_PRICE_STAGING
    WHERE IS_APPLIED = 1 AND APPLIED_DT < @CutoffDate;
    SET @Deleted = @@ROWCOUNT;
    PRINT 'Deleted ' + CAST(@Deleted AS VARCHAR) + ' old contract staging records';
    
    -- Cleanup applied customer staging
    DELETE FROM dbo.USER_CUSTOMER_STAGING
    WHERE IS_APPLIED = 1 AND APPLIED_DT < @CutoffDate;
    SET @Deleted = @@ROWCOUNT;
    PRINT 'Deleted ' + CAST(@Deleted AS VARCHAR) + ' old customer staging records';
    
    -- Cleanup applied order staging
    DELETE FROM dbo.USER_ORDER_STAGING
    WHERE IS_APPLIED = 1 AND APPLIED_DT < @CutoffDate;
    SET @Deleted = @@ROWCOUNT;
    PRINT 'Deleted ' + CAST(@Deleted AS VARCHAR) + ' old order staging records';
    
    -- Cleanup old sync logs
    DELETE FROM dbo.USER_SYNC_LOG
    WHERE CREATED_DT < @CutoffDate;
    SET @Deleted = @@ROWCOUNT;
    PRINT 'Deleted ' + CAST(@Deleted AS VARCHAR) + ' old sync log records';
END
GO

PRINT 'Created usp_Cleanup_StagingTables procedure';


-- ============================================
-- SQL AGENT JOB TEMPLATE
-- ============================================
-- Example job steps for automating the contract pricing rebuild

/*
-- Run this in MSDB to create the job (adjust schedule as needed):

USE msdb;
GO

EXEC dbo.sp_add_job
    @job_name = N'WP_Rebuild_ContractPricing',
    @enabled = 1,
    @description = N'Rebuilds contract pricing rules from USER_CONTRACT_PRICE_MASTER to IM_PRC_RUL';

EXEC dbo.sp_add_jobstep
    @job_name = N'WP_Rebuild_ContractPricing',
    @step_name = N'Rebuild Pricing Rules',
    @subsystem = N'TSQL',
    @command = N'
        DECLARE @Del INT, @Ins INT;
        EXEC dbo.usp_Rebuild_ContractPricing_FromMaster 
            @DryRun = 0, 
            @DeletedCount = @Del OUTPUT, 
            @InsertedCount = @Ins OUTPUT;
    ',
    @database_name = N'WOODYS_CP';

EXEC dbo.sp_add_schedule
    @schedule_name = N'Daily_6AM',
    @freq_type = 4,  -- Daily
    @freq_interval = 1,
    @active_start_time = 060000;

EXEC dbo.sp_attach_schedule
    @job_name = N'WP_Rebuild_ContractPricing',
    @schedule_name = N'Daily_6AM';

EXEC dbo.sp_add_jobserver
    @job_name = N'WP_Rebuild_ContractPricing',
    @server_name = N'(LOCAL)';
*/


-- ============================================
-- SUMMARY
-- ============================================

PRINT '';
PRINT '============================================';
PRINT 'CounterPoint Integration Tables Setup Complete';
PRINT 'Database: CPPractice';
PRINT '============================================';
PRINT '';
PRINT 'Tables Created:';
PRINT '  - USER_SYNC_LOG                  (sync audit trail)';
PRINT '  - USER_CONTRACT_PRICE_MASTER     (contract pricing source of truth)';
PRINT '  - USER_CONTRACT_PRICE_STAGING    (contract pricing imports)';
PRINT '  - USER_CUSTOMER_STAGING          (customer imports)';
PRINT '  - USER_CUSTOMER_MAP              (CP <-> Woo customer mapping)';
PRINT '  - USER_ORDER_STAGING             (order imports)';
PRINT '';
PRINT 'Views Created:';
PRINT '  - VI_EXPORT_CONTRACT_PRICES      (for Woo sync)';
PRINT '  - VI_EXPORT_ECOMM_CUSTOMERS      (for Woo sync)';
PRINT '';
PRINT 'Procedures Created:';
PRINT '  - usp_Validate_ContractPricing_Staging';
PRINT '  - usp_Merge_ContractPricing_StagingToMaster';
PRINT '  - usp_Rebuild_ContractPricing_FromMaster';
PRINT '  - usp_Cleanup_StagingTables';
PRINT '';
PRINT 'Next Steps:';
PRINT '  1. Review and test on dev database first';
PRINT '  2. Confirm IM_PRC_RUL column names match your CP version';
PRINT '  3. Set up SQL Agent job for scheduled rebuilds';
PRINT '  4. Configure Python integration scripts';
PRINT '';
GO

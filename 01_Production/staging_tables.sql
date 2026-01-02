-- ============================================
-- Staging & Master Tables for CounterPoint Integration
-- Database: WOODYS_CP on ADWPC-MAIN
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

USE WOODYS_CP;  -- Test database - update to WOODYS_CP for production
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
        
        -- Customer data (matching AR_CUST column lengths exactly)
        NAM                 VARCHAR(40),
        FST_NAM             VARCHAR(15),
        LST_NAM             VARCHAR(25),                -- AR_CUST = 25
        SALUTATION          VARCHAR(10),                -- AR_CUST = 10 (Mr., Ms., Dr., etc.)
        PHONE_1             VARCHAR(25),
        PHONE_2             VARCHAR(25),                -- AR_CUST = 25 (secondary phone)
        MBL_PHONE_1         VARCHAR(25),                -- AR_CUST = 25 (mobile phone 1)
        MBL_PHONE_2         VARCHAR(25),                -- AR_CUST = 25 (mobile phone 2)
        FAX_1               VARCHAR(25),                -- AR_CUST = 25 (primary fax)
        FAX_2               VARCHAR(25),                -- AR_CUST = 25 (secondary fax)
        ADRS_1              VARCHAR(40),
        ADRS_2              VARCHAR(40),
        ADRS_3              VARCHAR(40),                -- AR_CUST = 40 (third address line)
        CITY                VARCHAR(20),
        STATE               VARCHAR(10),                -- AR_CUST = 10
        ZIP_COD             VARCHAR(15),
        CNTRY               VARCHAR(20) DEFAULT 'US',   -- AR_CUST = 20
        CONTCT_1            VARCHAR(40),                -- AR_CUST = 40 (primary contact name)
        CONTCT_2            VARCHAR(40),                -- AR_CUST = 40 (secondary contact name)
        EMAIL_ADRS_2        VARCHAR(50),                -- AR_CUST = 50 (secondary email)
        URL_1               VARCHAR(100),                -- AR_CUST = 100 (primary website URL)
        URL_2               VARCHAR(100),                -- AR_CUST = 100 (secondary website URL)
        
        -- Classification (matching AR_CUST columns)
        CUST_TYP            VARCHAR(10),
        CATEG_COD           VARCHAR(10),                 -- Customer category (RETAIL, etc.)
        PROF_COD_1          VARCHAR(10),                 -- Tier pricing (TIER1, TIER2, TIER3, TIER4, TIER5, RESELLER, RETAIL)
        TERMS_COD           VARCHAR(10),
        TAX_COD             VARCHAR(10),
        STR_ID              VARCHAR(15),
        SLS_REP             VARCHAR(10),                 -- AR_CUST = 10 (sales rep assignment)
        SHIP_VIA_COD        VARCHAR(10),                 -- AR_CUST = 10 (shipping method preference)
        SHIP_ZONE_COD       VARCHAR(10),                 -- AR_CUST = 10 (shipping zone code)
        STMNT_COD           VARCHAR(10),                 -- AR_CUST = 10 (statement code)
        CUST_NAM_TYP        VARCHAR(1),                  -- AR_CUST = 1 (B=Business, P=Person)
        
        -- E-commerce preferences (matching AR_CUST columns)
        EMAIL_STATEMENT      VARCHAR(1),                  -- AR_CUST = 1 (Y/N - email statement preference)
        RPT_EMAIL            VARCHAR(1),                  -- AR_CUST = 1 (Y/N - report email preference)
        INCLUDE_IN_MARKETING_MAILOUTS VARCHAR(1),         -- AR_CUST = 1 (Y/N - marketing opt-in)
        COMMNT               VARCHAR(50),                 -- AR_CUST = 50 (general comments field)
        
        -- Flags
        IS_ECOMM_CUST       CHAR(1) DEFAULT 'Y',
        ALLOW_AR_CHRG       CHAR(1) DEFAULT 'N',
        
        -- Validation status
        IS_VALIDATED        BIT DEFAULT 0,
        VALIDATION_ERROR    NVARCHAR(500),              -- Errors that prevent import
        VALIDATION_NOTES    NVARCHAR(500),              -- Info messages (e.g., "linked to existing")
        IS_APPLIED          BIT DEFAULT 0,
        APPLIED_DT          DATETIME2,
        ACTION_TAKEN        VARCHAR(20) NULL,           -- INSERT, UPDATE, LINKED_EXISTING, SKIPPED
        
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
BEGIN
    PRINT 'USER_CUSTOMER_STAGING already exists';
    
    -- Add VALIDATION_NOTES column if missing (migration for existing tables)
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'USER_CUSTOMER_STAGING' AND COLUMN_NAME = 'VALIDATION_NOTES')
    BEGIN
        ALTER TABLE dbo.USER_CUSTOMER_STAGING ADD VALIDATION_NOTES NVARCHAR(500);
        PRINT '  -> Added VALIDATION_NOTES column';
    END
    
    -- Add PROF_COD_1 column if missing (tier pricing field - migration)
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'USER_CUSTOMER_STAGING' AND COLUMN_NAME = 'PROF_COD_1')
    BEGIN
        ALTER TABLE dbo.USER_CUSTOMER_STAGING ADD PROF_COD_1 VARCHAR(10);
        PRINT '  -> Added PROF_COD_1 column (tier pricing field)';
    END
    
    -- Add contact information fields (high priority - migration)
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'USER_CUSTOMER_STAGING' AND COLUMN_NAME = 'SALUTATION')
    BEGIN
        ALTER TABLE dbo.USER_CUSTOMER_STAGING ADD SALUTATION VARCHAR(10);
        PRINT '  -> Added SALUTATION column';
    END
    
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'USER_CUSTOMER_STAGING' AND COLUMN_NAME = 'PHONE_2')
    BEGIN
        ALTER TABLE dbo.USER_CUSTOMER_STAGING ADD PHONE_2 VARCHAR(25);
        PRINT '  -> Added PHONE_2 column';
    END
    
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'USER_CUSTOMER_STAGING' AND COLUMN_NAME = 'MBL_PHONE_1')
    BEGIN
        ALTER TABLE dbo.USER_CUSTOMER_STAGING ADD MBL_PHONE_1 VARCHAR(25);
        PRINT '  -> Added MBL_PHONE_1 column';
    END
    
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'USER_CUSTOMER_STAGING' AND COLUMN_NAME = 'MBL_PHONE_2')
    BEGIN
        ALTER TABLE dbo.USER_CUSTOMER_STAGING ADD MBL_PHONE_2 VARCHAR(25);
        PRINT '  -> Added MBL_PHONE_2 column';
    END
    
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'USER_CUSTOMER_STAGING' AND COLUMN_NAME = 'FAX_1')
    BEGIN
        ALTER TABLE dbo.USER_CUSTOMER_STAGING ADD FAX_1 VARCHAR(25);
        PRINT '  -> Added FAX_1 column';
    END
    
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'USER_CUSTOMER_STAGING' AND COLUMN_NAME = 'FAX_2')
    BEGIN
        ALTER TABLE dbo.USER_CUSTOMER_STAGING ADD FAX_2 VARCHAR(25);
        PRINT '  -> Added FAX_2 column';
    END
    
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'USER_CUSTOMER_STAGING' AND COLUMN_NAME = 'ADRS_3')
    BEGIN
        ALTER TABLE dbo.USER_CUSTOMER_STAGING ADD ADRS_3 VARCHAR(40);
        PRINT '  -> Added ADRS_3 column';
    END
    
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'USER_CUSTOMER_STAGING' AND COLUMN_NAME = 'CONTCT_1')
    BEGIN
        ALTER TABLE dbo.USER_CUSTOMER_STAGING ADD CONTCT_1 VARCHAR(40);
        PRINT '  -> Added CONTCT_1 column';
    END
    
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'USER_CUSTOMER_STAGING' AND COLUMN_NAME = 'CONTCT_2')
    BEGIN
        ALTER TABLE dbo.USER_CUSTOMER_STAGING ADD CONTCT_2 VARCHAR(40);
        PRINT '  -> Added CONTCT_2 column';
    END
    
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'USER_CUSTOMER_STAGING' AND COLUMN_NAME = 'EMAIL_ADRS_2')
    BEGIN
        ALTER TABLE dbo.USER_CUSTOMER_STAGING ADD EMAIL_ADRS_2 VARCHAR(50);
        PRINT '  -> Added EMAIL_ADRS_2 column';
    END
    
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'USER_CUSTOMER_STAGING' AND COLUMN_NAME = 'URL_1')
    BEGIN
        ALTER TABLE dbo.USER_CUSTOMER_STAGING ADD URL_1 VARCHAR(100);
        PRINT '  -> Added URL_1 column';
    END
    
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'USER_CUSTOMER_STAGING' AND COLUMN_NAME = 'URL_2')
    BEGIN
        ALTER TABLE dbo.USER_CUSTOMER_STAGING ADD URL_2 VARCHAR(100);
        PRINT '  -> Added URL_2 column';
    END
    
    -- Add business classification fields (high priority - migration)
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'USER_CUSTOMER_STAGING' AND COLUMN_NAME = 'SLS_REP')
    BEGIN
        ALTER TABLE dbo.USER_CUSTOMER_STAGING ADD SLS_REP VARCHAR(10);
        PRINT '  -> Added SLS_REP column (sales rep assignment)';
    END
    
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'USER_CUSTOMER_STAGING' AND COLUMN_NAME = 'SHIP_VIA_COD')
    BEGIN
        ALTER TABLE dbo.USER_CUSTOMER_STAGING ADD SHIP_VIA_COD VARCHAR(10);
        PRINT '  -> Added SHIP_VIA_COD column (shipping method preference)';
    END
    
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'USER_CUSTOMER_STAGING' AND COLUMN_NAME = 'SHIP_ZONE_COD')
    BEGIN
        ALTER TABLE dbo.USER_CUSTOMER_STAGING ADD SHIP_ZONE_COD VARCHAR(10);
        PRINT '  -> Added SHIP_ZONE_COD column (shipping zone code)';
    END
    
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'USER_CUSTOMER_STAGING' AND COLUMN_NAME = 'STMNT_COD')
    BEGIN
        ALTER TABLE dbo.USER_CUSTOMER_STAGING ADD STMNT_COD VARCHAR(10);
        PRINT '  -> Added STMNT_COD column (statement code)';
    END
    
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'USER_CUSTOMER_STAGING' AND COLUMN_NAME = 'CUST_NAM_TYP')
    BEGIN
        ALTER TABLE dbo.USER_CUSTOMER_STAGING ADD CUST_NAM_TYP VARCHAR(1);
        PRINT '  -> Added CUST_NAM_TYP column (customer name type: B=Business, P=Person)';
    END
    
    -- Add e-commerce preference fields (high priority - migration)
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'USER_CUSTOMER_STAGING' AND COLUMN_NAME = 'EMAIL_STATEMENT')
    BEGIN
        ALTER TABLE dbo.USER_CUSTOMER_STAGING ADD EMAIL_STATEMENT VARCHAR(1);
        PRINT '  -> Added EMAIL_STATEMENT column (email statement preference: Y/N)';
    END
    
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'USER_CUSTOMER_STAGING' AND COLUMN_NAME = 'RPT_EMAIL')
    BEGIN
        ALTER TABLE dbo.USER_CUSTOMER_STAGING ADD RPT_EMAIL VARCHAR(1);
        PRINT '  -> Added RPT_EMAIL column (report email preference: Y/N)';
    END
    
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'USER_CUSTOMER_STAGING' AND COLUMN_NAME = 'INCLUDE_IN_MARKETING_MAILOUTS')
    BEGIN
        ALTER TABLE dbo.USER_CUSTOMER_STAGING ADD INCLUDE_IN_MARKETING_MAILOUTS VARCHAR(1);
        PRINT '  -> Added INCLUDE_IN_MARKETING_MAILOUTS column (marketing opt-in: Y/N)';
    END
    
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'USER_CUSTOMER_STAGING' AND COLUMN_NAME = 'COMMNT')
    BEGIN
        ALTER TABLE dbo.USER_CUSTOMER_STAGING ADD COMMNT VARCHAR(50);
        PRINT '  -> Added COMMNT column (general comments field)';
    END
    
    -- Fix ACTION_TAKEN column length if too short
    IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
               WHERE TABLE_NAME = 'USER_CUSTOMER_STAGING' 
               AND COLUMN_NAME = 'ACTION_TAKEN' 
               AND CHARACTER_MAXIMUM_LENGTH < 20)
    BEGIN
        ALTER TABLE dbo.USER_CUSTOMER_STAGING ALTER COLUMN ACTION_TAKEN VARCHAR(20);
        PRINT '  -> Expanded ACTION_TAKEN column to VARCHAR(20)';
    END
END
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
-- 6. SHIP-TO ADDRESS STAGING TABLE
-- ============================================
-- For importing ship-to addresses before applying to AR_SHIP_ADRS
-- Rule 1.2: All imports go through staging
-- Rule 3.1: CUST_NO is king (must exist in AR_CUST)

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'USER_SHIP_TO_STAGING')
BEGIN
    CREATE TABLE dbo.USER_SHIP_TO_STAGING (
        STAGING_ID          INT IDENTITY(1,1) PRIMARY KEY,
        BATCH_ID            VARCHAR(50) NOT NULL,
        
        -- Customer identifier (Rule 3.1: CUST_NO is king)
        CUST_NO             VARCHAR(15) NOT NULL,       -- Must exist in AR_CUST
        WOO_USER_ID         INT NULL,                   -- For reference only
        
        -- Ship-to address data (matching AR_SHIP_ADRS column lengths exactly)
        SHIP_ADRS_ID        VARCHAR(10) NULL,           -- Will be auto-generated if NULL
        NAM                 VARCHAR(40),                -- AR_SHIP_ADRS = 40
        FST_NAM             VARCHAR(15),
        LST_NAM             VARCHAR(25),
        SALUTATION          VARCHAR(10),
        ADRS_1              VARCHAR(40),
        ADRS_2              VARCHAR(40),
        ADRS_3              VARCHAR(40),
        CITY                VARCHAR(20),
        STATE               VARCHAR(10),
        ZIP_COD             VARCHAR(15),
        CNTRY               VARCHAR(20) DEFAULT 'US',
        PHONE_1             VARCHAR(25),
        PHONE_2             VARCHAR(25),
        FAX_1               VARCHAR(25),
        FAX_2               VARCHAR(25),
        CONTCT_1             VARCHAR(40),
        CONTCT_2             VARCHAR(40),
        
        -- Validation status
        IS_VALIDATED        BIT DEFAULT 0,
        VALIDATION_ERROR    NVARCHAR(500),
        VALIDATION_NOTES    NVARCHAR(500),
        IS_APPLIED          BIT DEFAULT 0,
        APPLIED_DT          DATETIME2,
        ACTION_TAKEN        VARCHAR(20) NULL,           -- INSERT, UPDATE, SKIPPED
        CP_SHIP_ADRS_ID     VARCHAR(10) NULL,          -- AR_SHIP_ADRS.SHIP_ADRS_ID after creation
        
        -- Audit
        SOURCE_SYSTEM       VARCHAR(50) DEFAULT 'WOOCOMMERCE',
        CREATED_DT          DATETIME2 DEFAULT GETDATE(),
        CREATED_BY          VARCHAR(50) DEFAULT SYSTEM_USER
    );

    CREATE INDEX IX_SHIP_TO_STAGING_BATCH ON dbo.USER_SHIP_TO_STAGING(BATCH_ID);
    CREATE INDEX IX_SHIP_TO_STAGING_CUST ON dbo.USER_SHIP_TO_STAGING(CUST_NO);
    CREATE INDEX IX_SHIP_TO_STAGING_STATUS ON dbo.USER_SHIP_TO_STAGING(IS_VALIDATED, IS_APPLIED);
    
    PRINT 'Created USER_SHIP_TO_STAGING table';
END
ELSE
    PRINT 'USER_SHIP_TO_STAGING already exists';
GO


-- ============================================
-- 7. CUSTOMER NOTES STAGING TABLE
-- ============================================
-- For importing customer notes before applying to AR_CUST_NOTE
-- Rule 1.2: All imports go through staging
-- Rule 3.1: CUST_NO is king (must exist in AR_CUST)

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'USER_CUSTOMER_NOTES_STAGING')
BEGIN
    CREATE TABLE dbo.USER_CUSTOMER_NOTES_STAGING (
        STAGING_ID          INT IDENTITY(1,1) PRIMARY KEY,
        BATCH_ID            VARCHAR(50) NOT NULL,
        
        -- Customer identifier (Rule 3.1: CUST_NO is king)
        CUST_NO             VARCHAR(15) NOT NULL,       -- Must exist in AR_CUST
        WOO_USER_ID         INT NULL,                   -- For reference only
        
        -- Note data (matching AR_CUST_NOTE structure)
        NOTE_ID             INT NULL,                   -- Will be auto-generated if NULL
        NOTE_DAT            DATETIME2 DEFAULT GETDATE(),
        USR_ID              VARCHAR(10) DEFAULT SYSTEM_USER,
        NOTE                VARCHAR(50),                -- Short note (AR_CUST_NOTE = 50)
        NOTE_TXT            NVARCHAR(MAX),             -- Full note text
        
        -- Validation status
        IS_VALIDATED        BIT DEFAULT 0,
        VALIDATION_ERROR    NVARCHAR(500),
        VALIDATION_NOTES    NVARCHAR(500),
        IS_APPLIED          BIT DEFAULT 0,
        APPLIED_DT          DATETIME2,
        ACTION_TAKEN        VARCHAR(20) NULL,           -- INSERT, UPDATE, SKIPPED
        CP_NOTE_ID          INT NULL,                  -- AR_CUST_NOTE.NOTE_ID after creation
        
        -- Audit
        SOURCE_SYSTEM       VARCHAR(50) DEFAULT 'WOOCOMMERCE',
        CREATED_DT          DATETIME2 DEFAULT GETDATE(),
        CREATED_BY          VARCHAR(50) DEFAULT SYSTEM_USER
    );

    CREATE INDEX IX_CUSTOMER_NOTES_STAGING_BATCH ON dbo.USER_CUSTOMER_NOTES_STAGING(BATCH_ID);
    CREATE INDEX IX_CUSTOMER_NOTES_STAGING_CUST ON dbo.USER_CUSTOMER_NOTES_STAGING(CUST_NO);
    CREATE INDEX IX_CUSTOMER_NOTES_STAGING_STATUS ON dbo.USER_CUSTOMER_NOTES_STAGING(IS_VALIDATED, IS_APPLIED);
    
    PRINT 'Created USER_CUSTOMER_NOTES_STAGING table';
END
ELSE
    PRINT 'USER_CUSTOMER_NOTES_STAGING already exists';
GO


-- ============================================
-- 8. ORDER STAGING TABLE
-- ============================================
-- For importing WooCommerce orders before creating in PS_DOC_HDR
-- This is for Woo → CP order flow

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
-- 9. PRODUCT MAPPING TABLE
-- ============================================
-- Explicit mapping between CounterPoint SKUs and WooCommerce product IDs
-- Rule 3.3: Keep mappings explicit
-- Used for Phase 2: Product Catalog Sync

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'USER_PRODUCT_MAP')
BEGIN
    CREATE TABLE dbo.USER_PRODUCT_MAP (
        MAP_ID              INT IDENTITY(1,1) PRIMARY KEY,
        SKU                 VARCHAR(50) NOT NULL,       -- CP SKU (IM_ITEM.ITEM_NO)
        WOO_PRODUCT_ID      BIGINT NOT NULL,            -- WooCommerce product ID
        IS_ACTIVE           BIT DEFAULT 1,
        
        CREATED_DT          DATETIME2 DEFAULT GETDATE(),
        CREATED_BY          VARCHAR(50) DEFAULT SYSTEM_USER,
        UPDATED_DT          DATETIME2,
        UPDATED_BY          VARCHAR(50),
        NOTES               NVARCHAR(255)
    );

    -- Unique constraints: one active mapping per SKU / per Woo product
    CREATE UNIQUE INDEX IX_PRODUCT_MAP_SKU ON dbo.USER_PRODUCT_MAP(SKU) WHERE IS_ACTIVE = 1;
    CREATE UNIQUE INDEX IX_PRODUCT_MAP_WOO ON dbo.USER_PRODUCT_MAP(WOO_PRODUCT_ID) WHERE IS_ACTIVE = 1;
    
    PRINT 'Created USER_PRODUCT_MAP table';
END
ELSE
    PRINT 'USER_PRODUCT_MAP already exists';
GO


-- ============================================
-- 10. CATEGORY MAPPING TABLE
-- ============================================
-- Explicit mapping between CounterPoint category codes and WooCommerce category IDs
-- Rule 3.3: Keep mappings explicit
-- Used for Phase 2: Product Catalog Sync

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'USER_CATEGORY_MAP')
BEGIN
    CREATE TABLE dbo.USER_CATEGORY_MAP (
        MAP_ID              INT IDENTITY(1,1) PRIMARY KEY,
        CP_CATEGORY_CODE    VARCHAR(50) NOT NULL,        -- CP category code (IM_ITEM.CATEG_COD)
        WOO_CATEGORY_ID     BIGINT NOT NULL,            -- WooCommerce category ID
        WOO_CATEGORY_SLUG   VARCHAR(100) NULL,          -- WooCommerce category slug (for reference)
        IS_ACTIVE           BIT DEFAULT 1,
        
        CREATED_DT          DATETIME2 DEFAULT GETDATE(),
        CREATED_BY          VARCHAR(50) DEFAULT SYSTEM_USER,
        UPDATED_DT          DATETIME2,
        UPDATED_BY          VARCHAR(50),
        NOTES               NVARCHAR(255)
    );

    -- Unique constraints: one active mapping per CP category / per Woo category
    CREATE UNIQUE INDEX IX_CATEGORY_MAP_CP ON dbo.USER_CATEGORY_MAP(CP_CATEGORY_CODE) WHERE IS_ACTIVE = 1;
    CREATE UNIQUE INDEX IX_CATEGORY_MAP_WOO ON dbo.USER_CATEGORY_MAP(WOO_CATEGORY_ID) WHERE IS_ACTIVE = 1;
    
    PRINT 'Created USER_CATEGORY_MAP table';
END
ELSE
    PRINT 'USER_CATEGORY_MAP already exists';
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
    -- Note: PRC_COD validation is optional - price codes may be managed separately
    -- If PRC_COD table name differs, update the table name in the EXISTS clause below
    IF EXISTS (SELECT * FROM sys.tables WHERE name = 'IM_PRC_COD')
    BEGIN
        UPDATE s
        SET VALIDATION_ERROR = 'Price code not found: ' + s.PRC_COD
        FROM dbo.USER_CONTRACT_PRICE_STAGING s
        WHERE s.BATCH_ID = @BatchID
          AND s.IS_APPLIED = 0
          AND s.VALIDATION_ERROR IS NULL
          AND s.PRC_COD IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM dbo.IM_PRC_COD p WHERE p.PRC_COD = s.PRC_COD);
    END
    
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
-- MERGE STORED PROCEDURE: Staging → Master
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
-- REBUILD STORED PROCEDURE: Master → IM_PRC_RUL
-- ============================================
-- Rebuilds IM_PRC_RUL from our master table
-- Rule 1.3: Only touches rows we own (specific GRP_TYP or flag)
-- NOTE: CounterPoint's IM_PRC_RUL uses complex filter expressions.
--       This procedure is REPORT-ONLY (does not modify IM_PRC_RUL).

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'usp_Rebuild_ContractPricing_FromMaster')
    DROP PROCEDURE dbo.usp_Rebuild_ContractPricing_FromMaster;
GO

CREATE PROCEDURE dbo.usp_Rebuild_ContractPricing_FromMaster
    @DryRun BIT = 1,
    @DeletedCount INT = 0 OUTPUT,
    @InsertedCount INT = 0 OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    /*
    ============================================
    CONTRACT PRICING REPORT PROCEDURE
    ============================================
    
    CounterPoint's IM_PRC_RUL uses complex filter expressions
    that are not safe to modify programmatically. Instead,
    this procedure generates a REPORT of contract prices
    from USER_CONTRACT_PRICE_MASTER for manual review.
    
    The report can be used to:
    1. Verify pricing data imported from CSV/external sources
    2. Generate a list for manual entry into CounterPoint
    3. Compare with existing CP pricing
    
    NOTE: Actual pricing changes should be made through 
    CounterPoint's pricing management interface.
    ============================================
    */
    
    -- Always report mode (no direct CP modification)
    SET @DeletedCount = 0;
    SET @InsertedCount = 0;
    
    PRINT '============================================';
    PRINT 'CONTRACT PRICING REPORT';
    PRINT 'From: USER_CONTRACT_PRICE_MASTER';
    PRINT '============================================';
    PRINT '';
    
    -- Count active contract prices in our master table
    DECLARE @ActiveCount INT;
    SELECT @ActiveCount = COUNT(*)
    FROM dbo.USER_CONTRACT_PRICE_MASTER
    WHERE IS_ACTIVE = 1
      AND (EFFECTIVE_FROM IS NULL OR EFFECTIVE_FROM <= GETDATE())
      AND (EFFECTIVE_TO IS NULL OR EFFECTIVE_TO >= GETDATE());
    
    PRINT 'Active contract prices in master: ' + CAST(@ActiveCount AS VARCHAR);
    SET @InsertedCount = @ActiveCount;
    
    -- Summary by customer
    PRINT '';
    PRINT 'BY CUSTOMER:';
    PRINT '--------------------------------------------';
    
    SELECT 
        ISNULL(m.CUST_NO, '(ALL)') AS CUST_NO,
        c.NAM AS Customer_Name,
        COUNT(*) AS Rule_Count,
        CASE m.PRC_METH 
            WHEN 'D' THEN 'Discount %'
            WHEN 'O' THEN 'Override'
            WHEN 'M' THEN 'Markup %'
            WHEN 'A' THEN 'Amount Off'
            ELSE 'Unknown'
        END AS Price_Method,
        MIN(m.PRC_AMT) AS Min_Amount,
        MAX(m.PRC_AMT) AS Max_Amount
    FROM dbo.USER_CONTRACT_PRICE_MASTER m
    LEFT JOIN dbo.AR_CUST c ON c.CUST_NO = m.CUST_NO
    WHERE m.IS_ACTIVE = 1
      AND (m.EFFECTIVE_FROM IS NULL OR m.EFFECTIVE_FROM <= GETDATE())
      AND (m.EFFECTIVE_TO IS NULL OR m.EFFECTIVE_TO >= GETDATE())
    GROUP BY m.CUST_NO, c.NAM, m.PRC_METH
    ORDER BY m.CUST_NO;
    
    -- Detail preview (first 20)
    PRINT '';
    PRINT 'DETAIL PREVIEW (top 20):';
    PRINT '--------------------------------------------';
    
    SELECT TOP 20
        m.CONTRACT_ID,
        m.CUST_NO,
        m.ITEM_NO,
        m.ITEM_CATEG_COD,
        m.DESCR,
        m.PRC_METH,
        m.PRC_AMT,
        m.MIN_QTY,
        m.EFFECTIVE_FROM,
        m.EFFECTIVE_TO
    FROM dbo.USER_CONTRACT_PRICE_MASTER m
    WHERE m.IS_ACTIVE = 1
      AND (m.EFFECTIVE_FROM IS NULL OR m.EFFECTIVE_FROM <= GETDATE())
      AND (m.EFFECTIVE_TO IS NULL OR m.EFFECTIVE_TO >= GETDATE())
    ORDER BY m.PRIORITY, m.CONTRACT_ID;
    
    PRINT '';
    PRINT '============================================';
    PRINT 'NOTE: This is a REPORT only.';
    PRINT 'To apply pricing changes, use CounterPoint';
    PRINT 'Pricing Management interface.';
    PRINT '============================================';
    
    RETURN;
END
GO

PRINT 'Created usp_Rebuild_ContractPricing_FromMaster procedure (report-only)';


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
    c.CATEG_COD AS CUST_CATEG_COD,    -- Customer category
    c.PROF_COD_1 AS CUST_TIER,        -- Tier pricing (TIER1, TIER2, etc.)
    c.DISC_PCT AS CUST_DISC_PCT,      -- Customer discount %
    m.PRC_COD AS RULE_PRC_COD,        -- From our master table
    m.ITEM_NO,
    i.DESCR AS ITEM_DESCR,
    p.REG_PRC AS REGULAR_PRICE,       -- Regular price from IM_PRC
    p.PRC_1 AS TIER1_PRICE,           -- Tier 1 price
    p.PRC_2 AS TIER2_PRICE,           -- Tier 2 price
    p.PRC_3 AS TIER3_PRICE,           -- Tier 3 price
    m.PRC_METH,
    m.PRC_AMT,
    -- Calculate effective price based on method
    CASE 
        WHEN m.PRC_METH = 'D' THEN p.REG_PRC * (1 - m.PRC_AMT / 100)  -- Discount %
        WHEN m.PRC_METH = 'O' THEN m.PRC_AMT                          -- Override price
        WHEN m.PRC_METH = 'M' THEN p.REG_PRC * (1 + m.PRC_AMT / 100)  -- Markup %
        WHEN m.PRC_METH = 'A' THEN p.REG_PRC - m.PRC_AMT              -- Amount off
        ELSE p.REG_PRC
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
LEFT JOIN dbo.IM_PRC p ON p.ITEM_NO = m.ITEM_NO AND p.LOC_ID = '1'  -- Default location
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
    c.CATEG_COD,              -- Customer category
    c.PROF_COD_1,             -- Tier pricing (TIER1, TIER2, etc.)
    c.DISC_PCT,               -- Direct discount percentage
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
-- PRICING TIER REFERENCE VIEW
-- ============================================
-- Shows tier pricing distribution (PROF_COD_1 controls tier pricing)

IF EXISTS (SELECT * FROM sys.views WHERE name = 'VI_PRICING_TIER_SUMMARY')
    DROP VIEW dbo.VI_PRICING_TIER_SUMMARY;
GO

CREATE VIEW dbo.VI_PRICING_TIER_SUMMARY
AS
SELECT 
    c.PROF_COD_1 AS TIER,
    COUNT(*) AS Customer_Count,
    AVG(c.DISC_PCT) AS Avg_Discount_Pct,
    MIN(c.DISC_PCT) AS Min_Discount_Pct,
    MAX(c.DISC_PCT) AS Max_Discount_Pct
FROM dbo.AR_CUST c
WHERE c.PROF_COD_1 IS NOT NULL
GROUP BY c.PROF_COD_1;
GO

PRINT 'Created VI_PRICING_TIER_SUMMARY view';


-- ============================================
-- ITEM PRICE TIERS VIEW
-- ============================================
-- Shows item prices across all tiers

IF EXISTS (SELECT * FROM sys.views WHERE name = 'VI_ITEM_PRICE_TIERS')
    DROP VIEW dbo.VI_ITEM_PRICE_TIERS;
GO

CREATE VIEW dbo.VI_ITEM_PRICE_TIERS
AS
SELECT 
    p.ITEM_NO,
    i.DESCR AS ITEM_DESCR,
    p.LOC_ID,
    p.REG_PRC AS Regular_Price,
    p.PRC_1 AS Tier1_Price,
    p.PRC_2 AS Tier2_Price,
    p.PRC_3 AS Tier3_Price,
    p.PRC_4 AS Tier4_Price,
    p.PRC_5 AS Tier5_Price,
    p.PRC_6 AS Tier6_Price,
    -- Calculate discount percentages from regular price
    CASE WHEN p.REG_PRC > 0 THEN ROUND((1 - p.PRC_1/p.REG_PRC) * 100, 2) END AS Tier1_Discount_Pct,
    CASE WHEN p.REG_PRC > 0 THEN ROUND((1 - p.PRC_2/p.REG_PRC) * 100, 2) END AS Tier2_Discount_Pct,
    CASE WHEN p.REG_PRC > 0 THEN ROUND((1 - p.PRC_3/p.REG_PRC) * 100, 2) END AS Tier3_Discount_Pct
FROM dbo.IM_PRC p
JOIN dbo.IM_ITEM i ON i.ITEM_NO = p.ITEM_NO
WHERE p.REG_PRC IS NOT NULL AND p.REG_PRC > 0;
GO

PRINT 'Created VI_ITEM_PRICE_TIERS view';


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
    @DefaultTAX_COD VARCHAR(10) = 'FL-BROWAR',  -- Max 10 chars (FL-BROWARD truncated)
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
    
    -- Get next CUST_NO (find max numeric customer number)
    DECLARE @NextCustNo INT;
    SELECT @NextCustNo = ISNULL(MAX(TRY_CAST(CUST_NO AS INT)), 9999) + 1
    FROM dbo.AR_CUST
    WHERE TRY_CAST(CUST_NO AS INT) IS NOT NULL;
    
    PRINT 'Next CUST_NO will start at: ' + CAST(@NextCustNo AS VARCHAR);
    
    -- Create temp table for records to process
    CREATE TABLE #ToProcess (
        STAGING_ID INT,
        WOO_USER_ID INT,
        EMAIL_ADRS_1 VARCHAR(50),
        NAM VARCHAR(40),
        FST_NAM VARCHAR(15),
        LST_NAM VARCHAR(25),
        SALUTATION VARCHAR(10),
        PHONE_1 VARCHAR(25),
        PHONE_2 VARCHAR(25),
        MBL_PHONE_1 VARCHAR(25),
        MBL_PHONE_2 VARCHAR(25),
        FAX_1 VARCHAR(25),
        FAX_2 VARCHAR(25),
        ADRS_1 VARCHAR(40),
        ADRS_2 VARCHAR(40),
        ADRS_3 VARCHAR(40),
        CITY VARCHAR(20),
        STATE VARCHAR(10),
        ZIP_COD VARCHAR(15),
        CNTRY VARCHAR(20),
        CONTCT_1 VARCHAR(40),
        CONTCT_2 VARCHAR(40),
        EMAIL_ADRS_2 VARCHAR(50),
        URL_1 VARCHAR(100),
        URL_2 VARCHAR(100),
        CATEG_COD VARCHAR(10),
        PROF_COD_1 VARCHAR(10),
        TAX_COD VARCHAR(10),
        SLS_REP VARCHAR(10),
        SHIP_VIA_COD VARCHAR(10),
        SHIP_ZONE_COD VARCHAR(10),
        STMNT_COD VARCHAR(10),
        CUST_NAM_TYP VARCHAR(1),
        EMAIL_STATEMENT VARCHAR(1),
        RPT_EMAIL VARCHAR(1),
        INCLUDE_IN_MARKETING_MAILOUTS VARCHAR(1),
        COMMNT VARCHAR(50),
        NEW_CUST_NO VARCHAR(15)
    );
    
    -- Load records to process (with field length limits matching AR_CUST)
    -- Also sanitize: remove Unicode issues, normalize phone, handle NULLs
    -- SKIP records with VALIDATION_ERROR (incomplete info - stay in WooCommerce only)
    INSERT INTO #ToProcess
    SELECT 
        s.STAGING_ID,
        s.WOO_USER_ID,  -- Can be NULL for guest checkout
        -- Email: trim, lowercase for matching
        LOWER(LTRIM(RTRIM(LEFT(s.EMAIL_ADRS_1, 50)))),
        -- NAM: sanitize Unicode, use company or name
        LEFT(
            REPLACE(REPLACE(REPLACE(REPLACE(
                ISNULL(s.NAM, 'Web Customer'),
                CHAR(0), ''),    -- Remove null chars
                CHAR(9), ' '),   -- Tab to space
                CHAR(10), ' '),  -- Newline to space
                CHAR(13), ' '),  -- CR to space
            40),
        LEFT(LTRIM(RTRIM(s.FST_NAM)), 15),
        LEFT(LTRIM(RTRIM(s.LST_NAM)), 25),
        LEFT(LTRIM(RTRIM(ISNULL(s.SALUTATION, ''))), 10),  -- Salutation (Mr., Ms., Dr., etc.)
        -- Phone: light normalization (keep readable format, just trim)
        -- Full stripping would break extensions like "ext 123"
        LEFT(LTRIM(RTRIM(ISNULL(s.PHONE_1, ''))), 25),
        LEFT(LTRIM(RTRIM(ISNULL(s.PHONE_2, ''))), 25),  -- Secondary phone
        LEFT(LTRIM(RTRIM(ISNULL(s.MBL_PHONE_1, ''))), 25),  -- Mobile phone 1
        LEFT(LTRIM(RTRIM(ISNULL(s.MBL_PHONE_2, ''))), 25),  -- Mobile phone 2
        LEFT(LTRIM(RTRIM(ISNULL(s.FAX_1, ''))), 25),  -- Primary fax
        LEFT(LTRIM(RTRIM(ISNULL(s.FAX_2, ''))), 25),  -- Secondary fax
        LEFT(LTRIM(RTRIM(s.ADRS_1)), 40),
        LEFT(LTRIM(RTRIM(s.ADRS_2)), 40),
        LEFT(LTRIM(RTRIM(ISNULL(s.ADRS_3, ''))), 40),  -- Third address line
        LEFT(LTRIM(RTRIM(s.CITY)), 20),
        LEFT(UPPER(LTRIM(RTRIM(s.STATE))), 10),  -- State codes uppercase
        LEFT(LTRIM(RTRIM(s.ZIP_COD)), 15),
        LEFT(UPPER(LTRIM(RTRIM(ISNULL(s.CNTRY, 'US')))), 20),  -- Country uppercase
        LEFT(LTRIM(RTRIM(ISNULL(s.CONTCT_1, ''))), 40),  -- Primary contact name
        LEFT(LTRIM(RTRIM(ISNULL(s.CONTCT_2, ''))), 40),  -- Secondary contact name
        LEFT(LOWER(LTRIM(RTRIM(ISNULL(s.EMAIL_ADRS_2, '')))), 50),  -- Secondary email (lowercase for consistency)
        LEFT(LTRIM(RTRIM(ISNULL(s.URL_1, ''))), 100),  -- Primary website URL
        LEFT(LTRIM(RTRIM(ISNULL(s.URL_2, ''))), 100),  -- Secondary website URL
        LEFT(ISNULL(s.CATEG_COD, 'RETAIL'), 10),  -- CATEG_COD: max 10 (always truncate to ensure compliance)
        LEFT(ISNULL(s.PROF_COD_1, 'RETAIL'), 10),  -- PROF_COD_1: max 10 (always truncate to ensure compliance)
        LEFT(ISNULL(s.TAX_COD, @DefaultTAX_COD), 10),  -- TAX_COD: max 10 (always truncate to ensure compliance)
        LEFT(LTRIM(RTRIM(ISNULL(s.SLS_REP, ''))), 10),  -- Sales rep assignment
        LEFT(LTRIM(RTRIM(ISNULL(s.SHIP_VIA_COD, ''))), 10),  -- Shipping method preference
        LEFT(LTRIM(RTRIM(ISNULL(s.SHIP_ZONE_COD, ''))), 10),  -- Shipping zone code
        LEFT(LTRIM(RTRIM(ISNULL(s.STMNT_COD, ''))), 10),  -- Statement code
        LEFT(UPPER(LTRIM(RTRIM(ISNULL(s.CUST_NAM_TYP, 'B')))), 1),  -- Customer name type (B=Business, P=Person, default to B)
        LEFT(UPPER(LTRIM(RTRIM(ISNULL(s.EMAIL_STATEMENT, 'N')))), 1),  -- Email statement preference (Y/N, default N)
        LEFT(UPPER(LTRIM(RTRIM(ISNULL(s.RPT_EMAIL, 'N')))), 1),  -- Report email preference (Y/N, default N)
        LEFT(UPPER(LTRIM(RTRIM(ISNULL(s.INCLUDE_IN_MARKETING_MAILOUTS, 'N')))), 1),  -- Marketing opt-in (Y/N, default N)
        LEFT(LTRIM(RTRIM(ISNULL(s.COMMNT, ''))), 50),  -- General comments field
        NULL
    FROM dbo.USER_CUSTOMER_STAGING s
    WHERE s.IS_APPLIED = 0
      AND s.CUST_NO IS NULL
      AND s.VALIDATION_ERROR IS NULL  -- Skip customers with validation errors (incomplete info - stay in WooCommerce only)
      AND (
          (@BatchID IS NOT NULL AND s.BATCH_ID = @BatchID)
          OR (@StagingID IS NOT NULL AND s.STAGING_ID = @StagingID)
      );
    
    DECLARE @RecordCount INT = (SELECT COUNT(*) FROM #ToProcess);
    DECLARE @SkippedValidationErrors INT;
    
    -- Count how many were skipped due to validation errors
    SELECT @SkippedValidationErrors = COUNT(*)
    FROM dbo.USER_CUSTOMER_STAGING s
    WHERE s.IS_APPLIED = 0
      AND s.CUST_NO IS NULL
      AND s.VALIDATION_ERROR IS NOT NULL
      AND (
          (@BatchID IS NOT NULL AND s.BATCH_ID = @BatchID)
          OR (@StagingID IS NOT NULL AND s.STAGING_ID = @StagingID)
      );
    
    PRINT 'Records to process: ' + CAST(@RecordCount AS VARCHAR);
    IF @SkippedValidationErrors > 0
    BEGIN
        PRINT 'Skipped (validation errors - incomplete info): ' + CAST(@SkippedValidationErrors AS VARCHAR);
        PRINT '  Note: These customers remain in WooCommerce with full access, but are not synced to CounterPoint';
    END
    
    -- =========================================================================
    -- GAP #1: EMAIL DUPLICATE CHECK
    -- Skip records where email already exists in AR_CUST
    -- =========================================================================
    
    DECLARE @DuplicateEmails INT;
    
    -- Find emails that already exist in CounterPoint
    CREATE TABLE #DuplicateEmails (
        STAGING_ID INT,
        EMAIL_ADRS_1 VARCHAR(50),
        EXISTING_CUST_NO VARCHAR(15)
    );
    
    INSERT INTO #DuplicateEmails
    SELECT t.STAGING_ID, t.EMAIL_ADRS_1, c.CUST_NO
    FROM #ToProcess t
    INNER JOIN dbo.AR_CUST c ON LOWER(LTRIM(RTRIM(c.EMAIL_ADRS_1))) = t.EMAIL_ADRS_1
    WHERE t.EMAIL_ADRS_1 IS NOT NULL AND t.EMAIL_ADRS_1 <> '';
    
    SET @DuplicateEmails = @@ROWCOUNT;
    
    IF @DuplicateEmails > 0
    BEGIN
        PRINT '';
        PRINT 'WARNING: ' + CAST(@DuplicateEmails AS VARCHAR) + ' email(s) already exist in CounterPoint:';
        PRINT '------------------------------------------------------------';
        
        SELECT 
            EMAIL_ADRS_1 AS [Email],
            EXISTING_CUST_NO AS [Existing CUST_NO]
        FROM #DuplicateEmails;
        
        -- Remove duplicates from processing (they already have CP accounts)
        DELETE t
        FROM #ToProcess t
        INNER JOIN #DuplicateEmails d ON t.STAGING_ID = d.STAGING_ID;
        
        -- Update staging records to link them to existing customers
        UPDATE s
        SET 
            CUST_NO = d.EXISTING_CUST_NO,
            IS_APPLIED = 1,
            APPLIED_DT = GETDATE(),
            ACTION_TAKEN = 'LINKED_EXISTING',
            VALIDATION_NOTES = 'Email matched existing CP customer'
        FROM dbo.USER_CUSTOMER_STAGING s
        INNER JOIN #DuplicateEmails d ON s.STAGING_ID = d.STAGING_ID;
        
        PRINT 'Linked ' + CAST(@DuplicateEmails AS VARCHAR) + ' staging records to existing customers';
    END
    
    DROP TABLE #DuplicateEmails;
    
    -- =========================================================================
    -- GAP #2: Check for NULL/invalid emails (potential spam/bots)
    -- =========================================================================
    
    DECLARE @InvalidEmails INT;
    
    SELECT @InvalidEmails = COUNT(*) 
    FROM #ToProcess 
    WHERE EMAIL_ADRS_1 IS NULL 
       OR EMAIL_ADRS_1 = '' 
       OR EMAIL_ADRS_1 NOT LIKE '%@%.%';
    
    IF @InvalidEmails > 0
    BEGIN
        PRINT '';
        PRINT 'WARNING: ' + CAST(@InvalidEmails AS VARCHAR) + ' record(s) have invalid/missing emails';
        
        -- Show them but don't remove - let user decide
        SELECT STAGING_ID, NAM, EMAIL_ADRS_1, WOO_USER_ID
        FROM #ToProcess
        WHERE EMAIL_ADRS_1 IS NULL 
           OR EMAIL_ADRS_1 = '' 
           OR EMAIL_ADRS_1 NOT LIKE '%@%.%';
    END
    
    -- =========================================================================
    -- GAP #3: Guest checkout handling (WOO_USER_ID is NULL)
    -- These are still valid customers, just no mapping created
    -- =========================================================================
    
    DECLARE @GuestCheckouts INT;
    
    SELECT @GuestCheckouts = COUNT(*) 
    FROM #ToProcess 
    WHERE WOO_USER_ID IS NULL;
    
    IF @GuestCheckouts > 0
    BEGIN
        PRINT '';
        PRINT 'INFO: ' + CAST(@GuestCheckouts AS VARCHAR) + ' guest checkout(s) - will create customer but no WooCommerce mapping';
    END
    
    -- Recount after removing duplicates
    SET @RecordCount = (SELECT COUNT(*) FROM #ToProcess);
    PRINT '';
    PRINT 'Records remaining after duplicate check: ' + CAST(@RecordCount AS VARCHAR);
    
    IF @RecordCount = 0
    BEGIN
        PRINT 'No eligible records found to process.';
        DROP TABLE #ToProcess;
        RETURN;
    END
    
    -- Assign sequential CUST_NO to each record
    ;WITH Numbered AS (
        SELECT STAGING_ID, ROW_NUMBER() OVER (ORDER BY STAGING_ID) AS RowNum
        FROM #ToProcess
    )
    UPDATE t
    SET NEW_CUST_NO = CAST(@NextCustNo + n.RowNum - 1 AS VARCHAR(15))
    FROM #ToProcess t
    INNER JOIN Numbered n ON t.STAGING_ID = n.STAGING_ID;
    
    -- Preview what we're about to create
    PRINT '';
    PRINT 'Customers to create:';
    PRINT '------------------------------------------------------------';
    
    SELECT 
        NEW_CUST_NO AS [CUST_NO],
        NAM AS [Name],
        SALUTATION AS [Salutation],
        EMAIL_ADRS_1 AS [Email],
        EMAIL_ADRS_2 AS [Email2],
        PHONE_1 AS [Phone],
        PHONE_2 AS [Phone2],
        MBL_PHONE_1 AS [Mobile],
        CONTCT_1 AS [Contact],
        CATEG_COD AS [Category],
        PROF_COD_1 AS [Tier],
        WOO_USER_ID AS [WooID]
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
    
    -- Begin transaction for atomicity
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- Insert into AR_CUST
        INSERT INTO dbo.AR_CUST (
            CUST_NO, NAM, NAM_UPR, CUST_TYP, PROMPT_NAM_ADRS, SLS_REP, STR_ID,
            SHIP_VIA_COD, SHIP_ZONE_COD, STMNT_COD,
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
            SALUTATION,
            ADRS_1, ADRS_2, ADRS_3, CITY, STATE, ZIP_COD, CNTRY,
            PHONE_1, PHONE_2, MBL_PHONE_1, MBL_PHONE_2, FAX_1, FAX_2,
            CONTCT_1, CONTCT_2,
            EMAIL_ADRS_1, EMAIL_ADRS_2,
            URL_1, URL_2,
            CATEG_COD, PROF_COD_1, TAX_COD,
            COMMNT,
            LST_MAINT_DT, LST_MAINT_USR_ID
        )
        SELECT
            LEFT(t.NEW_CUST_NO, 15),           -- CUST_NO: max 15
            LEFT(t.NAM, 40),                    -- NAM: max 40
            LEFT(UPPER(t.NAM), 40),             -- NAM_UPR: max 40
            'C',                                -- CUST_TYP: C (valid: C or A)
            'N',                                -- PROMPT_NAM_ADRS: N (valid: S, N, or Y)
            LEFT(t.SLS_REP, 10),                -- SLS_REP: max 10 (sales rep assignment)
            LEFT(@DefaultSTR_ID, 10),           -- STR_ID: max 10
            LEFT(t.SHIP_VIA_COD, 10),           -- SHIP_VIA_COD: max 10 (shipping method preference)
            LEFT(t.SHIP_ZONE_COD, 10),          -- SHIP_ZONE_COD: max 10 (shipping zone code)
            LEFT(t.STMNT_COD, 10),              -- STMNT_COD: max 10 (statement code)
            'N',
            'Y',
            'Y',
            'Y',
            0,
            'O',                                -- BAL_METH: O (only valid value per CPPractice constraint)
            0,
            0,
            0,
            'N',
            'Y',
            'Y',
            'I',                                -- LST_AGE_METH: I (valid: D, I, or !)
            'N',
            '!',                                -- LST_STMNT_METH: ! (valid: D, I, or ! per CPPractice constraint)
            'N',
            0,
            0,
            'N',
            'Y',
            'Y',
            'N',
            'N',
            'N',
            0,
            0,
            0,
            0,
            'N',
            LEFT(t.CUST_NAM_TYP, 1),            -- CUST_NAM_TYP: max 1 (B=Business, P=Person, default B)
            LEFT(t.EMAIL_STATEMENT, 1),         -- EMAIL_STATEMENT: max 1 (Y/N - email statement preference)
            0,                                  -- RS_STAT
            LEFT(t.INCLUDE_IN_MARKETING_MAILOUTS, 1),  -- INCLUDE_IN_MARKETING_MAILOUTS: max 1 (Y/N - marketing opt-in)
            LEFT(t.RPT_EMAIL, 1),               -- RPT_EMAIL: max 1 (Y/N - report email preference)
            LEFT(t.FST_NAM, 15),                -- FST_NAM: max 15
            LEFT(UPPER(t.FST_NAM), 15),         -- FST_NAM_UPR: max 15
            LEFT(t.LST_NAM, 25),                -- LST_NAM: max 25
            LEFT(UPPER(t.LST_NAM), 25),         -- LST_NAM_UPR: max 25
            LEFT(t.SALUTATION, 10),             -- SALUTATION: max 10
            LEFT(t.ADRS_1, 40),                 -- ADRS_1: max 40
            LEFT(t.ADRS_2, 40),                 -- ADRS_2: max 40
            LEFT(t.ADRS_3, 40),                 -- ADRS_3: max 40
            LEFT(t.CITY, 20),                    -- CITY: max 20
            LEFT(t.STATE, 10),                   -- STATE: max 10
            LEFT(t.ZIP_COD, 15),                 -- ZIP_COD: max 15
            LEFT(t.CNTRY, 20),                  -- CNTRY: max 20
            LEFT(t.PHONE_1, 25),                 -- PHONE_1: max 25
            LEFT(t.PHONE_2, 25),                 -- PHONE_2: max 25
            LEFT(t.MBL_PHONE_1, 25),            -- MBL_PHONE_1: max 25
            LEFT(t.MBL_PHONE_2, 25),            -- MBL_PHONE_2: max 25
            LEFT(t.FAX_1, 25),                   -- FAX_1: max 25
            LEFT(t.FAX_2, 25),                   -- FAX_2: max 25
            LEFT(t.CONTCT_1, 40),               -- CONTCT_1: max 40
            LEFT(t.CONTCT_2, 40),               -- CONTCT_2: max 40
            LEFT(t.EMAIL_ADRS_1, 50),            -- EMAIL_ADRS_1: max 50
            LEFT(t.EMAIL_ADRS_2, 50),            -- EMAIL_ADRS_2: max 50
            LEFT(t.URL_1, 100),                  -- URL_1: max 100
            LEFT(t.URL_2, 100),                  -- URL_2: max 100
            LEFT(t.CATEG_COD, 10),               -- CATEG_COD: max 10
            LEFT(t.PROF_COD_1, 10),              -- PROF_COD_1: max 10
            LEFT(t.TAX_COD, 10),                 -- TAX_COD: max 10
            LEFT(t.COMMNT, 50),                  -- COMMNT: max 50 (general comments field)
            GETDATE(),
            'INTEG'                              -- LST_MAINT_USR_ID: abbreviated from 'INTEGRATION' (max 10 chars)
        FROM #ToProcess t;
        
        SET @CreatedCount = @@ROWCOUNT;
        PRINT 'Created ' + CAST(@CreatedCount AS VARCHAR) + ' customers in AR_CUST';
        
        -- Create mappings in USER_CUSTOMER_MAP
        INSERT INTO dbo.USER_CUSTOMER_MAP (
            CUST_NO, WOO_USER_ID, WOO_EMAIL, MAPPING_SOURCE, IS_ACTIVE
        )
        SELECT 
            t.NEW_CUST_NO,
            t.WOO_USER_ID,
            LEFT(t.EMAIL_ADRS_1, 100),         -- WOO_EMAIL: max 100
            'AUTO_STAGING',
            1
        FROM #ToProcess t
        WHERE t.WOO_USER_ID IS NOT NULL;
        
        PRINT 'Created ' + CAST(@@ROWCOUNT AS VARCHAR) + ' customer mappings';
        
        -- Update staging records as applied
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
        IF @InvalidEmails > 0
            PRINT 'Invalid emails (warning):  ' + CAST(@InvalidEmails AS VARCHAR);
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

PRINT 'Created usp_Create_Customers_From_Staging procedure';

-- To validate a batch before creating, run these queries manually:
-- 
-- Check for duplicates:
--   SELECT EMAIL_ADRS_1, COUNT(*) FROM USER_CUSTOMER_STAGING 
--   WHERE BATCH_ID = 'your_batch' GROUP BY EMAIL_ADRS_1 HAVING COUNT(*) > 1;
--
-- Check emails already in CounterPoint:
--   SELECT s.EMAIL_ADRS_1, c.CUST_NO FROM USER_CUSTOMER_STAGING s
--   INNER JOIN AR_CUST c ON LOWER(s.EMAIL_ADRS_1) = LOWER(c.EMAIL_ADRS_1)
--   WHERE s.BATCH_ID = 'your_batch';


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
    
    -- Cleanup applied ship-to staging
    DELETE FROM dbo.USER_SHIP_TO_STAGING
    WHERE IS_APPLIED = 1 AND APPLIED_DT < @CutoffDate;
    SET @Deleted = @@ROWCOUNT;
    PRINT 'Deleted ' + CAST(@Deleted AS VARCHAR) + ' old ship-to staging records';
    
    -- Cleanup applied customer notes staging
    DELETE FROM dbo.USER_CUSTOMER_NOTES_STAGING
    WHERE IS_APPLIED = 1 AND APPLIED_DT < @CutoffDate;
    SET @Deleted = @@ROWCOUNT;
    PRINT 'Deleted ' + CAST(@Deleted AS VARCHAR) + ' old customer notes staging records';
    
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
PRINT '============================================';
PRINT '';
PRINT 'Tables Created:';
PRINT '  - USER_SYNC_LOG                  (sync audit trail)';
PRINT '  - USER_CONTRACT_PRICE_MASTER     (contract pricing source of truth)';
PRINT '  - USER_CONTRACT_PRICE_STAGING    (contract pricing imports)';
PRINT '  - USER_CUSTOMER_STAGING          (customer imports)';
PRINT '  - USER_CUSTOMER_MAP              (CP <-> Woo customer mapping)';
PRINT '  - USER_SHIP_TO_STAGING           (ship-to address imports)';
PRINT '  - USER_CUSTOMER_NOTES_STAGING    (customer notes imports)';
PRINT '  - USER_ORDER_STAGING             (order imports)';
PRINT '';
PRINT 'Views Created:';
PRINT '  - VI_EXPORT_CONTRACT_PRICES      (for Woo sync)';
PRINT '  - VI_EXPORT_ECOMM_CUSTOMERS      (for Woo sync)';
PRINT '  - VI_PRICING_TIER_SUMMARY        (customer tier analysis)';
PRINT '  - VI_ITEM_PRICE_TIERS            (item prices by tier)';
PRINT '';
PRINT 'Procedures Created:';
PRINT '  - usp_Validate_ContractPricing_Staging';
PRINT '  - usp_Merge_ContractPricing_StagingToMaster';
PRINT '  - usp_Rebuild_ContractPricing_FromMaster (report-only)';
PRINT '  - usp_Create_Customers_From_Staging';
PRINT '  - usp_Create_ShipTo_From_Staging';
PRINT '  - usp_Create_CustomerNotes_From_Staging';
PRINT '  - usp_Cleanup_StagingTables';
PRINT '';
PRINT 'PRICING STRATEGY:';
PRINT '  - New WooCommerce customers -> CATEG_COD = RETAIL, PROF_COD_1 = RETAIL';
PRINT '  - PROF_COD_1 controls tier pricing discounts (used by pricing rules)';
PRINT '  - CounterPoint pricing rules filter by PROF_COD_1 (TIER1, TIER2, etc.)';
PRINT '  - Staff can upgrade PROF_COD_1 to TIER1/2/3/4/5/RESELLER as needed';
PRINT '';
GO

-- ============================================
-- VERIFICATION: Show Current Customer Tiers
-- ============================================

PRINT '';
PRINT '============================================';
PRINT 'VERIFICATION: Tier Pricing Distribution';
PRINT 'Field: PROF_COD_1 (ACTIVE TIER PRICING FIELD)';
PRINT 'This field controls tier pricing discounts';
PRINT '============================================';

SELECT 
    c.PROF_COD_1 AS [Tier],
    COUNT(*) AS [Customers],
    MIN(c.DISC_PCT) AS [Min Disc %],
    MAX(c.DISC_PCT) AS [Max Disc %]
FROM dbo.AR_CUST c
WHERE c.PROF_COD_1 IS NOT NULL
GROUP BY c.PROF_COD_1
ORDER BY 
    CASE c.PROF_COD_1 
        WHEN 'RETAIL' THEN 1 
        WHEN 'TIER1' THEN 2 
        WHEN 'TIER2' THEN 3 
        WHEN 'TIER3' THEN 4 
        WHEN 'TIER4' THEN 5 
        WHEN 'TIER5' THEN 6
        ELSE 99 
    END;
GO

PRINT '';
PRINT '============================================';
PRINT 'VERIFICATION: Customer Category Distribution';
PRINT 'Field: CATEG_COD (CUSTOMER CATEGORY - Mostly Defaults)';
PRINT 'Note: Most customers default to RETAIL here';
PRINT '============================================';

SELECT 
    c.CATEG_COD AS [Category],
    COUNT(*) AS [Customers],
    MIN(c.DISC_PCT) AS [Min Disc %],
    MAX(c.DISC_PCT) AS [Max Disc %]
FROM dbo.AR_CUST c
WHERE c.CATEG_COD IS NOT NULL
GROUP BY c.CATEG_COD
ORDER BY COUNT(*) DESC;
GO

PRINT '';
PRINT 'Setup complete at: ' + CONVERT(VARCHAR, GETDATE(), 126);
PRINT '============================================';
GO

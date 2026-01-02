-- ============================================
-- TAX CODE MAPPING TABLE
-- Stores full tax code names for reference
-- while using abbreviated codes in AR_CUST
-- ============================================

USE WOODYS_CP;  -- Change to CPPractice if testing
GO

-- Create mapping table for tax codes
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'USER_TAX_CODE_MAPPING')
BEGIN
    CREATE TABLE dbo.USER_TAX_CODE_MAPPING (
        TAX_CODE_ABBREV VARCHAR(10) PRIMARY KEY,  -- What goes in AR_CUST.TAX_COD (max 10 chars)
        TAX_CODE_FULL VARCHAR(100),                -- Full descriptive name
        STATE_CODE VARCHAR(2),                     -- State abbreviation
        COUNTY_NAME VARCHAR(50),                   -- County name
        DESCRIPTION NVARCHAR(255),                 -- Additional description
        CREATED_DT DATETIME DEFAULT GETDATE(),
        UPDATED_DT DATETIME DEFAULT GETDATE()
    );
    
    PRINT 'Created USER_TAX_CODE_MAPPING table';
END
ELSE
BEGIN
    PRINT 'USER_TAX_CODE_MAPPING table already exists';
END
GO

-- Insert common Florida tax codes
IF NOT EXISTS (SELECT 1 FROM dbo.USER_TAX_CODE_MAPPING WHERE TAX_CODE_ABBREV = 'FL-BROWAR')
BEGIN
    INSERT INTO dbo.USER_TAX_CODE_MAPPING (TAX_CODE_ABBREV, TAX_CODE_FULL, STATE_CODE, COUNTY_NAME, DESCRIPTION)
    VALUES 
        ('FL-BROWAR', 'FL-BROWARD', 'FL', 'Broward', 'Broward County, Florida'),
        ('FL-DADE', 'FL-MIAMI-DADE', 'FL', 'Miami-Dade', 'Miami-Dade County, Florida'),
        ('FL-PALMB', 'FL-PALM-BEACH', 'FL', 'Palm Beach', 'Palm Beach County, Florida'),
        ('FL-HILLS', 'FL-HILLSBOROUGH', 'FL', 'Hillsborough', 'Hillsborough County, Florida'),
        ('FL-ORANG', 'FL-ORANGE', 'FL', 'Orange', 'Orange County, Florida');
    
    PRINT 'Inserted common Florida tax code mappings';
END
ELSE
BEGIN
    PRINT 'Tax code mappings already exist';
END
GO

-- Create view for easy lookup
IF EXISTS (SELECT * FROM sys.views WHERE name = 'VW_TAX_CODE_MAPPING')
    DROP VIEW dbo.VW_TAX_CODE_MAPPING;
GO

CREATE VIEW dbo.VW_TAX_CODE_MAPPING AS
SELECT 
    TAX_CODE_ABBREV,
    TAX_CODE_FULL,
    STATE_CODE,
    COUNTY_NAME,
    DESCRIPTION
FROM dbo.USER_TAX_CODE_MAPPING;
GO

PRINT 'Created VW_TAX_CODE_MAPPING view';
PRINT '';
PRINT '============================================';
PRINT 'TAX CODE MAPPING SETUP COMPLETE';
PRINT '============================================';
PRINT '';
PRINT 'Usage:';
PRINT '  SELECT * FROM dbo.VW_TAX_CODE_MAPPING;';
PRINT '  SELECT * FROM dbo.VW_TAX_CODE_MAPPING WHERE STATE_CODE = ''FL'';';
PRINT '';
PRINT 'To add more mappings:';
PRINT '  INSERT INTO dbo.USER_TAX_CODE_MAPPING (TAX_CODE_ABBREV, TAX_CODE_FULL, STATE_CODE, COUNTY_NAME)';
PRINT '  VALUES (''FL-XXXXX'', ''FL-FULL-NAME'', ''FL'', ''County Name'');';
PRINT '============================================';
GO


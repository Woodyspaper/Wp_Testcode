-- ============================================
-- Tax Code Abbreviation System
-- Ensures all tax codes are 10 characters or less
-- ============================================

USE WOODYS_CP;  -- or CPPractice if testing
GO

-- Create function to abbreviate tax codes to 10 chars
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'fn_Abbreviate_Tax_Code' AND type = 'FN')
    DROP FUNCTION dbo.fn_Abbreviate_Tax_Code;
GO

CREATE FUNCTION dbo.fn_Abbreviate_Tax_Code(@TaxCode VARCHAR(100))
RETURNS VARCHAR(10)
AS
BEGIN
    DECLARE @Abbrev VARCHAR(10);
    
    -- If already 10 or less, return as-is
    IF LEN(@TaxCode) <= 10
        RETURN LEFT(LTRIM(RTRIM(@TaxCode)), 10);
    
    -- Check mapping table first
    SELECT @Abbrev = TAX_CODE_ABBREV
    FROM dbo.USER_TAX_CODE_MAPPING
    WHERE TAX_CODE_FULL = @TaxCode
       OR TAX_CODE_ABBREV = @TaxCode;
    
    IF @Abbrev IS NOT NULL
        RETURN @Abbrev;
    
    -- Common abbreviations for Florida counties
    IF @TaxCode LIKE 'FL-BROWARD%'
        RETURN 'FL-BROWAR';
    IF @TaxCode LIKE 'FL-MIAMI-DADE%' OR @TaxCode LIKE 'FL-DADE%'
        RETURN 'FL-DADE';
    IF @TaxCode LIKE 'FL-PALM-BEACH%' OR @TaxCode LIKE 'FL-PALM BEACH%'
        RETURN 'FL-PALMB';
    IF @TaxCode LIKE 'FL-HILLSBOROUGH%'
        RETURN 'FL-HILLS';
    IF @TaxCode LIKE 'FL-ORANGE%'
        RETURN 'FL-ORANG';
    IF @TaxCode LIKE 'FL-PINELLAS%'
        RETURN 'FL-PINEL';
    IF @TaxCode LIKE 'FL-DUVAL%'
        RETURN 'FL-DUVAL';
    IF @TaxCode LIKE 'FL-BREVARD%'
        RETURN 'FL-BREVA';
    
    -- Generic abbreviation: take first 10 chars
    RETURN LEFT(LTRIM(RTRIM(@TaxCode)), 10);
END;
GO

PRINT 'Created fn_Abbreviate_Tax_Code function';
PRINT '';
PRINT 'Usage:';
PRINT '  SELECT dbo.fn_Abbreviate_Tax_Code(''FL-BROWARD'') AS Abbrev;';
PRINT '  -- Returns: FL-BROWAR';
PRINT '';
GO

-- Test the function
SELECT 
    'FL-BROWARD' AS Original,
    dbo.fn_Abbreviate_Tax_Code('FL-BROWARD') AS Abbreviated,
    LEN(dbo.fn_Abbreviate_Tax_Code('FL-BROWARD')) AS Length;
GO


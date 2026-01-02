-- ============================================
-- PREFLIGHT VALIDATION FOR STAGING TABLES
-- ============================================
-- Run this BEFORE calling usp_Create_Customers_From_Staging
-- to catch validation errors early and prevent constraint violations
--
-- Usage:
--   EXEC usp_Preflight_Validate_Customer_Staging @BatchID = 'BATCH_20241222_120000'
--   EXEC usp_Preflight_Validate_Customer_Staging @StagingID = 123
--   EXEC usp_Preflight_Validate_Customer_Staging  -- All records
--
-- Returns validation errors in a report format
-- ============================================

USE WOODYS_CP;  -- Production database
GO

-- ============================================
-- PREFLIGHT VALIDATION PROCEDURE
-- ============================================

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'usp_Preflight_Validate_Customer_Staging')
    DROP PROCEDURE dbo.usp_Preflight_Validate_Customer_Staging;
GO

CREATE PROCEDURE dbo.usp_Preflight_Validate_Customer_Staging
    @BatchID VARCHAR(50) = NULL,
    @StagingID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ErrorCount INT = 0;
    DECLARE @WarningCount INT = 0;
    
    PRINT '============================================';
    PRINT 'PREFLIGHT VALIDATION REPORT';
    PRINT '============================================';
    PRINT 'Validating: ' + ISNULL(@BatchID, ISNULL(CAST(@StagingID AS VARCHAR), 'ALL RECORDS'));
    PRINT '';
    
    -- ============================================
    -- 1. CUST_NAM_TYP VALIDATION
    -- ============================================
    PRINT '1. CUST_NAM_TYP Validation';
    PRINT '   ------------------------';
    
    -- Create temp table explicitly (no IDENTITY column)
    CREATE TABLE #CustNamTypErrors (
        STAGING_ID INT,
        BATCH_ID VARCHAR(50),
        ERROR_TYPE VARCHAR(100),
        FIELD_NAME VARCHAR(50),
        FIELD_VALUE VARCHAR(100)
    );
    
    -- Check for NULL values
    INSERT INTO #CustNamTypErrors (STAGING_ID, BATCH_ID, ERROR_TYPE, FIELD_NAME, FIELD_VALUE)
    SELECT 
        STAGING_ID,
        BATCH_ID,
        'CUST_NAM_TYP is NULL' AS ERROR_TYPE,
        'CUST_NAM_TYP' AS FIELD_NAME,
        NULL AS FIELD_VALUE
    FROM dbo.USER_CUSTOMER_STAGING
    WHERE (@BatchID IS NULL OR BATCH_ID = @BatchID)
      AND (@StagingID IS NULL OR STAGING_ID = @StagingID)
      AND CUST_NAM_TYP IS NULL;
    
    SET @ErrorCount = @ErrorCount + @@ROWCOUNT;
    
    -- Check for invalid values (must be 'B' or 'P')
    INSERT INTO #CustNamTypErrors (STAGING_ID, BATCH_ID, ERROR_TYPE, FIELD_NAME, FIELD_VALUE)
    SELECT 
        STAGING_ID,
        BATCH_ID,
        'CUST_NAM_TYP has invalid value: ' + ISNULL(CUST_NAM_TYP, 'NULL') AS ERROR_TYPE,
        'CUST_NAM_TYP' AS FIELD_NAME,
        CUST_NAM_TYP AS FIELD_VALUE
    FROM dbo.USER_CUSTOMER_STAGING
    WHERE (@BatchID IS NULL OR BATCH_ID = @BatchID)
      AND (@StagingID IS NULL OR STAGING_ID = @StagingID)
      AND CUST_NAM_TYP IS NOT NULL
      AND UPPER(LTRIM(RTRIM(CUST_NAM_TYP))) NOT IN ('B', 'P');
    
    SET @ErrorCount = @ErrorCount + @@ROWCOUNT;
    
    -- Check for trailing spaces or case issues
    INSERT INTO #CustNamTypErrors (STAGING_ID, BATCH_ID, ERROR_TYPE, FIELD_NAME, FIELD_VALUE)
    SELECT 
        STAGING_ID,
        BATCH_ID,
        'CUST_NAM_TYP has trailing spaces or wrong case' AS ERROR_TYPE,
        'CUST_NAM_TYP' AS FIELD_NAME,
        CUST_NAM_TYP AS FIELD_VALUE
    FROM dbo.USER_CUSTOMER_STAGING
    WHERE (@BatchID IS NULL OR BATCH_ID = @BatchID)
      AND (@StagingID IS NULL OR STAGING_ID = @StagingID)
      AND CUST_NAM_TYP IS NOT NULL
      AND (CUST_NAM_TYP <> LTRIM(RTRIM(CUST_NAM_TYP)) OR CUST_NAM_TYP <> UPPER(LTRIM(RTRIM(CUST_NAM_TYP))));
    
    SET @WarningCount = @WarningCount + @@ROWCOUNT;
    
    IF EXISTS (SELECT 1 FROM #CustNamTypErrors)
    BEGIN
        SELECT * FROM #CustNamTypErrors ORDER BY STAGING_ID;
    END
    ELSE
    BEGIN
        PRINT '   [OK] CUST_NAM_TYP validation passed';
    END
    
    PRINT '';
    
    -- ============================================
    -- 2. ADDRESS COMPLETENESS CHECKS
    -- ============================================
    PRINT '2. Address Completeness Validation';
    PRINT '   --------------------------------';
    
    -- Create temp table explicitly
    CREATE TABLE #AddressErrors (
        STAGING_ID INT,
        BATCH_ID VARCHAR(50),
        ERROR_TYPE VARCHAR(100),
        FIELD_NAME VARCHAR(50),
        FIELD_VALUE VARCHAR(100)
    );
    
    INSERT INTO #AddressErrors (STAGING_ID, BATCH_ID, ERROR_TYPE, FIELD_NAME, FIELD_VALUE)
    SELECT 
        STAGING_ID,
        BATCH_ID,
        CASE 
            WHEN ZIP_COD IS NULL OR LTRIM(RTRIM(ZIP_COD)) = '' THEN 'Missing ZIP_COD'
            WHEN STATE IS NULL OR LTRIM(RTRIM(STATE)) = '' THEN 'Missing STATE'
            WHEN CITY IS NULL OR LTRIM(RTRIM(CITY)) = '' THEN 'Missing CITY'
            WHEN ADRS_1 IS NULL OR LTRIM(RTRIM(ADRS_1)) = '' THEN 'Missing ADRS_1'
            ELSE NULL
        END AS ERROR_TYPE,
        CASE 
            WHEN ZIP_COD IS NULL OR LTRIM(RTRIM(ZIP_COD)) = '' THEN 'ZIP_COD'
            WHEN STATE IS NULL OR LTRIM(RTRIM(STATE)) = '' THEN 'STATE'
            WHEN CITY IS NULL OR LTRIM(RTRIM(CITY)) = '' THEN 'CITY'
            WHEN ADRS_1 IS NULL OR LTRIM(RTRIM(ADRS_1)) = '' THEN 'ADRS_1'
            ELSE NULL
        END AS FIELD_NAME,
        NULL AS FIELD_VALUE
    FROM dbo.USER_CUSTOMER_STAGING
    WHERE (@BatchID IS NULL OR BATCH_ID = @BatchID)
      AND (@StagingID IS NULL OR STAGING_ID = @StagingID)
      AND (
          ZIP_COD IS NULL OR LTRIM(RTRIM(ZIP_COD)) = ''
          OR STATE IS NULL OR LTRIM(RTRIM(STATE)) = ''
          OR CITY IS NULL OR LTRIM(RTRIM(CITY)) = ''
          OR ADRS_1 IS NULL OR LTRIM(RTRIM(ADRS_1)) = ''
      );
    
    SET @ErrorCount = @ErrorCount + @@ROWCOUNT;
    
    IF EXISTS (SELECT 1 FROM #AddressErrors)
    BEGIN
        SELECT * FROM #AddressErrors ORDER BY STAGING_ID;
    END
    ELSE
    BEGIN
        PRINT '   [OK] Address completeness validation passed';
    END
    
    PRINT '';
    
    -- ============================================
    -- 3. OVERLENGTH FIELD CHECKS
    -- ============================================
    PRINT '3. Field Length Validation';
    PRINT '   -----------------------';
    
    -- Create temp table explicitly
    CREATE TABLE #LengthErrors (
        STAGING_ID INT,
        BATCH_ID VARCHAR(50),
        ERROR_TYPE VARCHAR(100),
        FIELD_NAME VARCHAR(50),
        FIELD_VALUE VARCHAR(100)
    );
    
    INSERT INTO #LengthErrors (STAGING_ID, BATCH_ID, ERROR_TYPE, FIELD_NAME, FIELD_VALUE)
    SELECT 
        STAGING_ID,
        BATCH_ID,
        'Field exceeds maximum length' AS ERROR_TYPE,
        FIELD_NAME,
        FIELD_VALUE
    FROM (
        SELECT 
            STAGING_ID,
            BATCH_ID,
            'NAM' AS FIELD_NAME,
            NAM AS FIELD_VALUE,
            LEN(NAM) AS FIELD_LENGTH,
            40 AS MAX_LENGTH
        FROM dbo.USER_CUSTOMER_STAGING
        WHERE (@BatchID IS NULL OR BATCH_ID = @BatchID)
          AND (@StagingID IS NULL OR STAGING_ID = @StagingID)
          AND LEN(NAM) > 40
        
        UNION ALL
        
        SELECT 
            STAGING_ID,
            BATCH_ID,
            'FST_NAM' AS FIELD_NAME,
            FST_NAM AS FIELD_VALUE,
            LEN(FST_NAM) AS FIELD_LENGTH,
            15 AS MAX_LENGTH
        FROM dbo.USER_CUSTOMER_STAGING
        WHERE (@BatchID IS NULL OR BATCH_ID = @BatchID)
          AND (@StagingID IS NULL OR STAGING_ID = @StagingID)
          AND LEN(FST_NAM) > 15
        
        UNION ALL
        
        SELECT 
            STAGING_ID,
            BATCH_ID,
            'LST_NAM' AS FIELD_NAME,
            LST_NAM AS FIELD_VALUE,
            LEN(LST_NAM) AS FIELD_LENGTH,
            25 AS MAX_LENGTH
        FROM dbo.USER_CUSTOMER_STAGING
        WHERE (@BatchID IS NULL OR BATCH_ID = @BatchID)
          AND (@StagingID IS NULL OR STAGING_ID = @StagingID)
          AND LEN(LST_NAM) > 25
        
        UNION ALL
        
        SELECT 
            STAGING_ID,
            BATCH_ID,
            'EMAIL_ADRS_1' AS FIELD_NAME,
            EMAIL_ADRS_1 AS FIELD_VALUE,
            LEN(EMAIL_ADRS_1) AS FIELD_LENGTH,
            50 AS MAX_LENGTH
        FROM dbo.USER_CUSTOMER_STAGING
        WHERE (@BatchID IS NULL OR BATCH_ID = @BatchID)
          AND (@StagingID IS NULL OR STAGING_ID = @StagingID)
          AND LEN(EMAIL_ADRS_1) > 50
        
        UNION ALL
        
        SELECT 
            STAGING_ID,
            BATCH_ID,
            'ADRS_1' AS FIELD_NAME,
            ADRS_1 AS FIELD_VALUE,
            LEN(ADRS_1) AS FIELD_LENGTH,
            40 AS MAX_LENGTH
        FROM dbo.USER_CUSTOMER_STAGING
        WHERE (@BatchID IS NULL OR BATCH_ID = @BatchID)
          AND (@StagingID IS NULL OR STAGING_ID = @StagingID)
          AND LEN(ADRS_1) > 40
        
        UNION ALL
        
        SELECT 
            STAGING_ID,
            BATCH_ID,
            'ADRS_2' AS FIELD_NAME,
            ADRS_2 AS FIELD_VALUE,
            LEN(ADRS_2) AS FIELD_LENGTH,
            40 AS MAX_LENGTH
        FROM dbo.USER_CUSTOMER_STAGING
        WHERE (@BatchID IS NULL OR BATCH_ID = @BatchID)
          AND (@StagingID IS NULL OR STAGING_ID = @StagingID)
          AND LEN(ADRS_2) > 40
        
        UNION ALL
        
        SELECT 
            STAGING_ID,
            BATCH_ID,
            'CITY' AS FIELD_NAME,
            CITY AS FIELD_VALUE,
            LEN(CITY) AS FIELD_LENGTH,
            20 AS MAX_LENGTH
        FROM dbo.USER_CUSTOMER_STAGING
        WHERE (@BatchID IS NULL OR BATCH_ID = @BatchID)
          AND (@StagingID IS NULL OR STAGING_ID = @StagingID)
          AND LEN(CITY) > 20
        
        UNION ALL
        
        SELECT 
            STAGING_ID,
            BATCH_ID,
            'STATE' AS FIELD_NAME,
            STATE AS FIELD_VALUE,
            LEN(STATE) AS FIELD_LENGTH,
            10 AS MAX_LENGTH
        FROM dbo.USER_CUSTOMER_STAGING
        WHERE (@BatchID IS NULL OR BATCH_ID = @BatchID)
          AND (@StagingID IS NULL OR STAGING_ID = @StagingID)
          AND LEN(STATE) > 10
        
        UNION ALL
        
        SELECT 
            STAGING_ID,
            BATCH_ID,
            'ZIP_COD' AS FIELD_NAME,
            ZIP_COD AS FIELD_VALUE,
            LEN(ZIP_COD) AS FIELD_LENGTH,
            15 AS MAX_LENGTH
        FROM dbo.USER_CUSTOMER_STAGING
        WHERE (@BatchID IS NULL OR BATCH_ID = @BatchID)
          AND (@StagingID IS NULL OR STAGING_ID = @StagingID)
          AND LEN(ZIP_COD) > 15
    ) AS LengthChecks
    WHERE FIELD_LENGTH > MAX_LENGTH;
    
    SET @ErrorCount = @ErrorCount + @@ROWCOUNT;
    
    IF EXISTS (SELECT 1 FROM #LengthErrors)
    BEGIN
        SELECT 
            STAGING_ID,
            BATCH_ID,
            ERROR_TYPE + ': ' + FIELD_NAME + ' (' + CAST(LEN(FIELD_VALUE) AS VARCHAR) + ' chars, max ' + CAST(MAX_LENGTH AS VARCHAR) + ')' AS ERROR_TYPE,
            FIELD_NAME,
            LEFT(FIELD_VALUE, 50) AS FIELD_VALUE
        FROM #LengthErrors
        ORDER BY STAGING_ID, FIELD_NAME;
    END
    ELSE
    BEGIN
        PRINT '   [OK] Field length validation passed';
    END
    
    PRINT '';
    
    -- ============================================
    -- 4. TIER VALUE SANITY CHECKS
    -- ============================================
    PRINT '4. Tier Value (PROF_COD_1) Validation';
    PRINT '   -----------------------------------';
    
    -- Valid tier values
    DECLARE @ValidTiers TABLE (TIER_VALUE VARCHAR(10));
    INSERT INTO @ValidTiers VALUES ('TIER1'), ('TIER2'), ('TIER3'), ('TIER4'), ('TIER5'), 
                                   ('RESELLER'), ('RETAIL'), ('GOV TIER1'), ('GOV TIER2'), ('GOV TIER3');
    
    -- Create temp table explicitly (already created above, but ensure it exists)
    IF OBJECT_ID('tempdb..#TierErrors') IS NULL
    BEGIN
        CREATE TABLE #TierErrors (
            STAGING_ID INT,
            BATCH_ID VARCHAR(50),
            ERROR_TYPE VARCHAR(100),
            FIELD_NAME VARCHAR(50),
            FIELD_VALUE VARCHAR(100)
        );
    END
    
    INSERT INTO #TierErrors (STAGING_ID, BATCH_ID, ERROR_TYPE, FIELD_NAME, FIELD_VALUE)
    SELECT 
        STAGING_ID,
        BATCH_ID,
        'PROF_COD_1 has invalid tier value: ' + ISNULL(PROF_COD_1, 'NULL') AS ERROR_TYPE,
        'PROF_COD_1' AS FIELD_NAME,
        PROF_COD_1 AS FIELD_VALUE
    FROM dbo.USER_CUSTOMER_STAGING s
    WHERE (@BatchID IS NULL OR BATCH_ID = @BatchID)
      AND (@StagingID IS NULL OR STAGING_ID = @StagingID)
      AND PROF_COD_1 IS NOT NULL
      AND UPPER(LTRIM(RTRIM(PROF_COD_1))) NOT IN (SELECT TIER_VALUE FROM @ValidTiers);
    
    SET @ErrorCount = @ErrorCount + @@ROWCOUNT;
    
    -- Check for trailing spaces or case mismatch
    INSERT INTO #TierErrors (STAGING_ID, BATCH_ID, ERROR_TYPE, FIELD_NAME, FIELD_VALUE)
    SELECT 
        STAGING_ID,
        BATCH_ID,
        'PROF_COD_1 has trailing spaces or wrong case' AS ERROR_TYPE,
        'PROF_COD_1' AS FIELD_NAME,
        PROF_COD_1 AS FIELD_VALUE
    FROM dbo.USER_CUSTOMER_STAGING
    WHERE (@BatchID IS NULL OR BATCH_ID = @BatchID)
      AND (@StagingID IS NULL OR STAGING_ID = @StagingID)
      AND PROF_COD_1 IS NOT NULL
      AND PROF_COD_1 <> LTRIM(RTRIM(PROF_COD_1));
    
    SET @WarningCount = @WarningCount + @@ROWCOUNT;
    
    IF EXISTS (SELECT 1 FROM #TierErrors)
    BEGIN
        SELECT * FROM #TierErrors ORDER BY STAGING_ID;
    END
    ELSE
    BEGIN
        PRINT '   [OK] Tier value validation passed';
    END
    
    PRINT '';
    
    -- ============================================
    -- 5. TRAILING SPACES / CASE MISMATCH CHECKS
    -- ============================================
    PRINT '5. Trailing Spaces / Case Validation';
    PRINT '   ----------------------------------';
    
    -- Create temp table explicitly
    CREATE TABLE #TrailingSpaceErrors (
        STAGING_ID INT,
        BATCH_ID VARCHAR(50),
        ERROR_TYPE VARCHAR(100),
        FIELD_NAME VARCHAR(50),
        FIELD_VALUE VARCHAR(100)
    );
    
    INSERT INTO #TrailingSpaceErrors (STAGING_ID, BATCH_ID, ERROR_TYPE, FIELD_NAME, FIELD_VALUE)
    SELECT 
        STAGING_ID,
        BATCH_ID,
        'Field has trailing spaces: ' + FIELD_NAME AS ERROR_TYPE,
        FIELD_NAME,
        FIELD_VALUE
    FROM (
        SELECT STAGING_ID, BATCH_ID, 'CUST_NAM_TYP' AS FIELD_NAME, CUST_NAM_TYP AS FIELD_VALUE
        FROM dbo.USER_CUSTOMER_STAGING
        WHERE (@BatchID IS NULL OR BATCH_ID = @BatchID)
          AND (@StagingID IS NULL OR STAGING_ID = @StagingID)
          AND CUST_NAM_TYP IS NOT NULL
          AND CUST_NAM_TYP <> LTRIM(RTRIM(CUST_NAM_TYP))
        
        UNION ALL
        
        SELECT STAGING_ID, BATCH_ID, 'PROF_COD_1' AS FIELD_NAME, PROF_COD_1 AS FIELD_VALUE
        FROM dbo.USER_CUSTOMER_STAGING
        WHERE (@BatchID IS NULL OR BATCH_ID = @BatchID)
          AND (@StagingID IS NULL OR STAGING_ID = @StagingID)
          AND PROF_COD_1 IS NOT NULL
          AND PROF_COD_1 <> LTRIM(RTRIM(PROF_COD_1))
        
        UNION ALL
        
        SELECT STAGING_ID, BATCH_ID, 'CATEG_COD' AS FIELD_NAME, CATEG_COD AS FIELD_VALUE
        FROM dbo.USER_CUSTOMER_STAGING
        WHERE (@BatchID IS NULL OR BATCH_ID = @BatchID)
          AND (@StagingID IS NULL OR STAGING_ID = @StagingID)
          AND CATEG_COD IS NOT NULL
          AND CATEG_COD <> LTRIM(RTRIM(CATEG_COD))
    ) AS TrailingSpaceChecks;
    
    SET @WarningCount = @WarningCount + @@ROWCOUNT;
    
    IF EXISTS (SELECT 1 FROM #TrailingSpaceErrors)
    BEGIN
        SELECT * FROM #TrailingSpaceErrors ORDER BY STAGING_ID, FIELD_NAME;
    END
    ELSE
    BEGIN
        PRINT '   [OK] Trailing spaces validation passed';
    END
    
    PRINT '';
    
    -- ============================================
    -- SUMMARY
    -- ============================================
    PRINT '============================================';
    PRINT 'VALIDATION SUMMARY';
    PRINT '============================================';
    PRINT 'Errors:   ' + CAST(@ErrorCount AS VARCHAR);
    PRINT 'Warnings: ' + CAST(@WarningCount AS VARCHAR);
    PRINT '';
    
    IF @ErrorCount > 0
    BEGIN
        PRINT '❌ VALIDATION FAILED - Fix errors before running usp_Create_Customers_From_Staging';
        PRINT '';
        PRINT 'To fix errors, update USER_CUSTOMER_STAGING table:';
        PRINT '  UPDATE dbo.USER_CUSTOMER_STAGING';
        PRINT '  SET [FIELD_NAME] = [CORRECTED_VALUE]';
        PRINT '  WHERE STAGING_ID = [ID];';
    END
    ELSE IF @WarningCount > 0
    BEGIN
        PRINT '⚠️  VALIDATION PASSED WITH WARNINGS - Review warnings above';
    END
    ELSE
    BEGIN
        PRINT '✅ VALIDATION PASSED - Ready to run usp_Create_Customers_From_Staging';
    END
    
    PRINT '============================================';
    
    -- Cleanup temp tables
    DROP TABLE IF EXISTS #CustNamTypErrors;
    DROP TABLE IF EXISTS #AddressErrors;
    DROP TABLE IF EXISTS #LengthErrors;
    DROP TABLE IF EXISTS #TierErrors;
    DROP TABLE IF EXISTS #TrailingSpaceErrors;
    
END
GO

PRINT 'Preflight validation procedure created successfully';
PRINT 'Usage: EXEC usp_Preflight_Validate_Customer_Staging @BatchID = ''YOUR_BATCH_ID''';
GO


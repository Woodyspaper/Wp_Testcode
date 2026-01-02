USE WOODYS_CP;
GO

-- ============================================
-- FIND THE EXACT FIELD CAUSING TRUNCATION
-- ============================================

-- Compare staging data to AR_CUST column limits
SELECT 
    'FIELD TOO LONG' AS Issue,
    s.STAGING_ID,
    s.BATCH_ID,
    CASE
        WHEN LEN(ISNULL(s.NAM, '')) > 40 THEN 'NAM: ' + CAST(LEN(s.NAM) AS VARCHAR) + ' chars (max 40)'
        WHEN LEN(ISNULL(s.FST_NAM, '')) > 15 THEN 'FST_NAM: ' + CAST(LEN(s.FST_NAM) AS VARCHAR) + ' chars (max 15)'
        WHEN LEN(ISNULL(s.LST_NAM, '')) > 25 THEN 'LST_NAM: ' + CAST(LEN(s.LST_NAM) AS VARCHAR) + ' chars (max 25)'
        WHEN LEN(ISNULL(s.EMAIL_ADRS_1, '')) > 50 THEN 'EMAIL_ADRS_1: ' + CAST(LEN(s.EMAIL_ADRS_1) AS VARCHAR) + ' chars (max 50)'
        WHEN LEN(ISNULL(s.ADRS_1, '')) > 40 THEN 'ADRS_1: ' + CAST(LEN(s.ADRS_1) AS VARCHAR) + ' chars (max 40)'
        WHEN LEN(ISNULL(s.ADRS_2, '')) > 40 THEN 'ADRS_2: ' + CAST(LEN(s.ADRS_2) AS VARCHAR) + ' chars (max 40)'
        WHEN LEN(ISNULL(s.ADRS_3, '')) > 40 THEN 'ADRS_3: ' + CAST(LEN(s.ADRS_3) AS VARCHAR) + ' chars (max 40)'
        WHEN LEN(ISNULL(s.CITY, '')) > 20 THEN 'CITY: ' + CAST(LEN(s.CITY) AS VARCHAR) + ' chars (max 20)'
        WHEN LEN(ISNULL(s.STATE, '')) > 10 THEN 'STATE: ' + CAST(LEN(s.STATE) AS VARCHAR) + ' chars (max 10)'
        WHEN LEN(ISNULL(s.ZIP_COD, '')) > 15 THEN 'ZIP_COD: ' + CAST(LEN(s.ZIP_COD) AS VARCHAR) + ' chars (max 15)'
        WHEN LEN(ISNULL(s.CNTRY, '')) > 20 THEN 'CNTRY: ' + CAST(LEN(s.CNTRY) AS VARCHAR) + ' chars (max 20)'
        WHEN LEN(ISNULL(s.PROF_COD_1, '')) > 10 THEN 'PROF_COD_1: ' + CAST(LEN(s.PROF_COD_1) AS VARCHAR) + ' chars (max 10)'
        WHEN LEN(ISNULL(s.TAX_COD, '')) > 10 THEN 'TAX_COD: ' + CAST(LEN(s.TAX_COD) AS VARCHAR) + ' chars (max 10)'
        WHEN LEN(ISNULL(s.CATEG_COD, '')) > 10 THEN 'CATEG_COD: ' + CAST(LEN(s.CATEG_COD) AS VARCHAR) + ' chars (max 10)'
        WHEN LEN(ISNULL(s.SLS_REP, '')) > 10 THEN 'SLS_REP: ' + CAST(LEN(s.SLS_REP) AS VARCHAR) + ' chars (max 10)'
        WHEN LEN(ISNULL(s.SHIP_VIA_COD, '')) > 10 THEN 'SHIP_VIA_COD: ' + CAST(LEN(s.SHIP_VIA_COD) AS VARCHAR) + ' chars (max 10)'
        WHEN LEN(ISNULL(s.SHIP_ZONE_COD, '')) > 10 THEN 'SHIP_ZONE_COD: ' + CAST(LEN(s.SHIP_ZONE_COD) AS VARCHAR) + ' chars (max 10)'
        WHEN LEN(ISNULL(s.STMNT_COD, '')) > 10 THEN 'STMNT_COD: ' + CAST(LEN(s.STMNT_COD) AS VARCHAR) + ' chars (max 10)'
        WHEN LEN(ISNULL(s.COMMNT, '')) > 50 THEN 'COMMNT: ' + CAST(LEN(s.COMMNT) AS VARCHAR) + ' chars (max 50)'
        ELSE 'NO ISSUE FOUND IN STAGING DATA'
    END AS ProblemField
FROM dbo.USER_CUSTOMER_STAGING s
WHERE s.BATCH_ID = 'TEST_BATCH_001'
  AND (
    LEN(ISNULL(s.NAM, '')) > 40
    OR LEN(ISNULL(s.FST_NAM, '')) > 15
    OR LEN(ISNULL(s.LST_NAM, '')) > 25
    OR LEN(ISNULL(s.EMAIL_ADRS_1, '')) > 50
    OR LEN(ISNULL(s.ADRS_1, '')) > 40
    OR LEN(ISNULL(s.ADRS_2, '')) > 40
    OR LEN(ISNULL(s.ADRS_3, '')) > 40
    OR LEN(ISNULL(s.CITY, '')) > 20
    OR LEN(ISNULL(s.STATE, '')) > 10
    OR LEN(ISNULL(s.ZIP_COD, '')) > 15
    OR LEN(ISNULL(s.CNTRY, '')) > 20
    OR LEN(ISNULL(s.PROF_COD_1, '')) > 10
    OR LEN(ISNULL(s.TAX_COD, '')) > 10
    OR LEN(ISNULL(s.CATEG_COD, '')) > 10
    OR LEN(ISNULL(s.SLS_REP, '')) > 10
    OR LEN(ISNULL(s.SHIP_VIA_COD, '')) > 10
    OR LEN(ISNULL(s.SHIP_ZONE_COD, '')) > 10
    OR LEN(ISNULL(s.STMNT_COD, '')) > 10
    OR LEN(ISNULL(s.COMMNT, '')) > 50
  );

-- Check LST_MAINT_USR_ID length in AR_CUST
SELECT 
    'LST_MAINT_USR_ID Length Check' AS CheckType,
    COLUMN_NAME,
    CHARACTER_MAXIMUM_LENGTH AS MAX_LENGTH,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'AR_CUST'
  AND COLUMN_NAME = 'LST_MAINT_USR_ID';

GO


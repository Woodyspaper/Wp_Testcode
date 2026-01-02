-- ============================================
-- Diagnose Truncation Error
-- Find which field is causing the issue
-- ============================================

USE WOODYS_CP;  -- or CPPractice if testing
GO

PRINT '============================================';
PRINT 'DIAGNOSING TRUNCATION ERROR';
PRINT '============================================';
PRINT '';

-- Check the test record and all field lengths
SELECT 
    'NAM' AS FIELD_NAME,
    LEN(ISNULL(NAM, '')) AS FIELD_LENGTH,
    40 AS MAX_LENGTH,
    CASE WHEN LEN(ISNULL(NAM, '')) > 40 THEN '❌ TOO LONG' ELSE '✅ OK' END AS STATUS,
    NAM AS FIELD_VALUE
FROM dbo.USER_CUSTOMER_STAGING
WHERE BATCH_ID = 'TEST_BATCH_001'

UNION ALL

SELECT 
    'ADRS_1',
    LEN(ISNULL(ADRS_1, '')),
    40,
    CASE WHEN LEN(ISNULL(ADRS_1, '')) > 40 THEN '❌ TOO LONG' ELSE '✅ OK' END,
    ADRS_1
FROM dbo.USER_CUSTOMER_STAGING
WHERE BATCH_ID = 'TEST_BATCH_001'

UNION ALL

SELECT 
    'CITY',
    LEN(ISNULL(CITY, '')),
    20,
    CASE WHEN LEN(ISNULL(CITY, '')) > 20 THEN '❌ TOO LONG' ELSE '✅ OK' END,
    CITY
FROM dbo.USER_CUSTOMER_STAGING
WHERE BATCH_ID = 'TEST_BATCH_001'

UNION ALL

SELECT 
    'STATE',
    LEN(ISNULL(STATE, '')),
    10,
    CASE WHEN LEN(ISNULL(STATE, '')) > 10 THEN '❌ TOO LONG' ELSE '✅ OK' END,
    STATE
FROM dbo.USER_CUSTOMER_STAGING
WHERE BATCH_ID = 'TEST_BATCH_001'

UNION ALL

SELECT 
    'ZIP_COD',
    LEN(ISNULL(ZIP_COD, '')),
    15,
    CASE WHEN LEN(ISNULL(ZIP_COD, '')) > 15 THEN '❌ TOO LONG' ELSE '✅ OK' END,
    ZIP_COD
FROM dbo.USER_CUSTOMER_STAGING
WHERE BATCH_ID = 'TEST_BATCH_001'

UNION ALL

SELECT 
    'EMAIL_ADRS_1',
    LEN(ISNULL(EMAIL_ADRS_1, '')),
    50,
    CASE WHEN LEN(ISNULL(EMAIL_ADRS_1, '')) > 50 THEN '❌ TOO LONG' ELSE '✅ OK' END,
    EMAIL_ADRS_1
FROM dbo.USER_CUSTOMER_STAGING
WHERE BATCH_ID = 'TEST_BATCH_001'

UNION ALL

SELECT 
    'PROF_COD_1',
    LEN(ISNULL(PROF_COD_1, '')),
    10,
    CASE WHEN LEN(ISNULL(PROF_COD_1, '')) > 10 THEN '❌ TOO LONG' ELSE '✅ OK' END,
    PROF_COD_1
FROM dbo.USER_CUSTOMER_STAGING
WHERE BATCH_ID = 'TEST_BATCH_001'

UNION ALL

SELECT 
    'TAX_COD',
    LEN(ISNULL(TAX_COD, '')),
    10,
    CASE WHEN LEN(ISNULL(TAX_COD, '')) > 10 THEN '❌ TOO LONG' ELSE '✅ OK' END,
    TAX_COD
FROM dbo.USER_CUSTOMER_STAGING
WHERE BATCH_ID = 'TEST_BATCH_001'

UNION ALL

SELECT 
    'CATEG_COD',
    LEN(ISNULL(CATEG_COD, '')),
    10,
    CASE WHEN LEN(ISNULL(CATEG_COD, '')) > 10 THEN '❌ TOO LONG' ELSE '✅ OK' END,
    CATEG_COD
FROM dbo.USER_CUSTOMER_STAGING
WHERE BATCH_ID = 'TEST_BATCH_001';
GO

PRINT '';
PRINT '============================================';
PRINT 'CHECKING PROCEDURE DEFAULT VALUES';
PRINT '============================================';
PRINT '';

-- Check the procedure definition for default values
DECLARE @ProcText NVARCHAR(MAX);
SELECT @ProcText = OBJECT_DEFINITION(OBJECT_ID('dbo.usp_Create_Customers_From_Staging'));

PRINT 'Checking procedure defaults...';
PRINT '';

IF @ProcText LIKE '%@DefaultTAX_COD VARCHAR(10) = ''FL-BROWARD''%'
BEGIN
    PRINT '❌ @DefaultTAX_COD = ''FL-BROWARD'' (11 chars - TOO LONG!)';
END
ELSE IF @ProcText LIKE '%@DefaultTAX_COD VARCHAR(10) = ''FL-BROWAR''%'
BEGIN
    PRINT '✅ @DefaultTAX_COD = ''FL-BROWAR'' (10 chars - CORRECT)';
END
ELSE
BEGIN
    PRINT '⚠️ Could not determine @DefaultTAX_COD value';
END
GO

PRINT '';
PRINT 'If any field shows ❌ TOO LONG, that is the problem!';
PRINT '============================================';
GO


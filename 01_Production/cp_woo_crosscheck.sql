/*
================================================================================
CP ↔ Woo Cross-Check (REPORT, optional mapping create)
Now exposed as a stored procedure for automation.
================================================================================
*/

CREATE OR ALTER PROCEDURE dbo.usp_CP_Woo_Crosscheck
    @BatchID VARCHAR(50),
    @ApplyMappings BIT = 0  -- 0 = report only, 1 = create mappings
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '============================================';
    PRINT 'CP ↔ Woo Cross-Check';
    PRINT 'Batch ID: ' + ISNULL(@BatchID, '(NULL)');
    PRINT 'Apply mappings: ' + CASE WHEN @ApplyMappings = 1 THEN 'YES' ELSE 'NO (report only)' END;
    PRINT '============================================';
    PRINT '';

    /* 1) Woo staging rows for this batch (for reference) */
    PRINT '1) Woo staging rows (batch scope check):';
    SELECT TOP 5 BATCH_ID, COUNT(*) AS RowsInBatch
    FROM dbo.USER_CUSTOMER_STAGING
    GROUP BY BATCH_ID
    ORDER BY BATCH_ID DESC;
    PRINT '';

    /* 2) Woo -> CP: staged Woo customers NOT found in CP (candidates to create) */
    PRINT '2) Woo customers staged in batch but NOT found in CP (by email):';
    SELECT TOP 50
        s.STAGING_ID,
        s.WOO_USER_ID,
        s.EMAIL_ADRS_1 AS WooEmail,
        s.NAM          AS WooName,
        s.PHONE_1      AS WooPhone,
        s.ADRS_1       AS WooAddr1,
        s.CITY         AS WooCity,
        s.STATE        AS WooState,
        s.ZIP_COD      AS WooZip
    FROM dbo.USER_CUSTOMER_STAGING s
    LEFT JOIN dbo.AR_CUST c
        ON LOWER(LTRIM(RTRIM(c.EMAIL_ADRS_1))) = LOWER(LTRIM(RTRIM(s.EMAIL_ADRS_1)))
    WHERE s.BATCH_ID = @BatchID
      AND c.CUST_NO IS NULL
    ORDER BY s.STAGING_ID;
    PRINT '';

    /* 3) CP -> Woo: CP customers with no mapping and no email match in this batch */
    PRINT '3) CP customers with NO mapping and NO email match in this batch (likely no online account):';
    SELECT TOP 50
        c.CUST_NO,
        c.NAM          AS CPName,
        c.EMAIL_ADRS_1 AS CPEmail,
        c.PHONE_1      AS CPPhone,
        c.CITY         AS CPCity,
        c.STATE        AS CPState
    FROM dbo.AR_CUST c
    LEFT JOIN dbo.USER_CUSTOMER_MAP m ON m.CUST_NO = c.CUST_NO AND m.IS_ACTIVE = 1
    LEFT JOIN dbo.USER_CUSTOMER_STAGING s
        ON s.BATCH_ID = @BatchID
       AND LOWER(LTRIM(RTRIM(s.EMAIL_ADRS_1))) = LOWER(LTRIM(RTRIM(c.EMAIL_ADRS_1)))
    WHERE m.MAP_ID IS NULL      -- no mapping
      AND s.STAGING_ID IS NULL  -- no email match in this batch
      AND c.EMAIL_ADRS_1 IS NOT NULL
    ORDER BY c.CUST_NO;
    PRINT '';

    /* 4) Matched by email but missing mapping (Woo staged vs CP) */
    PRINT '4) Matched by email but missing mapping (eligible to map):';
    ;WITH Matched AS (
        SELECT
            s.STAGING_ID,
            s.WOO_USER_ID,
            s.EMAIL_ADRS_1 AS WooEmail,
            c.CUST_NO,
            c.NAM AS CPName
        FROM dbo.USER_CUSTOMER_STAGING s
        INNER JOIN dbo.AR_CUST c
            ON LOWER(LTRIM(RTRIM(c.EMAIL_ADRS_1))) = LOWER(LTRIM(RTRIM(s.EMAIL_ADRS_1)))
        LEFT JOIN dbo.USER_CUSTOMER_MAP m
            ON m.CUST_NO = c.CUST_NO
           AND m.WOO_USER_ID = s.WOO_USER_ID
           AND m.IS_ACTIVE = 1
        WHERE s.BATCH_ID = @BatchID
          AND s.WOO_USER_ID IS NOT NULL      -- only registered Woo users
          AND m.MAP_ID IS NULL               -- no mapping yet
    )
    SELECT TOP 50 * FROM Matched ORDER BY STAGING_ID;
    PRINT '';

    /* 5) Optionally create mappings for the matched set */
    IF @ApplyMappings = 1
    BEGIN
        PRINT '5) Creating mappings for matched set...';
        INSERT INTO dbo.USER_CUSTOMER_MAP (CUST_NO, WOO_USER_ID, WOO_EMAIL, MAPPING_SOURCE, IS_ACTIVE, CREATED_DT, CREATED_BY)
        SELECT
            m.CUST_NO,
            m.WOO_USER_ID,
            m.WooEmail,
            'AUTO',
            1,
            GETDATE(),
            SYSTEM_USER
        FROM (
            SELECT DISTINCT
                s.WOO_USER_ID,
                s.EMAIL_ADRS_1 AS WooEmail,
                c.CUST_NO
            FROM dbo.USER_CUSTOMER_STAGING s
            INNER JOIN dbo.AR_CUST c
                ON LOWER(LTRIM(RTRIM(c.EMAIL_ADRS_1))) = LOWER(LTRIM(RTRIM(s.EMAIL_ADRS_1)))
            LEFT JOIN dbo.USER_CUSTOMER_MAP m
                ON m.CUST_NO = c.CUST_NO
               AND m.WOO_USER_ID = s.WOO_USER_ID
               AND m.IS_ACTIVE = 1
            WHERE s.BATCH_ID = @BatchID
              AND s.WOO_USER_ID IS NOT NULL
              AND m.MAP_ID IS NULL
        ) m;

        DECLARE @NewMaps INT = @@ROWCOUNT;
        PRINT '   -> Created mappings: ' + CAST(@NewMaps AS VARCHAR);
    END
    ELSE
    BEGIN
        PRINT '5) Skipped mapping creation (report-only). Set @ApplyMappings = 1 to create.';
    END
    PRINT '';

    /* 6) Summary counts */
    PRINT '6) Summary counts:';
    SELECT
        (SELECT COUNT(*) FROM dbo.USER_CUSTOMER_STAGING WHERE BATCH_ID = @BatchID) AS StagedTotal,
        (SELECT COUNT(*) FROM dbo.USER_CUSTOMER_STAGING s
            LEFT JOIN dbo.AR_CUST c ON LOWER(LTRIM(RTRIM(c.EMAIL_ADRS_1))) = LOWER(LTRIM(RTRIM(s.EMAIL_ADRS_1)))
            WHERE s.BATCH_ID = @BatchID AND c.CUST_NO IS NULL) AS StagedNotInCP,
        (SELECT COUNT(*) FROM dbo.AR_CUST c
            LEFT JOIN dbo.USER_CUSTOMER_MAP m ON m.CUST_NO = c.CUST_NO AND m.IS_ACTIVE = 1
            WHERE m.MAP_ID IS NULL AND c.EMAIL_ADRS_1 IS NOT NULL) AS CP_NoMapping,
        (SELECT COUNT(*) FROM dbo.USER_CUSTOMER_MAP) AS TotalMappings;
    PRINT '';

    PRINT '============================================';
    PRINT 'END OF CP ↔ Woo CROSS-CHECK';
    PRINT '============================================';
END
GO

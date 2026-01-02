-- ============================================
-- CHECK SQL SERVER COMPATIBILITY LEVEL
-- ============================================
-- Purpose: Check if database supports OPENJSON (requires compatibility level 130+)
-- ============================================

USE WOODYS_CP;
GO

-- Check SQL Server version
SELECT 
    @@VERSION AS SQLServerVersion,
    SERVERPROPERTY('ProductVersion') AS ProductVersion,
    SERVERPROPERTY('ProductLevel') AS ProductLevel,
    SERVERPROPERTY('Edition') AS Edition;

-- Check database compatibility level
SELECT 
    name AS DatabaseName,
    compatibility_level AS CompatibilityLevel,
    CASE 
        WHEN compatibility_level >= 130 THEN 'Supports OPENJSON (SQL Server 2016+)'
        WHEN compatibility_level >= 120 THEN 'SQL Server 2014'
        WHEN compatibility_level >= 110 THEN 'SQL Server 2012'
        WHEN compatibility_level >= 100 THEN 'SQL Server 2008'
        ELSE 'Older version'
    END AS VersionInfo
FROM sys.databases
WHERE name = DB_NAME();

-- Test OPENJSON availability
BEGIN TRY
    DECLARE @TestJSON NVARCHAR(MAX) = '[{"test": "value"}]';
    SELECT * FROM OPENJSON(@TestJSON);
    PRINT 'OPENJSON is available';
END TRY
BEGIN CATCH
    PRINT 'OPENJSON is NOT available: ' + ERROR_MESSAGE();
END CATCH
GO

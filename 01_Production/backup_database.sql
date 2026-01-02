-- ============================================
-- BACKUP WOODYS_CP DATABASE
-- Run this BEFORE deploying the pipeline
-- ============================================

USE master;
GO

-- Create backup with timestamp
DECLARE @BackupPath NVARCHAR(500);
DECLARE @BackupName NVARCHAR(500);
DECLARE @Timestamp VARCHAR(20);

SET @Timestamp = CONVERT(VARCHAR, GETDATE(), 112) + '_' + 
                 REPLACE(CONVERT(VARCHAR, GETDATE(), 108), ':', '');
SET @BackupPath = 'C:\Backups\WOODYS_CP_PreDeployment_' + @Timestamp + '.bak';
SET @BackupName = 'WOODYS_CP Full Backup - ' + CONVERT(VARCHAR, GETDATE(), 120);

PRINT '============================================';
PRINT 'BACKING UP WOODYS_CP DATABASE';
PRINT '============================================';
PRINT 'Backup Path: ' + @BackupPath;
PRINT 'Backup Name: ' + @BackupName;
PRINT 'Starting backup...';
PRINT '';

-- Perform the backup
-- Note: COMPRESSION removed for SQL Server Express compatibility
BACKUP DATABASE WOODYS_CP 
TO DISK = @BackupPath
WITH 
    FORMAT,                    -- Overwrite existing media
    INIT,                      -- Initialize backup set
    NAME = @BackupName,
    DESCRIPTION = 'Full backup before pipeline deployment',
    STATS = 10;                -- Show progress every 10%

PRINT '';
PRINT '============================================';
PRINT 'BACKUP COMPLETE';
PRINT '============================================';
PRINT 'Backup saved to: ' + @BackupPath;
PRINT '';
PRINT 'To restore this backup:';
PRINT '  RESTORE DATABASE WOODYS_CP FROM DISK = ''' + @BackupPath + ''' WITH REPLACE;';
PRINT '============================================';
GO

-- Check backup file size
DECLARE @BackupPath NVARCHAR(500);
DECLARE @Timestamp VARCHAR(20);
DECLARE @FileSizeMB DECIMAL(10,2);

SET @Timestamp = CONVERT(VARCHAR, GETDATE(), 112) + '_' + 
                 REPLACE(CONVERT(VARCHAR, GETDATE(), 108), ':', '');
SET @BackupPath = 'C:\Backups\WOODYS_CP_PreDeployment_' + @Timestamp + '.bak';

-- Get file size from backup history
SELECT TOP 1 
    @FileSizeMB = backup_size / 1024.0 / 1024.0
FROM msdb.dbo.backupset
WHERE database_name = 'WOODYS_CP'
  AND backup_start_date >= DATEADD(MINUTE, -5, GETDATE())
ORDER BY backup_start_date DESC;

IF @FileSizeMB IS NOT NULL
BEGIN
    PRINT '✅ Backup verified';
    PRINT '   File Size: ' + CAST(@FileSizeMB AS VARCHAR) + ' MB';
    PRINT '   Location: ' + @BackupPath;
END
ELSE
BEGIN
    PRINT '⚠️ Could not verify backup. Check manually:';
    PRINT '   ' + @BackupPath;
    PRINT '   Make sure C:\Backups\ folder exists!';
END
GO


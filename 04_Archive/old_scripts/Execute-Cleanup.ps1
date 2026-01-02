# Execute-Cleanup.ps1
# Aggressive cleanup - Only keep essential files for pipeline operation
# Archives everything else, deletes obsolete files

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "WP_Testcode Aggressive Cleanup" -ForegroundColor Cyan
Write-Host "Only keeping essential pipeline files" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Create archive structure
$archiveRoot = Join-Path $scriptDir "04_Archive"
$archiveHistorical = Join-Path $archiveRoot "historical"
$archiveScripts = Join-Path $archiveRoot "old_scripts"
$archiveSQL = Join-Path $archiveRoot "sql_files"
$archiveDocs = Join-Path $archiveRoot "documentation"

New-Item -ItemType Directory -Force -Path $archiveRoot | Out-Null
New-Item -ItemType Directory -Force -Path $archiveHistorical | Out-Null
New-Item -ItemType Directory -Force -Path $archiveScripts | Out-Null
New-Item -ItemType Directory -Force -Path $archiveSQL | Out-Null
New-Item -ItemType Directory -Force -Path $archiveDocs | Out-Null

Write-Host "Created archive directories" -ForegroundColor Green
Write-Host ""

# Files to DELETE (screenshots and obsolete)
$filesToDelete = @(
    "A1.PNG",
    "A2.PNG",
    "A3.PNG",
    "A4.PNG",
    "cpan.PNG",
    "Diagnosis.PNG",
    "Disc1.PNG",
    "Inven.PNG",
    "SQL_DIAGNOSTIC_REPORT.txt"
)

Write-Host "Deleting obsolete files..." -ForegroundColor Yellow
foreach ($file in $filesToDelete) {
    $filePath = Join-Path $scriptDir $file
    if (Test-Path $filePath) {
        Remove-Item $filePath -Force
        Write-Host "  Deleted: $file" -ForegroundColor Gray
    }
}
Write-Host ""

# Folders to MOVE to archive
$foldersToArchive = @(
    @{Source = "02_Testing"; Dest = "02_Testing"},
    @{Source = "03_Reference"; Dest = "03_Reference"},
    @{Source = "docs"; Dest = "docs"},
    @{Source = "archive_files"; Dest = "archive_files"},
    @{Source = "legacy_docs"; Dest = "legacy_docs"},
    @{Source = "legacy_imports"; Dest = "legacy_imports"}
)

Write-Host "Moving folders to archive..." -ForegroundColor Yellow
foreach ($folder in $foldersToArchive) {
    $sourcePath = Join-Path $scriptDir $folder.Source
    $destPath = Join-Path $archiveRoot $folder.Dest
    
    if (Test-Path $sourcePath) {
        if (Test-Path $destPath) {
            Write-Host "  Archive already exists: $($folder.Dest)" -ForegroundColor Yellow
        } else {
            Move-Item $sourcePath $destPath -Force
            Write-Host "  Moved: $($folder.Source) -> archive/$($folder.Dest)" -ForegroundColor Gray
        }
    }
}
Write-Host ""

# Essential documentation to KEEP
$essentialDocs = @(
    "PIPELINE_EXPLANATION_FOR_RICHARD.md",
    "OPERATIONS_RUNBOOK.md",
    "ROLLBACK_PROCEDURES.md",
    "DEAD_LETTER_QUEUE_PROCESS.md",
    "EMAIL_ALERTS_SETUP.md",
    "PRODUCTION_READINESS_SUMMARY.md"
)

# Get all .md files in root and archive non-essential ones
Write-Host "Archiving non-essential documentation..." -ForegroundColor Yellow
$allMdFiles = Get-ChildItem -Path $scriptDir -Filter "*.md" -File
foreach ($mdFile in $allMdFiles) {
    if ($essentialDocs -notcontains $mdFile.Name) {
        $destPath = Join-Path $archiveDocs $mdFile.Name
        Move-Item $mdFile.FullName $destPath -Force
        Write-Host "  Archived: $($mdFile.Name)" -ForegroundColor Gray
    } else {
        Write-Host "  Keeping: $($mdFile.Name)" -ForegroundColor Green
    }
}
Write-Host ""

# Essential PowerShell scripts to KEEP
$essentialPS1 = @(
    "Run-WooOrderProcessing-Scheduled.ps1",
    "Run-WooProductSync-Scheduled.ps1",
    "Run-WooInventorySync-Scheduled.ps1",
    "Run-WooCustomerSync.ps1",
    "Create-OrderProcessingTask.ps1",
    "Create-ProductSyncTask.ps1",
    "Create-InventorySyncTask.ps1",
    "Setup-EmailAlerts.ps1",
    "Update-OrderProcessingTaskSchedule.ps1"
)

# Get all .ps1 files in root and archive non-essential ones
Write-Host "Archiving non-essential PowerShell scripts..." -ForegroundColor Yellow
$allPS1Files = Get-ChildItem -Path $scriptDir -Filter "*.ps1" -File
foreach ($ps1File in $allPS1Files) {
    if ($essentialPS1 -notcontains $ps1File.Name) {
        $destPath = Join-Path $archiveScripts $ps1File.Name
        Move-Item $ps1File.FullName $destPath -Force
        Write-Host "  Archived: $($ps1File.Name)" -ForegroundColor Gray
    } else {
        Write-Host "  Keeping: $($ps1File.Name)" -ForegroundColor Green
    }
}
Write-Host ""

# Essential Python scripts to KEEP
$essentialPy = @(
    "woo_client.py",
    "woo_orders.py",
    "woo_products.py",
    "woo_customers.py",
    "woo_inventory_sync.py",
    "cp_order_processor.py",
    "check_order_processing_needed.py",
    "check_order_processing_health.py",
    "database.py",
    "config.py",
    "data_utils.py"
)

# Get all .py files in root and archive non-essential ones
Write-Host "Archiving non-essential Python scripts..." -ForegroundColor Yellow
$allPyFiles = Get-ChildItem -Path $scriptDir -Filter "*.py" -File
foreach ($pyFile in $allPyFiles) {
    if ($essentialPy -notcontains $pyFile.Name) {
        $destPath = Join-Path $archiveScripts $pyFile.Name
        Move-Item $pyFile.FullName $destPath -Force
        Write-Host "  Archived: $($pyFile.Name)" -ForegroundColor Gray
    } else {
        Write-Host "  Keeping: $($pyFile.Name)" -ForegroundColor Green
    }
}
Write-Host ""

# Note: 01_Production/ folder is kept as-is (all SQL files are essential)

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Cleanup Complete!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  - Deleted obsolete files (screenshots, etc.)" -ForegroundColor White
Write-Host "  - Archived testing/reference folders" -ForegroundColor White
Write-Host "  - Archived non-essential documentation" -ForegroundColor White
Write-Host "  - Archived non-essential scripts" -ForegroundColor White
Write-Host ""
Write-Host "Root directory now contains only:" -ForegroundColor Yellow
Write-Host "  - Essential production Python scripts (11 files)" -ForegroundColor White
Write-Host "  - Essential PowerShell scripts (9 files)" -ForegroundColor White
Write-Host "  - Essential documentation (6 files)" -ForegroundColor White
Write-Host "  - Configuration files (4 files)" -ForegroundColor White
Write-Host "  - Production folders (01_Production/, api/, wordpress/, logs/, tests/)" -ForegroundColor White
Write-Host ""
Write-Host "Archived files are in: 04_Archive/" -ForegroundColor Cyan
Write-Host ""

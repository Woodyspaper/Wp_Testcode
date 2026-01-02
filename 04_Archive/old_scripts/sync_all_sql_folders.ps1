# Sync All SQL Folders Between SSMS and Project
# Purpose: Ensure all folders (01_Production, 02_Testing, 03_Reference, 04_Archive) are synchronized

$ssmsBase = "C:\Users\Administrator.ADWPC-MAIN\OneDrive - woodyspaper.com\Documents\SQL Server Management Studio"
$projectBase = "."

# Folder mappings (SSMS folder name -> Project folder name)
$folderMappings = @{
    "01_Production" = "01_Production"
    "02_Testing" = "02_Testing"
    "03_Reference" = "03_Reference"
    "04_Archive" = "archive_files"  # Note: project uses archive_files, SSMS uses 04_Archive
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Complete SQL Folders Synchronization" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

foreach ($mapping in $folderMappings.GetEnumerator()) {
    $ssmsFolder = $mapping.Key
    $projectFolder = $mapping.Value
    
    $ssmsPath = Join-Path $ssmsBase $ssmsFolder
    $projectPath = Join-Path $projectBase $projectFolder
    
    Write-Host "Processing: $ssmsFolder" -ForegroundColor Yellow
    Write-Host "  SSMS Path: $ssmsPath" -ForegroundColor Gray
    Write-Host "  Project Path: $projectPath" -ForegroundColor Gray
    
    # Create SSMS folder if it doesn't exist
    if (-not (Test-Path $ssmsPath)) {
        Write-Host "  Creating SSMS folder..." -ForegroundColor Cyan
        New-Item -ItemType Directory -Path $ssmsPath -Force | Out-Null
    }
    
    # Check if project folder exists
    if (-not (Test-Path $projectPath)) {
        Write-Host "  [WARN] Project folder not found: $projectPath" -ForegroundColor Yellow
        continue
    }
    
    # Get SQL files from project folder
    $projectFiles = Get-ChildItem -Path $projectPath -Filter "*.sql" -ErrorAction SilentlyContinue
    
    if ($projectFiles.Count -eq 0) {
        Write-Host "  [INFO] No SQL files in project folder" -ForegroundColor Gray
    } else {
        Write-Host "  Found $($projectFiles.Count) SQL files in project folder" -ForegroundColor Cyan
        
        # Copy all SQL files from project to SSMS
        foreach ($file in $projectFiles) {
            $destFile = Join-Path $ssmsPath $file.Name
            Copy-Item -Path $file.FullName -Destination $destFile -Force
            Write-Host "    [OK] Copied: $($file.Name)" -ForegroundColor Green
        }
    }
    
    # Check for files in SSMS that don't exist in project (potential orphans)
    $ssmsFiles = Get-ChildItem -Path $ssmsPath -Filter "*.sql" -ErrorAction SilentlyContinue
    $projectFileNames = $projectFiles | Select-Object -ExpandProperty Name
    
    foreach ($ssmsFile in $ssmsFiles) {
        if ($projectFileNames -notcontains $ssmsFile.Name) {
            Write-Host "    [INFO] SSMS has file not in project: $($ssmsFile.Name)" -ForegroundColor Gray
            Write-Host "      (Keeping it - may be manually created)" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Synchronization Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Summary
Write-Host "Summary by folder:" -ForegroundColor Yellow
foreach ($mapping in $folderMappings.GetEnumerator()) {
    $ssmsFolder = $mapping.Key
    $projectFolder = $mapping.Value
    
    $ssmsPath = Join-Path $ssmsBase $ssmsFolder
    $projectPath = Join-Path $projectBase $projectFolder
    
    if (Test-Path $ssmsPath) {
        $ssmsCount = (Get-ChildItem -Path $ssmsPath -Filter "*.sql" -ErrorAction SilentlyContinue).Count
        Write-Host "  $ssmsFolder : $ssmsCount files" -ForegroundColor White
    }
}

Write-Host ""

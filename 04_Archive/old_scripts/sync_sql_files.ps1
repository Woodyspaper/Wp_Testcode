# Sync SQL Files Between SSMS Folder and Project Folder
# Purpose: Ensure both locations have the same required deployment scripts

$ssmsPath = "C:\Users\Administrator.ADWPC-MAIN\OneDrive - woodyspaper.com\Documents\SQL Server Management Studio\01_Production"
$projectPath = "01_Production"

# Required deployment scripts (for contract pricing system)
$requiredScripts = @(
    "contract_price_calculation.sql",
    "pricing_api_log_table.sql",
    "counterpoint_orders_export_view_corrected.sql"
)

# Other useful scripts to keep
$usefulScripts = @(
    "staging_tables.sql",
    "product_export_view.sql",
    "product_mapping_tables.sql",
    "cp_woo_crosscheck.sql",
    "create_scheduled_sync_job.sql",
    "backup_database.sql",
    "verify_schema_deployment.sql"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SQL Files Synchronization" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if SSMS folder exists
if (-not (Test-Path $ssmsPath)) {
    Write-Host "ERROR: SSMS folder not found: $ssmsPath" -ForegroundColor Red
    Write-Host "Creating folder..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $ssmsPath -Force | Out-Null
}

# Get files in both locations
$ssmsFiles = Get-ChildItem -Path $ssmsPath -Filter "*.sql" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
$projectFiles = Get-ChildItem -Path $projectPath -Filter "*.sql" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name

Write-Host "Step 1: Copying REQUIRED deployment scripts to SSMS folder..." -ForegroundColor Yellow
foreach ($script in $requiredScripts) {
    $sourceFile = Join-Path $projectPath $script
    $destFile = Join-Path $ssmsPath $script
    
    if (Test-Path $sourceFile) {
        Copy-Item -Path $sourceFile -Destination $destFile -Force
        Write-Host "  [OK] Copied: $script" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Not found in project: $script" -ForegroundColor Yellow
    }
}

Write-Host "`nStep 2: Copying useful scripts to SSMS folder..." -ForegroundColor Yellow
foreach ($script in $usefulScripts) {
    $sourceFile = Join-Path $projectPath $script
    $destFile = Join-Path $ssmsPath $script
    
    if (Test-Path $sourceFile) {
        Copy-Item -Path $sourceFile -Destination $destFile -Force
        Write-Host "  [OK] Copied: $script" -ForegroundColor Green
    }
}

Write-Host "`nStep 3: Handling name differences..." -ForegroundColor Yellow
# Handle verify_schema_deployment.sql vs verifying_schema_deploy.sql
$verifyInProject = Join-Path $projectPath "verify_schema_deployment.sql"
$verifyOldInSSMS = Join-Path $ssmsPath "verifying_schema_deploy.sql"
$verifyNewInSSMS = Join-Path $ssmsPath "verify_schema_deployment.sql"

if (Test-Path $verifyOldInSSMS) {
    if (Test-Path $verifyInProject) {
        # Copy new version and remove old
        Copy-Item -Path $verifyInProject -Destination $verifyNewInSSMS -Force
        Remove-Item -Path $verifyOldInSSMS -Force
        Write-Host "  [OK] Replaced: verifying_schema_deploy.sql -> verify_schema_deployment.sql" -ForegroundColor Green
    }
}

Write-Host "`nStep 4: Removing unused/obsolete scripts from SSMS folder..." -ForegroundColor Yellow
# Scripts that are not needed for deployment
$obsoleteScripts = @(
    # Add any scripts that are obsolete
)

$allSSMSFiles = Get-ChildItem -Path $ssmsPath -Filter "*.sql" -ErrorAction SilentlyContinue
$allRequiredAndUseful = $requiredScripts + $usefulScripts

foreach ($file in $allSSMSFiles) {
    if ($allRequiredAndUseful -notcontains $file.Name) {
        Write-Host "  [INFO] Keeping: $($file.Name) (not in required list, but keeping for now)" -ForegroundColor Gray
    }
}

Write-Host "`nStep 5: Summary..." -ForegroundColor Yellow
Write-Host "`nFiles in SSMS folder (01_Production):" -ForegroundColor Cyan
Get-ChildItem -Path $ssmsPath -Filter "*.sql" | Select-Object Name | Format-Table -AutoSize

Write-Host "`nFiles in Project folder (01_Production):" -ForegroundColor Cyan
Get-ChildItem -Path $projectPath -Filter "*.sql" | Select-Object Name | Format-Table -AutoSize

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Synchronization Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`nRequired deployment scripts are now in both locations:" -ForegroundColor Yellow
foreach ($script in $requiredScripts) {
    Write-Host "  - $script" -ForegroundColor White
}
Write-Host ""

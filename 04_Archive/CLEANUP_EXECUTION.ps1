# Comprehensive Cleanup Script for WP_Testcode
# Date: December 30, 2025

Write-Host "========================================" -ForegroundColor Green
Write-Host "WP_TESTCODE CLEANUP" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Step 1: Move all PNG screenshots to docs/screenshots
Write-Host "[1/6] Organizing screenshots..." -ForegroundColor Cyan
$screenshotDir = "docs\screenshots"
if (-not (Test-Path $screenshotDir)) {
    New-Item -ItemType Directory -Path $screenshotDir -Force | Out-Null
}

Get-ChildItem -Path . -Filter "*.PNG" -File | ForEach-Object {
    Move-Item -Path $_.FullName -Destination $screenshotDir -Force
    Write-Host "  Moved: $($_.Name)" -ForegroundColor Gray
}
Write-Host "  [OK] Screenshots organized" -ForegroundColor Green
Write-Host ""

# Step 2: Consolidate redundant deployment status files
Write-Host "[2/6] Consolidating deployment documentation..." -ForegroundColor Cyan
$deploymentFiles = @(
    "DEPLOYMENT_STATUS.md",
    "DEPLOYMENT_NEXT_STEPS.md",
    "DEPLOYMENT_READY_SUMMARY.md",
    "DEPLOYMENT_EXECUTION_CHECKLIST.md",
    "DEPLOYMENT_QUICK_START.md",
    "QUICK_DEPLOY_API.md",
    "DEPLOY_API_PRODUCTION.md"
)

$archiveDeploymentDir = "04_Archive\docs\deployment"
if (-not (Test-Path $archiveDeploymentDir)) {
    New-Item -ItemType Directory -Path $archiveDeploymentDir -Force | Out-Null
}

foreach ($file in $deploymentFiles) {
    if (Test-Path $file) {
        Move-Item -Path $file -Destination $archiveDeploymentDir -Force
        Write-Host "  Archived: $file" -ForegroundColor Gray
    }
}
Write-Host "  [OK] Deployment docs consolidated" -ForegroundColor Green
Write-Host ""

# Step 3: Move redundant setup/configuration docs
Write-Host "[3/6] Organizing setup documentation..." -ForegroundColor Cyan
$setupFiles = @(
    "IMPORT_FIXES_COMPLETE.md",
    "UPDATE_ENV_API_KEYS.md",
    "FIREWALL_CONFIGURED.md",
    "SERVICE_CREATED_SUCCESS.md",
    "SQL_FILES_SYNC_REPORT.md",
    "SQL_FOLDERS_SYNC_COMPLETE.md",
    "API_URL_CORRECTION.md",
    "PLUGIN_ACTIVATION_NEXT_STEPS.md",
    "PLUGIN_CONFIGURATION_VALUES.md"
)

$archiveSetupDir = "04_Archive\docs\setup"
if (-not (Test-Path $archiveSetupDir)) {
    New-Item -ItemType Directory -Path $archiveSetupDir -Force | Out-Null
}

foreach ($file in $setupFiles) {
    if (Test-Path $file) {
        Move-Item -Path $file -Destination $archiveSetupDir -Force
        Write-Host "  Archived: $file" -ForegroundColor Gray
    }
}
Write-Host "  [OK] Setup docs organized" -ForegroundColor Green
Write-Host ""

# Step 4: Move FTP/upload guides to docs
Write-Host "[4/6] Organizing upload guides..." -ForegroundColor Cyan
$uploadFiles = @(
    "FTP_UPLOAD_QUICK_GUIDE.md",
    "FTP_UPLOAD_STEP_BY_STEP.md",
    "FTP_ACCOUNT_CLARIFICATION.md",
    "FTP_CONNECTION_DETAILS.md",
    "GODADDY_FILE_MANAGER_UPLOAD.md",
    "UPLOAD_ZIP_INSTRUCTIONS.md",
    "WORDPRESS_UPLOAD_INSTRUCTIONS.md",
    "CLOUDFLARE_BLOCK_SOLUTION.md"
)

$docsUploadDir = "docs\guides\upload"
if (-not (Test-Path $docsUploadDir)) {
    New-Item -ItemType Directory -Path $docsUploadDir -Force | Out-Null
}

foreach ($file in $uploadFiles) {
    if (Test-Path $file) {
        Move-Item -Path $file -Destination $docsUploadDir -Force
        Write-Host "  Moved: $file" -ForegroundColor Gray
    }
}
Write-Host "  [OK] Upload guides organized" -ForegroundColor Green
Write-Host ""

# Step 5: Move NSSM docs to docs/guides
Write-Host "[5/6] Organizing NSSM documentation..." -ForegroundColor Cyan
$nssmFiles = @(
    "NSSM_GUI_FILL_IN.md",
    "NSSM_PATH_FIX.md",
    "NSSM_SERVICE_SETUP.md",
    "SETUP_NSSM_FIRST.md"
)

$docsNssmDir = "docs\guides\nssm"
if (-not (Test-Path $docsNssmDir)) {
    New-Item -ItemType Directory -Path $docsNssmDir -Force | Out-Null
}

foreach ($file in $nssmFiles) {
    if (Test-Path $file) {
        Move-Item -Path $file -Destination $docsNssmDir -Force
        Write-Host "  Moved: $file" -ForegroundColor Gray
    }
}
Write-Host "  [OK] NSSM docs organized" -ForegroundColor Green
Write-Host ""

# Step 6: Move remaining root-level docs to appropriate locations
Write-Host "[6/6] Organizing remaining documentation..." -ForegroundColor Cyan

# Move to docs root
$docsRootFiles = @(
    "WORDPRESS_SITE_HEALTH_NOTES.md",
    "QUICK_REFERENCE_API_KEYS_AND_SQL.md",
    "TEST_WITHOUT_CUSTOMER_CREDENTIALS.md"
)

foreach ($file in $docsRootFiles) {
    if (Test-Path $file) {
        Move-Item -Path $file -Destination "docs\" -Force
        Write-Host "  Moved to docs: $file" -ForegroundColor Gray
    }
}

# Move cleanup/status docs to archive
$cleanupFiles = @(
    "CLEANUP_ACTION_PLAN.md"
)

foreach ($file in $cleanupFiles) {
    if (Test-Path $file) {
        Move-Item -Path $file -Destination "04_Archive\docs\" -Force
        Write-Host "  Archived: $file" -ForegroundColor Gray
    }
}

Write-Host "  [OK] Remaining docs organized" -ForegroundColor Green
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Green
Write-Host "CLEANUP COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Files organized:" -ForegroundColor Cyan
Write-Host "  - Screenshots moved to docs/screenshots/" -ForegroundColor White
Write-Host "  - Deployment docs archived" -ForegroundColor White
Write-Host "  - Setup docs archived" -ForegroundColor White
Write-Host "  - Upload guides moved to docs/guides/upload/" -ForegroundColor White
Write-Host "  - NSSM docs moved to docs/guides/nssm/" -ForegroundColor White
Write-Host "  - Remaining docs organized" -ForegroundColor White
Write-Host ""

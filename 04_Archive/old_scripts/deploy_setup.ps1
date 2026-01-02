# Deployment Setup Script
# Purpose: Automated setup for contract pricing system deployment
# Date: December 30, 2025

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Contract Pricing System - Deployment Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check Python installation
Write-Host "Step 1: Checking Python installation..." -ForegroundColor Yellow
try {
    $pythonVersion = python --version 2>&1
    Write-Host "OK: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Python not found!" -ForegroundColor Red
    Write-Host "Please install Python 3.8+ and try again." -ForegroundColor Red
    exit 1
}
Write-Host ""

# Step 2: Install Python dependencies
Write-Host "Step 2: Installing Python dependencies..." -ForegroundColor Yellow
if (Test-Path "requirements.txt") {
    Write-Host "Found requirements.txt, installing packages..." -ForegroundColor Cyan
    pip install -r requirements.txt
    if ($LASTEXITCODE -eq 0) {
        Write-Host "OK: Dependencies installed successfully" -ForegroundColor Green
    } else {
        Write-Host "WARNING: Some dependencies may have failed to install" -ForegroundColor Yellow
    }
} else {
    Write-Host "WARNING: requirements.txt not found" -ForegroundColor Yellow
}
Write-Host ""

# Step 3: Verify critical imports
Write-Host "Step 3: Verifying critical Python packages..." -ForegroundColor Yellow
$packages = @("flask", "flask_cors", "pyodbc", "dotenv")
$allOk = $true
foreach ($pkg in $packages) {
    try {
        python -c "import $pkg; print('OK')" 2>&1 | Out-Null
        Write-Host "  OK: $pkg" -ForegroundColor Green
    } catch {
        Write-Host "  ERROR: $pkg not installed" -ForegroundColor Red
        $allOk = $false
    }
}
if ($allOk) {
    Write-Host "OK: All critical packages verified" -ForegroundColor Green
} else {
    Write-Host "ERROR: Some packages are missing. Run: pip install -r requirements.txt" -ForegroundColor Red
}
Write-Host ""

# Step 4: Check for .env file
Write-Host "Step 4: Checking .env file..." -ForegroundColor Yellow
if (Test-Path ".env") {
    Write-Host "OK: .env file exists" -ForegroundColor Green
    Write-Host "WARNING: Please verify .env contains all required values" -ForegroundColor Yellow
} else {
    Write-Host "WARNING: .env file not found" -ForegroundColor Yellow
    if (Test-Path ".env.template") {
        Write-Host "Found .env.template - creating .env from template..." -ForegroundColor Cyan
        Copy-Item ".env.template" ".env"
        Write-Host "OK: .env file created from template" -ForegroundColor Green
        Write-Host "IMPORTANT: Edit .env file and fill in your actual values!" -ForegroundColor Red
    } else {
        Write-Host "ERROR: .env.template not found. Cannot create .env file." -ForegroundColor Red
    }
}
Write-Host ""

# Step 5: Check SQL scripts
Write-Host "Step 5: Checking SQL deployment scripts..." -ForegroundColor Yellow
$sqlScripts = @(
    "01_Production\contract_price_calculation.sql",
    "01_Production\pricing_api_log_table.sql"
)
$allScriptsExist = $true
foreach ($script in $sqlScripts) {
    if (Test-Path $script) {
        Write-Host "  OK: $script" -ForegroundColor Green
    } else {
        Write-Host "  ERROR: $script not found" -ForegroundColor Red
        $allScriptsExist = $false
    }
}
if ($allScriptsExist) {
    Write-Host "OK: All SQL scripts found" -ForegroundColor Green
    Write-Host "NEXT: Run these scripts in SSMS (SQL Server Management Studio)" -ForegroundColor Cyan
} else {
    Write-Host "ERROR: Some SQL scripts are missing" -ForegroundColor Red
}
Write-Host ""

# Step 6: Check WordPress plugins
Write-Host "Step 6: Checking WordPress plugin files..." -ForegroundColor Yellow
$wpPlugins = @(
    "wordpress\woocommerce-contract-pricing-enhanced.php",
    "wordpress\woocommerce-cp-orders.php"
)
foreach ($plugin in $wpPlugins) {
    if (Test-Path $plugin) {
        Write-Host "  OK: $plugin" -ForegroundColor Green
    } else {
        Write-Host "  WARNING: $plugin not found (optional)" -ForegroundColor Yellow
    }
}
Write-Host ""

# Step 7: Check API files
Write-Host "Step 7: Checking API files..." -ForegroundColor Yellow
$apiFiles = @(
    "api\contract_pricing_api_enhanced.py",
    "api\cp_orders_api_enhanced.py"
)
$allApiFilesExist = $true
foreach ($file in $apiFiles) {
    if (Test-Path $file) {
        Write-Host "  OK: $file" -ForegroundColor Green
    } else {
        Write-Host "  ERROR: $file not found" -ForegroundColor Red
        $allApiFilesExist = $false
    }
}
if ($allApiFilesExist) {
    Write-Host "OK: All API files found" -ForegroundColor Green
} else {
    Write-Host "ERROR: Some API files are missing" -ForegroundColor Red
}
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Setup Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. Edit .env file with your actual values (database, API keys, etc.)" -ForegroundColor White
Write-Host "2. Run SQL scripts in SSMS:" -ForegroundColor White
Write-Host "   - 01_Production\contract_price_calculation.sql" -ForegroundColor White
Write-Host "   - 01_Production\pricing_api_log_table.sql" -ForegroundColor White
Write-Host "3. Test API: python api\contract_pricing_api_enhanced.py" -ForegroundColor White
Write-Host "4. Upload WordPress plugins to /wp-content/plugins/" -ForegroundColor White
Write-Host "5. Configure firewall rules (restrict API ports to WordPress server IP)" -ForegroundColor White
Write-Host "6. Run smoke tests (see docs/DEPLOYMENT_GUIDE_STEP_BY_STEP.md)" -ForegroundColor White
Write-Host ""
Write-Host "For detailed instructions, see: docs/DEPLOYMENT_GUIDE_STEP_BY_STEP.md" -ForegroundColor Cyan
Write-Host ""

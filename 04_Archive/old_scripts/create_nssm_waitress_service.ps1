# Create NSSM Service for Contract Pricing API with Waitress
# Run this script as Administrator

param(
    [string]$NSSMPath = "C:\nssm\win64\nssm.exe",
    [string]$ProjectPath = "C:\Users\Administrator.ADWPC-MAIN\OneDrive - woodyspaper.com\Desktop\WP_Testcode",
    [string]$PythonPath = "C:\Program Files\Python314\python.exe",
    [string]$ServiceName = "ContractPricingAPIWaitress",
    [int]$Port = 5000,
    [int]$Threads = 4
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Create NSSM Service for Contract Pricing API" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[ERROR] This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

# Check NSSM exists (try multiple possible locations)
$nssmPaths = @(
    $NSSMPath,
    "C:\nssm\win64\nssm.exe",
    "C:\nssm\nssm-2.24\win64\nssm.exe",
    "C:\nssm\win32\nssm.exe",
    "C:\nssm\nssm-2.24\win32\nssm.exe"
)

$foundNSSM = $null
foreach ($path in $nssmPaths) {
    if (Test-Path $path) {
        $foundNSSM = $path
        Write-Host "[OK] Found NSSM at: $path" -ForegroundColor Green
        $NSSMPath = $path
        break
    }
}

if (-not $foundNSSM) {
    Write-Host "[ERROR] NSSM not found in any expected location" -ForegroundColor Red
    Write-Host "Searched:" -ForegroundColor Yellow
    foreach ($path in $nssmPaths) {
        Write-Host "  - $path" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "Download NSSM from: https://nssm.cc/download" -ForegroundColor Yellow
    Write-Host "Extract to: C:\nssm\" -ForegroundColor Yellow
    exit 1
}

# Check Python exists
if (-not (Test-Path $PythonPath)) {
    Write-Host "[ERROR] Python not found at: $PythonPath" -ForegroundColor Red
    Write-Host "Update PythonPath in script or install Python" -ForegroundColor Yellow
    exit 1
}

# Check project path exists
if (-not (Test-Path $ProjectPath)) {
    Write-Host "[ERROR] Project path not found: $ProjectPath" -ForegroundColor Red
    Write-Host "Update ProjectPath in script" -ForegroundColor Yellow
    exit 1
}

# Create logs directory
$logsDir = Join-Path $ProjectPath "logs"
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    Write-Host "[OK] Created logs directory" -ForegroundColor Green
}

# Check if service already exists
$existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "[WARN] Service $ServiceName already exists" -ForegroundColor Yellow
    $response = Read-Host "Remove existing service? (y/n)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        Write-Host "Stopping service..." -ForegroundColor Yellow
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        & $NSSMPath remove $ServiceName confirm
        Write-Host "[OK] Removed existing service" -ForegroundColor Green
    } else {
        Write-Host "[INFO] Keeping existing service. Exiting." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host ""
Write-Host "Creating service: $ServiceName" -ForegroundColor Yellow
Write-Host "  Python: $PythonPath" -ForegroundColor Gray
Write-Host "  Project: $ProjectPath" -ForegroundColor Gray
Write-Host "  Port: $Port" -ForegroundColor Gray
Write-Host "  Threads: $Threads" -ForegroundColor Gray
Write-Host ""

# Create service
Write-Host "Step 1: Installing service..." -ForegroundColor Cyan
& $NSSMPath install $ServiceName

# Configure application
Write-Host "Step 2: Configuring application..." -ForegroundColor Cyan
& $NSSMPath set $ServiceName Application $PythonPath
& $NSSMPath set $ServiceName AppParameters "-m waitress-serve --host=0.0.0.0 --port=$Port --threads=$Threads api.contract_pricing_api_enhanced:app"
& $NSSMPath set $ServiceName AppDirectory $ProjectPath

# Configure service details
Write-Host "Step 3: Configuring service details..." -ForegroundColor Cyan
& $NSSMPath set $ServiceName DisplayName "Contract Pricing API (Waitress)"
& $NSSMPath set $ServiceName Description "REST API for CounterPoint contract pricing integration using Waitress WSGI server"

# Configure logging
Write-Host "Step 4: Configuring logging..." -ForegroundColor Cyan
$stdoutLog = Join-Path $logsDir "pricing_api_waitress.log"
$stderrLog = Join-Path $logsDir "pricing_api_waitress_error.log"
& $NSSMPath set $ServiceName AppStdout $stdoutLog
& $NSSMPath set $ServiceName AppStderr $stderrLog

# Configure auto-restart
Write-Host "Step 5: Configuring auto-restart..." -ForegroundColor Cyan
& $NSSMPath set $ServiceName AppRestartDelay 10000
& $NSSMPath set $ServiceName AppExit Default Restart

# Set to start automatically
Write-Host "Step 6: Setting startup type..." -ForegroundColor Cyan
& $NSSMPath set $ServiceName Start SERVICE_AUTO_START

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Service Created Successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Start service
Write-Host "Starting service..." -ForegroundColor Yellow
& $NSSMPath start $ServiceName

Start-Sleep -Seconds 3

# Check status
$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($service) {
    Write-Host ""
    Write-Host "Service Status:" -ForegroundColor Cyan
    Write-Host "  Name: $($service.Name)" -ForegroundColor White
    Write-Host "  Display Name: $($service.DisplayName)" -ForegroundColor White
    Write-Host "  Status: $($service.Status)" -ForegroundColor $(if ($service.Status -eq 'Running') { 'Green' } else { 'Yellow' })
    Write-Host "  Start Type: $($service.StartType)" -ForegroundColor White
    Write-Host ""
    
    if ($service.Status -eq 'Running') {
        Write-Host "[OK] Service is running!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Test the API:" -ForegroundColor Cyan
        Write-Host "  python test_api_health.py" -ForegroundColor White
        Write-Host "  Or: Invoke-WebRequest -Uri http://localhost:$Port/api/health" -ForegroundColor White
    } else {
        Write-Host "[WARN] Service is not running. Check logs:" -ForegroundColor Yellow
        Write-Host "  Get-Content $stderrLog -Tail 20" -ForegroundColor White
    }
} else {
    Write-Host "[ERROR] Service not found after creation" -ForegroundColor Red
}

Write-Host ""
Write-Host "Service Management:" -ForegroundColor Cyan
Write-Host "  Start:   Start-Service $ServiceName" -ForegroundColor White
Write-Host "  Stop:    Stop-Service $ServiceName" -ForegroundColor White
Write-Host "  Restart: Restart-Service $ServiceName" -ForegroundColor White
Write-Host "  Status:  Get-Service $ServiceName" -ForegroundColor White
Write-Host "  Remove:  & `"$NSSMPath`" remove $ServiceName confirm" -ForegroundColor White
Write-Host ""

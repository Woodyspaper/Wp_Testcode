# Download and Extract NSSM
# This script downloads NSSM and extracts it to C:\nssm\

$nssmUrl = "https://nssm.cc/release/nssm-2.24.zip"
$downloadPath = "$env:TEMP\nssm.zip"
$extractPath = "C:\nssm"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Download and Install NSSM" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if already installed
if (Test-Path "C:\nssm\win64\nssm.exe") {
    Write-Host "[OK] NSSM already installed at C:\nssm\win64\nssm.exe" -ForegroundColor Green
    Write-Host ""
    $response = Read-Host "Re-download? (y/n)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Skipping download." -ForegroundColor Yellow
        exit 0
    }
}

# Check if running as Administrator (needed for C:\nssm)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[WARN] Not running as Administrator" -ForegroundColor Yellow
    Write-Host "You may need admin rights to extract to C:\nssm\" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "Step 1: Downloading NSSM..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $nssmUrl -OutFile $downloadPath -UseBasicParsing
    Write-Host "[OK] Downloaded to $downloadPath" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to download NSSM: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Manual download:" -ForegroundColor Yellow
    Write-Host "  1. Go to: https://nssm.cc/download" -ForegroundColor White
    Write-Host "  2. Download nssm-2.24.zip" -ForegroundColor White
    Write-Host "  3. Extract to C:\nssm\" -ForegroundColor White
    exit 1
}

Write-Host ""
Write-Host "Step 2: Extracting NSSM..." -ForegroundColor Yellow

# Create extract directory
if (-not (Test-Path $extractPath)) {
    New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
}

# Extract ZIP
try {
    Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force
    Write-Host "[OK] Extracted to $extractPath" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to extract: $_" -ForegroundColor Red
    Write-Host "Try extracting manually to C:\nssm\" -ForegroundColor Yellow
    exit 1
}

# Clean up download
Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Step 3: Verifying installation..." -ForegroundColor Yellow

# Check for nssm.exe
$nssmExe = Get-ChildItem -Path $extractPath -Filter "nssm.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

if ($nssmExe) {
    Write-Host "[OK] NSSM found at: $($nssmExe.FullName)" -ForegroundColor Green
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "NSSM Installation Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Navigate to project directory:" -ForegroundColor White
    Write-Host "     cd `"C:\Users\Administrator.ADWPC-MAIN\OneDrive - woodyspaper.com\Desktop\WP_Testcode`"" -ForegroundColor Gray
    Write-Host "  2. Run service creation script:" -ForegroundColor White
    Write-Host "     .\create_nssm_waitress_service.ps1" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "[ERROR] nssm.exe not found after extraction" -ForegroundColor Red
    Write-Host "Check: $extractPath" -ForegroundColor Yellow
    exit 1
}

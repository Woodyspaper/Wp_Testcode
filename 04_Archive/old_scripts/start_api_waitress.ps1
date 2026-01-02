# Start Contract Pricing API with Waitress
# Use this for testing or if not using NSSM service

$ProjectPath = "C:\Users\Administrator.ADWPC-MAIN\OneDrive - woodyspaper.com\Desktop\WP_Testcode"
$PythonPath = "C:\Program Files\Python314\python.exe"
$Port = 5000
$Threads = 4

Write-Host "Starting Contract Pricing API with Waitress..." -ForegroundColor Cyan
Write-Host "  Port: $Port" -ForegroundColor Gray
Write-Host "  Threads: $Threads" -ForegroundColor Gray
Write-Host ""

# Set environment
$env:PYTHONPATH = $ProjectPath
Set-Location $ProjectPath

# Create logs directory if needed
if (-not (Test-Path "logs")) {
    New-Item -ItemType Directory -Path "logs" | Out-Null
}

# Start Waitress
Write-Host "Starting API..." -ForegroundColor Yellow
& $PythonPath -m waitress-serve --host=0.0.0.0 --port=$Port --threads=$Threads api.contract_pricing_api_enhanced:app

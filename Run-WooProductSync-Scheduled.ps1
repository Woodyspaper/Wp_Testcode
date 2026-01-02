# Run-WooProductSync-Scheduled.ps1
# Wrapper script for Task Scheduler - Product Catalog Sync (Phase 2)

$ErrorActionPreference = "Stop"

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

# Log directory
$logDir = Join-Path $scriptDir "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath = Join-Path $logDir "woo_product_sync_$ts.log"

function Log($msg) {
  $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg
  Write-Host $line
  $line | Out-File -FilePath $logPath -Append -Encoding UTF8
}

Log "============================================================"
Log "Product Catalog Sync: CounterPoint -> WooCommerce (Phase 2)"
Log "============================================================"
Log "Started at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Log "Script directory: $scriptDir"
Log "Log file: $logPath"

# Find Python executable
$pythonExe = "python"
try {
    $pythonVersion = & $pythonExe --version 2>&1
    Log "Python found: $pythonVersion"
} catch {
    Log "ERROR: Python not found in PATH. Trying common locations..."
    $commonPaths = @(
        "C:\Program Files\Python314\python.exe",
        "C:\Python314\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python314\python.exe"
    )
    $found = $false
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            $pythonExe = $path
            Log "Python found at: $pythonExe"
            $found = $true
            break
        }
    }
    if (-not $found) {
        Log "ERROR: Python not found. Please install Python or update PATH."
        exit 1
    }
}

# Find product sync script
$syncScript = Join-Path $scriptDir "woo_products.py"
if (-not (Test-Path $syncScript)) {
    Log "ERROR: Script not found: $syncScript"
    exit 1
}
Log "Sync script: $syncScript"

# Run product sync (use --updated-since last to only sync changes)
Log "Starting product catalog sync..."
try {
    # Create temporary output file
    $tempOutput = Join-Path $logDir "temp_output_$ts.txt"
    
    # Run Python script and capture output (properly quote paths with spaces)
    $process = Start-Process -FilePath $pythonExe -ArgumentList @("`"$syncScript`"", "sync", "--apply", "--updated-since", "24h") -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tempOutput -RedirectStandardError "$tempOutput.err"
    $exitCode = $process.ExitCode
    
    # Read and log output
    if (Test-Path $tempOutput) {
        $output = Get-Content $tempOutput -Raw
        $output -split "`n" | ForEach-Object { Log $_ }
        Remove-Item $tempOutput -ErrorAction SilentlyContinue
    }
    
    # Read and log errors
    if (Test-Path "$tempOutput.err") {
        $errors = Get-Content "$tempOutput.err" -Raw
        if ($errors) {
            $errors -split "`n" | ForEach-Object { Log "STDERR: $_" }
        }
        Remove-Item "$tempOutput.err" -ErrorAction SilentlyContinue
    }
    
    if ($exitCode -ne 0) {
        Log "ERROR: Product sync failed with exit code $exitCode"
        exit $exitCode
    }
    
    # Extract summary
    $created = ($output | Select-String -Pattern "Created:\s*(\d+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }) -join ", "
    $updated = ($output | Select-String -Pattern "Updated:\s*(\d+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }) -join ", "
    $errors = ($output | Select-String -Pattern "Errors:\s*(\d+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }) -join ", "
    
    Log "============================================================"
    Log "Summary:"
    Log "  Created: $created"
    Log "  Updated: $updated"
    Log "  Errors: $errors"
    Log "============================================================"
    
    if ($errors -eq "0" -or $errors -eq "") {
        Log "SUCCESS: Product catalog sync completed successfully."
    } else {
        Log "WARNING: Product catalog sync completed with errors."
    }
    
    Log "Completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Log "Log file: $logPath"
    exit 0
    
} catch {
    Log "ERROR: Exception occurred: $_"
    Log "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}

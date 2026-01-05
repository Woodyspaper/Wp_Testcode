# Run-FulfillmentStatusSync-Scheduled.ps1
# Wrapper script for Task Scheduler - Fulfillment Status Sync
# Syncs order fulfillment status from CounterPoint to WooCommerce

$ErrorActionPreference = "Stop"

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

# Log directory
$logDir = Join-Path $scriptDir "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath = Join-Path $logDir "fulfillment_status_sync_$ts.log"

function Log($msg) {
  $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg
  Write-Host $line
  $line | Out-File -FilePath $logPath -Append -Encoding UTF8
}

Log "============================================================"
Log "Fulfillment Status Sync: CounterPoint → WooCommerce"
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

# Find fulfillment sync script
$syncScript = Join-Path $scriptDir "sync_fulfillment_status.py"
if (-not (Test-Path $syncScript)) {
    Log "ERROR: Script not found: $syncScript"
    exit 1
}
Log "Sync script: $syncScript"

# Run fulfillment status sync
Log "Starting fulfillment status sync..."
try {
    # Create temporary output file
    $tempOutput = Join-Path $logDir "temp_fulfillment_output_$ts.txt"
    
    # Run Python script and capture output (properly quote paths with spaces)
    $process = Start-Process -FilePath $pythonExe -ArgumentList @("`"$syncScript`"", "--apply") -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tempOutput -RedirectStandardError "$tempOutput.err"
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
        Log "ERROR: Fulfillment status sync failed with exit code $exitCode"
        exit $exitCode
    }
    
    # Extract summary
    $updated = ($output | Select-String -Pattern "Updated:\s*(\d+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }) -join ", "
    $skipped = ($output | Select-String -Pattern "Skipped:\s*(\d+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }) -join ", "
    $total = ($output | Select-String -Pattern "Total:\s*(\d+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }) -join ", "
    
    Log "============================================================"
    Log "Summary:"
    Log "  Updated: $updated"
    Log "  Skipped: $skipped"
    Log "  Total: $total"
    Log "============================================================"
    
    if ($updated -eq "0" -or $updated -eq "") {
        Log "INFO: No orders needed fulfillment status update (all either not shipped or already completed)"
    } else {
        Log "SUCCESS: Fulfillment status sync completed. Updated $updated order(s) to 'completed'."
    }
    
    Log "Completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Log "Log file: $logPath"
    exit 0
    
} catch {
    Log "ERROR: Exception occurred: $_"
    Log "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}

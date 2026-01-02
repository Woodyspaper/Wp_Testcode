<#
.SYNOPSIS
    Smart order processing - only processes when orders are pending
    
.DESCRIPTION
    This script uses a smart check to determine if order processing is needed:
    - Checks for pending orders in staging
    - Only processes if orders are waiting
    - Falls back to periodic check (every 15 minutes) if no orders
    
    This is the SECOND step in the order flow:
    1. Run-WooOrderSync.ps1 - Pulls orders from WooCommerce to staging
    2. Run-WooOrderProcessing.ps1 - Processes staged orders into CounterPoint
    
.PARAMETER SqlServer
    SQL Server instance name
    
.PARAMETER Database
    Database name (WOODYS_CP)
    
.PARAMETER RepoRoot
    Path to repository root (where scripts and logs are)
    
.PARAMETER PythonExe
    Full path to python.exe (can be from venv)
    
.PARAMETER ProcessorScriptPath
    Full path to cp_order_processor.py
    
.PARAMETER CheckScriptPath
    Full path to check_order_processing_needed.py
    
.EXAMPLE
    .\Run-WooOrderProcessing.ps1 -SqlServer "localhost" -Database "WOODYS_CP" `
        -RepoRoot "C:\path\to\repo" -PythonExe "C:\Python314\python.exe" `
        -ProcessorScriptPath "C:\path\to\cp_order_processor.py" `
        -CheckScriptPath "C:\path\to\check_order_processing_needed.py"
#>

param(
  [Parameter(Mandatory=$true)][string]$SqlServer,
  [Parameter(Mandatory=$true)][string]$Database,
  [Parameter(Mandatory=$true)][string]$RepoRoot,          # path to repo/scripts
  [Parameter(Mandatory=$true)][string]$PythonExe,         # full path to python.exe (venv)
  [Parameter(Mandatory=$true)][string]$ProcessorScriptPath, # full path to cp_order_processor.py
  [Parameter(Mandatory=$true)][string]$CheckScriptPath     # full path to check_order_processing_needed.py
)

$ErrorActionPreference = "Stop"

$logDir = Join-Path $RepoRoot "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath = Join-Path $logDir "woo_order_processing_$ts.log"

function Log($msg) {
  $line = "[{0}] {1}" -f (Get-Date -Format "s"), $msg
  $line | Tee-Object -FilePath $logPath -Append
}

Log "============================================"
Log "WooCommerce Order Processing (Smart Check)"
Log "============================================"
Log "Checking if order processing is needed..."
Log ""

# ---- Step 1: Smart check - do we need to process? ----
Log "Running smart check for pending orders..."
$checkCmd = "& `$PythonExe `$CheckScriptPath"
$checkOutput = Invoke-Expression $checkCmd 2>&1
$checkOutput | ForEach-Object { Log $_ }

# Check exit code - 0 means processing needed, 1 means skip
if ($LASTEXITCODE -eq 1) {
  Log ""
  Log "No processing needed at this time. Exiting."
  Log "Log file: $logPath"
  exit 0
}

if ($LASTEXITCODE -ne 0) {
  Log ""
  Log "WARNING: Check script returned unexpected exit code: $LASTEXITCODE"
  Log "Proceeding with processing anyway (safe fallback)"
}

# ---- Step 2: Process all pending orders ----
Log ""
Log "Processing all pending orders..."
$processCmd = "& `$PythonExe `$ProcessorScriptPath process --all"
$processOutput = Invoke-Expression $processCmd 2>&1
$processOutput | ForEach-Object { Log $_ }

# Check for errors
if ($LASTEXITCODE -ne 0) {
  Log "ERROR: Order processing failed with exit code $LASTEXITCODE"
  Log "Log file: $logPath"
  exit $LASTEXITCODE
}

# Extract summary from output
$successCount = ($processOutput | Select-String -Pattern "Successful:\s*(\d+)" -CaseSensitive:$false | ForEach-Object { $_.Matches[0].Groups[1].Value }) -join ", "
$errorCount = ($processOutput | Select-String -Pattern "Failed:\s*(\d+)" -CaseSensitive:$false | ForEach-Object { $_.Matches[0].Groups[1].Value }) -join ", "

Log ""
Log "============================================"
Log "Order Processing Complete"
Log "============================================"
Log "  Successful: $successCount"
Log "  Failed: $errorCount"
Log ""
Log "SUCCESS. Orders processed into CounterPoint."
Log "Log file: $logPath"
exit 0

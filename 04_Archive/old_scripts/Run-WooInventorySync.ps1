param(
  [Parameter(Mandatory=$true)][string]$SqlServer,
  [Parameter(Mandatory=$true)][string]$Database,
  [Parameter(Mandatory=$true)][string]$RepoRoot,          # path to repo/scripts
  [Parameter(Mandatory=$true)][string]$PythonExe,         # full path to python.exe
  [Parameter(Mandatory=$true)][string]$WooScriptPath,     # full path to woo_inventory_sync.py
  [Parameter(Mandatory=$false)][switch]$DryRun
)

$ErrorActionPreference = "Stop"

$logDir = Join-Path $RepoRoot "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath = Join-Path $logDir "woo_inventory_sync_$ts.log"

function Log($msg) {
  $line = "[{0}] {1}" -f (Get-Date -Format "s"), $msg
  $line | Tee-Object -FilePath $logPath -Append
}

# ---- Step 1: Run inventory sync ----
$applyFlag = if ($DryRun.IsPresent) { "" } else { "--apply" }
Log "Starting inventory sync ($applyFlag)..."
$syncOutput = & $PythonExe $WooScriptPath sync $applyFlag 2>&1
$syncOutput | ForEach-Object { Log $_ }

# Check for errors
if ($LASTEXITCODE -ne 0) {
  Log "ERROR: Inventory sync failed with exit code $LASTEXITCODE"
  exit 1
}

# Extract summary from output
$updated = ($syncOutput | Select-String -Pattern "Updated:\s*(\d+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }) -join ", "
$errors = ($syncOutput | Select-String -Pattern "Errors:\s*(\d+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }) -join ", "

Log "Inventory sync completed. Updated: $updated, Errors: $errors"

if ($LASTEXITCODE -eq 0) {
  Log "SUCCESS. Inventory sync complete."
  Log "Log file: $logPath"
  exit 0
} else {
  Log "FAILED. Check log for details."
  exit 1
}

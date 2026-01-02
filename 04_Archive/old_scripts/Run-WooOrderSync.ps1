param(
  [Parameter(Mandatory=$true)][string]$SqlServer,
  [Parameter(Mandatory=$true)][string]$Database,
  [Parameter(Mandatory=$true)][string]$RepoRoot,          # path to repo/scripts
  [Parameter(Mandatory=$true)][string]$PythonExe,         # full path to python.exe (venv)
  [Parameter(Mandatory=$true)][string]$WooScriptPath,     # full path to woo_orders.py
  [Parameter(Mandatory=$false)][int]$Days = 1              # days to look back for orders
)

$ErrorActionPreference = "Stop"

$logDir = Join-Path $RepoRoot "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath = Join-Path $logDir "woo_order_sync_$ts.log"

function Log($msg) {
  $line = "[{0}] {1}" -f (Get-Date -Format "s"), $msg
  $line | Tee-Object -FilePath $logPath -Append
}

# ---- Step 1: Run Woo order pull ----
Log "Starting Woo order pull (last $Days days)..."
$pullOutput = & $PythonExe $WooScriptPath pull --apply --days $Days 2>&1
$pullOutput | ForEach-Object { Log $_ }

# Check for errors
if ($LASTEXITCODE -ne 0) {
  throw "Order pull failed with exit code $LASTEXITCODE"
}

# Extract summary from output
$newOrders = ($pullOutput | Select-String -Pattern "(\d+)\s+new.*order" -CaseSensitive:$false | ForEach-Object { $_.Matches[0].Groups[1].Value }) -join ", "
$skipped = ($pullOutput | Select-String -Pattern "(\d+)\s+already.*staged" -CaseSensitive:$false | ForEach-Object { $_.Matches[0].Groups[1].Value }) -join ", "

Log "Order pull completed. New: $newOrders, Skipped: $skipped"

# Note: Orders are staged only (Phase 5 not implemented yet)
# No SQL driver script needed until Phase 5 (order creation in CP)

Log "SUCCESS. Orders staged in USER_ORDER_STAGING table."
Log "Note: Orders are staged only. Phase 5 (order creation) not implemented yet."
Log "Log file: $logPath"
exit 0

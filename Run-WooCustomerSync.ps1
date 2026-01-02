param(
  [Parameter(Mandatory=$true)][string]$SqlServer,
  [Parameter(Mandatory=$true)][string]$Database,
  [Parameter(Mandatory=$true)][string]$RepoRoot,          # path to repo/scripts
  [Parameter(Mandatory=$true)][string]$PythonExe,         # full path to python.exe (venv)
  [Parameter(Mandatory=$true)][string]$WooScriptPath,     # full path to woo_customers.py
  [Parameter(Mandatory=$false)][switch]$DryRun,
  [Parameter(Mandatory=$false)][switch]$ApplyMappings
)

$ErrorActionPreference = "Stop"

$logDir = Join-Path $RepoRoot "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath = Join-Path $logDir "woo_customer_sync_$ts.log"

function Log($msg) {
  $line = "[{0}] {1}" -f (Get-Date -Format "s"), $msg
  $line | Tee-Object -FilePath $logPath -Append
}

# ---- Step 1: Run Woo pull (must output BatchID) ----
Log "Starting Woo pull..."
$pullOutput = & $PythonExe $WooScriptPath pull --apply 2>&1
$pullOutput | ForEach-Object { Log $_ }

# Extract BatchID from output (handles 'Batch ID:' or 'BatchID:' format)
$batchMatch = $pullOutput | Select-String -Pattern "(?i)batch\s*id\s*:\s*(\S+)" | Select-Object -First 1
if (-not $batchMatch) {
  throw "Could not find BatchID in woo_customers.py output. Ensure it prints 'Batch ID: <id>' or 'BatchID: <id>'."
}
$BatchID = $batchMatch.Matches[0].Groups[1].Value
Log "Captured BatchID = $BatchID"

# ---- Step 2: Run driver SQL ----
$driverSql = Join-Path $RepoRoot "01_Production\run_woo_customer_batch.sql"
if (-not (Test-Path $driverSql)) {
  throw "Driver SQL not found: $driverSql"
}

$doDryRun = if ($DryRun.IsPresent) { "1" } else { "0" }
$doApplyMappings = if ($ApplyMappings.IsPresent) { "1" } else { "0" }

Log "Running SQL driver (DoDryRun=$doDryRun, ApplyMappings=$doApplyMappings)..."

# Create temporary SQL file with BatchID substituted
$tempSql = Join-Path $env:TEMP "woo_customer_batch_$(Get-Date -Format 'yyyyMMddHHmmss').sql"
$sqlContent = Get-Content $driverSql -Raw
$sqlContent = $sqlContent -replace ':setvar BatchID ""', ":setvar BatchID `"$BatchID`""
$sqlContent = $sqlContent -replace ':setvar DoDryRun "0"', ":setvar DoDryRun `"$doDryRun`""
$sqlContent = $sqlContent -replace ':setvar ApplyMappings "0"', ":setvar ApplyMappings `"$doApplyMappings`""
$sqlContent | Set-Content $tempSql

try {
  $sqlcmdArgs = @(
    "-S", $SqlServer,
    "-d", $Database,
    "-E",                   # integrated auth; swap for -U/-P if needed
    "-b",                   # fail on error
    "-i", $tempSql
  )
  
  $sqlOut = & sqlcmd @sqlcmdArgs 2>&1
  $sqlOut | ForEach-Object { Log $_ }
} finally {
  # Clean up temp file
  if (Test-Path $tempSql) {
    Remove-Item $tempSql -Force -ErrorAction SilentlyContinue
  }
}

Log "SUCCESS. Batch completed: $BatchID"
Log "Log file: $logPath"
exit 0


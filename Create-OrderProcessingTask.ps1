# Create-OrderProcessingTask.ps1
# Creates Windows Task Scheduler job for order processing (Phase 5)
# Processes staged WooCommerce orders into CounterPoint sales tickets (PS_DOC_HDR/PS_DOC_LIN)

param(
    [string]$TaskName = "WP_WooCommerce_Order_Processing",
    [int]$CheckIntervalMinutes = 30  # Changed from 5 to 30 minutes - smart check will skip if not needed
)

$ErrorActionPreference = "Stop"

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$wrapperScript = Join-Path $scriptDir "Run-WooOrderProcessing-Scheduled.ps1"

if (-not (Test-Path $wrapperScript)) {
    Write-Host "ERROR: Wrapper script not found: $wrapperScript" -ForegroundColor Red
    exit 1
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Creating Task Scheduler Job: $TaskName" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This task will:" -ForegroundColor Yellow
Write-Host "  - Check for pending orders in USER_ORDER_STAGING" -ForegroundColor White
Write-Host "  - Process orders into CounterPoint (PS_DOC_HDR/PS_DOC_LIN)" -ForegroundColor White
Write-Host "  - Sync order status back to WooCommerce" -ForegroundColor White
Write-Host "  - Run every $CheckIntervalMinutes minutes (smart check)" -ForegroundColor White
Write-Host "  - Only processes when orders are pending (event-driven)" -ForegroundColor White
Write-Host ""

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "WARNING: Not running as Administrator." -ForegroundColor Yellow
    Write-Host "Task Scheduler may require admin rights to create tasks." -ForegroundColor Yellow
    Write-Host ""
}

# Task Scheduler action
# Use -NoProfile for faster startup, -ExecutionPolicy Bypass to avoid policy issues
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$wrapperScript`"" `
    -WorkingDirectory $scriptDir

# Task Scheduler trigger (every N minutes)
# Start immediately, then repeat every N minutes for 1 year (effectively indefinite)
$trigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes $CheckIntervalMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 365)  # Run for 1 year (effectively indefinite)

# Task Scheduler settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30)  # Max 30 minutes per run

# Task Scheduler principal (run as current user with highest privileges)
$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel Highest

# Task description with CounterPoint terminology
$description = @"
Smart Order Processing: Processes staged WooCommerce orders into CounterPoint sales tickets.

Flow:
1. Checks USER_ORDER_STAGING for pending orders (IS_APPLIED = 0)
2. Validates orders using sp_ValidateStagedOrder
3. Creates sales tickets in PS_DOC_HDR (document header)
4. Creates line items in PS_DOC_LIN (document lines)
5. Creates totals in PS_DOC_HDR_TOT (document totals)
6. Updates staging record with DOC_ID and TKT_NO
7. Syncs order status back to WooCommerce

Schedule: Runs every $CheckIntervalMinutes minutes (check frequency)
Processing: Only processes when orders are pending (event-driven)
Fallback: Periodic check every 2-3 hours if no orders

CounterPoint Tables:
- PS_DOC_HDR: Sales ticket header (DOC_ID, TKT_NO, CUST_NO, etc.)
- PS_DOC_LIN: Sales ticket line items (ITEM_NO, QTY_SOLD, EXT_PRC, etc.)
- PS_DOC_HDR_TOT: Sales ticket totals (SUBTOT, TAX_AMT, TOT_AMT, etc.)
"@

# Register the task
try {
    # Check if task already exists
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Host "Task already exists. Updating..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false | Out-Null
    }
    
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description $description `
        -Force | Out-Null
    
    Write-Host "✅ Task created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Task Details:" -ForegroundColor Cyan
    Write-Host "  Name: $TaskName" -ForegroundColor White
    Write-Host "  Schedule: Every $CheckIntervalMinutes minutes" -ForegroundColor White
    Write-Host "  Script: $wrapperScript" -ForegroundColor White
    Write-Host "  Processing: Event-driven (only when orders pending)" -ForegroundColor White
    Write-Host "  Fallback: Periodic check every 2-3 hours" -ForegroundColor White
    Write-Host ""
    Write-Host "CounterPoint Integration:" -ForegroundColor Cyan
    Write-Host "  - Creates PS_DOC_HDR (sales ticket header)" -ForegroundColor White
    Write-Host "  - Creates PS_DOC_LIN (sales ticket line items)" -ForegroundColor White
    Write-Host "  - Creates PS_DOC_HDR_TOT (sales ticket totals)" -ForegroundColor White
    Write-Host "  - Updates USER_ORDER_STAGING with DOC_ID/TKT_NO" -ForegroundColor White
    Write-Host ""
    Write-Host "To verify:" -ForegroundColor Yellow
    Write-Host "  1. Open Task Scheduler" -ForegroundColor White
    Write-Host "  2. Find task: $TaskName" -ForegroundColor White
    Write-Host "  3. Right-click → Run (to test)" -ForegroundColor White
    Write-Host "  4. Check 'Last Run Result' (should be 0x0 for success)" -ForegroundColor White
    Write-Host ""
    Write-Host "To monitor:" -ForegroundColor Yellow
    Write-Host "  Check logs in: $scriptDir\logs\woo_order_processing_*.log" -ForegroundColor White
    Write-Host ""
    Write-Host "To check pending orders:" -ForegroundColor Yellow
    Write-Host "  python cp_order_processor.py list" -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host "ERROR: Failed to create task: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Try running PowerShell as Administrator:" -ForegroundColor Yellow
    Write-Host "  1. Right-click PowerShell" -ForegroundColor White
    Write-Host "  2. Select 'Run as Administrator'" -ForegroundColor White
    Write-Host "  3. Run this script again" -ForegroundColor White
    Write-Host ""
    Write-Host "Error details:" -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

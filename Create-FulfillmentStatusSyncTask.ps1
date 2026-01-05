# Create-FulfillmentStatusSyncTask.ps1
# Creates Windows Task Scheduler job for fulfillment status sync
# Syncs order fulfillment status from CounterPoint to WooCommerce when orders are shipped

param(
    [string]$TaskName = "WP_Fulfillment_Status_Sync",
    [int]$CheckIntervalMinutes = 30  # Check every 30 minutes for shipped orders
)

$ErrorActionPreference = "Stop"

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$wrapperScript = Join-Path $scriptDir "Run-FulfillmentStatusSync-Scheduled.ps1"

if (-not (Test-Path $wrapperScript)) {
    Write-Host "ERROR: Wrapper script not found: $wrapperScript" -ForegroundColor Red
    exit 1
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Creating Task Scheduler Job: $TaskName" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This task will:" -ForegroundColor Yellow
Write-Host "  - Monitor PS_DOC_HDR.SHIP_DAT for shipped orders" -ForegroundColor White
Write-Host "  - Update WooCommerce order status to 'completed' when shipped" -ForegroundColor White
Write-Host "  - Run every $CheckIntervalMinutes minutes" -ForegroundColor White
Write-Host ""

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "WARNING: Not running as Administrator." -ForegroundColor Yellow
    Write-Host "Task Scheduler may require admin rights to create tasks." -ForegroundColor Yellow
    Write-Host ""
}

# Task Scheduler action
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$wrapperScript`"" `
    -WorkingDirectory $scriptDir

# Task Scheduler trigger (every N minutes)
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
    -ExecutionTimeLimit (New-TimeSpan -Minutes 15)  # Max 15 minutes per run

# Task Scheduler principal
$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel Highest

# Task description
$description = @"
Fulfillment Status Sync: Updates WooCommerce order status to 'completed' when orders are shipped in CounterPoint.

Flow:
1. Monitors PS_DOC_HDR.SHIP_DAT for shipped orders (SHIP_DAT is not NULL)
2. Matches CounterPoint orders to WooCommerce orders via USER_ORDER_STAGING
3. Checks current WooCommerce order status
4. Updates status to 'completed' if order is still 'processing' or 'pending'
5. Adds note: "Order fulfilled and shipped from CounterPoint. Ship Date: [date]"

Schedule: Runs every $CheckIntervalMinutes minutes
CounterPoint Indicator: PS_DOC_HDR.SHIP_DAT (not NULL = shipped)
"@

# Check if task already exists
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if ($existingTask) {
    Write-Host "Task '$TaskName' already exists. Updating..." -ForegroundColor Yellow
    Set-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description $description | Out-Null
    Write-Host "[OK] Task updated successfully" -ForegroundColor Green
} else {
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description $description | Out-Null
    Write-Host "[OK] Task created successfully" -ForegroundColor Green
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Task Details:" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Task Name: $TaskName"
Write-Host "Schedule: Every $CheckIntervalMinutes minutes"
Write-Host "Script: $wrapperScript"
Write-Host ""
Write-Host "To verify task:"
Write-Host "  Get-ScheduledTask -TaskName '$TaskName' | Get-ScheduledTaskInfo"
Write-Host ""
Write-Host "To run manually:"
Write-Host "  Start-ScheduledTask -TaskName '$TaskName'"
Write-Host ""
Write-Host "To disable:"
Write-Host "  Disable-ScheduledTask -TaskName '$TaskName'"
Write-Host ""

# Create-InventorySyncTask.ps1
# Creates Windows Task Scheduler job for inventory sync

param(
    [string]$TaskName = "WooCommerce Inventory Sync",
    [int]$IntervalHours = 12
)

$ErrorActionPreference = "Stop"

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$wrapperScript = Join-Path $scriptDir "Run-WooInventorySync-Scheduled.ps1"

if (-not (Test-Path $wrapperScript)) {
    Write-Host "ERROR: Wrapper script not found: $wrapperScript" -ForegroundColor Red
    exit 1
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Creating Task Scheduler Job: $TaskName" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
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

# Task Scheduler trigger (every N hours)
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours $IntervalHours) -RepetitionDuration (New-TimeSpan -Days 365)

# Task Scheduler settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
    -MultipleInstances IgnoreNew

# Task Scheduler principal (run as current user)
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive

# Task description
$description = "Syncs inventory levels from CounterPoint to WooCommerce. Smart sync: updates on orders/products changes, otherwise every $IntervalHours hours."

# Register the task
try {
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
    Write-Host "  Schedule: Every $IntervalHours hours (smart sync)" -ForegroundColor White
    Write-Host "  Script: $wrapperScript" -ForegroundColor White
    Write-Host "  Logic: Updates on events, otherwise every $IntervalHours hours" -ForegroundColor White
    Write-Host ""
    Write-Host "To verify:" -ForegroundColor Yellow
    Write-Host "  1. Open Task Scheduler" -ForegroundColor White
    Write-Host "  2. Find task: $TaskName" -ForegroundColor White
    Write-Host "  3. Right-click → Run (to test)" -ForegroundColor White
    Write-Host ""
    Write-Host "To monitor:" -ForegroundColor Yellow
    Write-Host "  Check logs in: $scriptDir\logs\" -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host "ERROR: Failed to create task: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Try running PowerShell as Administrator:" -ForegroundColor Yellow
    Write-Host "  1. Right-click PowerShell" -ForegroundColor White
    Write-Host "  2. Select 'Run as Administrator'" -ForegroundColor White
    Write-Host "  3. Run this script again" -ForegroundColor White
    exit 1
}

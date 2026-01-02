# Update-OrderProcessingTaskSchedule.ps1
# Updates the Task Scheduler task to use less frequent checks
# The smart check logic will still skip processing when not needed

$ErrorActionPreference = "Stop"

$TaskName = "WP_WooCommerce_Order_Processing"
$NewIntervalMinutes = 30  # Check every 30 minutes instead of 5

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Updating Task Schedule: $TaskName" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Current schedule: Every 5 minutes" -ForegroundColor Yellow
Write-Host "New schedule: Every $NewIntervalMinutes minutes" -ForegroundColor Green
Write-Host ""
Write-Host "Note: Smart check logic will still skip processing when:" -ForegroundColor White
Write-Host "  - No pending orders AND" -ForegroundColor White
Write-Host "  - Less than 2-3 hours since last successful processing" -ForegroundColor White
Write-Host ""

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "WARNING: Not running as Administrator." -ForegroundColor Yellow
    Write-Host "Task Scheduler requires admin rights to modify tasks." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

try {
    # Get the existing task
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
    
    Write-Host "Found task: $TaskName" -ForegroundColor Green
    Write-Host ""
    
    # Get current trigger
    $currentTrigger = $task.Triggers[0]
    Write-Host "Current trigger:" -ForegroundColor Yellow
    Write-Host "  Type: $($currentTrigger.GetType().Name)" -ForegroundColor White
    if ($currentTrigger.Repetition) {
        Write-Host "  Interval: $($currentTrigger.Repetition.Interval)" -ForegroundColor White
        Write-Host "  Duration: $($currentTrigger.Repetition.Duration)" -ForegroundColor White
    }
    Write-Host ""
    
    # Create new trigger with updated interval
    $newTrigger = New-ScheduledTaskTrigger `
        -Once `
        -At (Get-Date) `
        -RepetitionInterval (New-TimeSpan -Minutes $NewIntervalMinutes) `
        -RepetitionDuration (New-TimeSpan -Days 365)  # Run for 1 year (effectively indefinite)
    
    # Update the task with new trigger
    Set-ScheduledTask -TaskName $TaskName -Trigger $newTrigger
    
    Write-Host "✅ Task schedule updated successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "New schedule:" -ForegroundColor Cyan
    Write-Host "  Check frequency: Every $NewIntervalMinutes minutes" -ForegroundColor White
    Write-Host "  Processing: Event-driven (only when orders pending)" -ForegroundColor White
    Write-Host "  Fallback: Periodic check every 2-3 hours if no orders" -ForegroundColor White
    Write-Host ""
    Write-Host "To verify:" -ForegroundColor Yellow
    Write-Host "  1. Open Task Scheduler" -ForegroundColor White
    Write-Host "  2. Find task: $TaskName" -ForegroundColor White
    Write-Host "  3. Check 'Triggers' tab - should show every $NewIntervalMinutes minutes" -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host "❌ ERROR: Failed to update task: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error details:" -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

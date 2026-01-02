# Monitor-ProductSync.ps1
# Monitors product sync logs and task status

param(
    [int]$LastNHours = 24,
    [switch]$ShowDetails
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logDir = Join-Path $scriptDir "logs"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Product Catalog Sync Monitor (Phase 2)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Check Task Scheduler status
Write-Host "📅 Task Scheduler Status:" -ForegroundColor Yellow
try {
    $task = Get-ScheduledTask -TaskName "WooCommerce Product Catalog Sync" -ErrorAction SilentlyContinue
    if ($task) {
        $taskInfo = Get-ScheduledTaskInfo -TaskName "WooCommerce Product Catalog Sync"
        Write-Host "  Task Name: $($task.TaskName)" -ForegroundColor White
        Write-Host "  State: $($task.State)" -ForegroundColor $(if ($task.State -eq "Ready") { "Green" } else { "Yellow" })
        Write-Host "  Last Run: $($taskInfo.LastRunTime)" -ForegroundColor White
        Write-Host "  Last Result: $($taskInfo.LastTaskResult)" -ForegroundColor $(if ($taskInfo.LastTaskResult -eq 0) { "Green" } else { "Red" })
        Write-Host "  Next Run: $($taskInfo.NextRunTime)" -ForegroundColor White
    } else {
        Write-Host "  ⚠️  Task not found in Task Scheduler" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ❌ Error checking task: $_" -ForegroundColor Red
}
Write-Host ""

# Check log files
Write-Host "📋 Recent Log Files (Last $LastNHours hours):" -ForegroundColor Yellow
if (Test-Path $logDir) {
    $cutoffTime = (Get-Date).AddHours(-$LastNHours)
    $logFiles = Get-ChildItem -Path $logDir -Filter "woo_product_sync_*.log" | 
        Where-Object { $_.LastWriteTime -ge $cutoffTime } | 
        Sort-Object LastWriteTime -Descending
    
    if ($logFiles.Count -eq 0) {
        Write-Host "  ⚠️  No log files found in the last $LastNHours hours" -ForegroundColor Yellow
    } else {
        Write-Host "  Found $($logFiles.Count) log file(s)" -ForegroundColor White
        Write-Host ""
        
        foreach ($logFile in $logFiles | Select-Object -First 10) {
            Write-Host "  📄 $($logFile.Name)" -ForegroundColor Cyan
            Write-Host "     Modified: $($logFile.LastWriteTime)" -ForegroundColor Gray
            Write-Host "     Size: $([math]::Round($logFile.Length / 1KB, 2)) KB" -ForegroundColor Gray
            
            if ($ShowDetails) {
                Write-Host "     Content:" -ForegroundColor Gray
                Get-Content $logFile.FullName -Tail 20 | ForEach-Object {
                    if ($_ -match "ERROR|FAILED") {
                        Write-Host "       $_" -ForegroundColor Red
                    } elseif ($_ -match "SUCCESS|Created:|Updated:") {
                        Write-Host "       $_" -ForegroundColor Green
                    } else {
                        Write-Host "       $_" -ForegroundColor White
                    }
                }
            } else {
                # Quick summary
                $content = Get-Content $logFile.FullName -Raw
                if ($content -match "Created:\s*(\d+)") {
                    $created = $matches[1]
                    Write-Host "     Created: $created products" -ForegroundColor Green
                }
                if ($content -match "Updated:\s*(\d+)") {
                    $updated = $matches[1]
                    Write-Host "     Updated: $updated products" -ForegroundColor Green
                }
                if ($content -match "Errors:\s*(\d+)") {
                    $errors = $matches[1]
                    if ([int]$errors -gt 0) {
                        Write-Host "     Errors: $errors" -ForegroundColor Red
                    } else {
                        Write-Host "     Errors: 0" -ForegroundColor Green
                    }
                }
            }
            Write-Host ""
        }
    }
} else {
    Write-Host "  ⚠️  Log directory not found: $logDir" -ForegroundColor Yellow
}
Write-Host ""

# Summary
Write-Host "📊 Summary:" -ForegroundColor Yellow
$recentLogs = Get-ChildItem -Path $logDir -Filter "woo_product_sync_*.log" -ErrorAction SilentlyContinue | 
    Where-Object { $_.LastWriteTime -ge (Get-Date).AddHours(-$LastNHours) }
$successCount = 0
$errorCount = 0
$totalCreated = 0
$totalUpdated = 0

foreach ($log in $recentLogs) {
    $content = Get-Content $log.FullName -Raw
    if ($content -match "SUCCESS") { $successCount++ }
    if ($content -match "ERROR|FAILED") { $errorCount++ }
    if ($content -match "Created:\s*(\d+)") {
        $totalCreated += [int]$matches[1]
    }
    if ($content -match "Updated:\s*(\d+)") {
        $totalUpdated += [int]$matches[1]
    }
}

Write-Host "  Total Runs: $($recentLogs.Count)" -ForegroundColor White
Write-Host "  Successful: $successCount" -ForegroundColor Green
Write-Host "  With Errors: $errorCount" -ForegroundColor $(if ($errorCount -eq 0) { "Green" } else { "Red" })
Write-Host "  Total Products Created: $totalCreated" -ForegroundColor White
Write-Host "  Total Products Updated: $totalUpdated" -ForegroundColor White
Write-Host ""

Write-Host "💡 Tip: Use -ShowDetails to see full log content" -ForegroundColor Cyan
Write-Host "   Example: .\Monitor-ProductSync.ps1 -ShowDetails" -ForegroundColor Gray

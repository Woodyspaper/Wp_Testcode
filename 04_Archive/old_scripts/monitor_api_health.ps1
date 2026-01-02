# API Health Monitoring Script
# Monitors API health, error rates, and request counts
# Date: December 30, 2025

param(
    [string]$API_URL = "http://localhost:5000",
    [string]$API_KEY = "",
    [int]$CheckInterval = 60,  # seconds
    [switch]$Continuous = $false
)

# Get API key from .env if not provided
if (-not $API_KEY) {
    $envFilePath = Join-Path $PSScriptRoot ".env"
    if (Test-Path $envFilePath) {
        Get-Content $envFilePath | ForEach-Object {
            if ($_ -match "^CONTRACT_PRICING_API_KEY=(.*)$") {
                $API_KEY = $Matches[1]
            }
        }
    }
}

if (-not $API_KEY) {
    Write-Error "Error: API key not found. Please provide -API_KEY or set CONTRACT_PRICING_API_KEY in .env"
    exit 1
}

$headers = @{
    "Content-Type" = "application/json"
    "X-API-Key" = $API_KEY
}

function Test-APIHealth {
    param([string]$Url, [hashtable]$Headers)
    
    try {
        $response = Invoke-RestMethod -Uri "$Url/api/health" -Method GET -Headers $Headers -TimeoutSec 5
        return @{
            Status = "OK"
            Database = $response.database
            Timestamp = Get-Date
        }
    } catch {
        return @{
            Status = "ERROR"
            Error = $_.Exception.Message
            Timestamp = Get-Date
        }
    }
}

function Get-ErrorRate {
    param([string]$LogPath)
    
    if (-not (Test-Path $LogPath)) {
        return $null
    }
    
    $logContent = Get-Content $LogPath -Tail 100 -ErrorAction SilentlyContinue
    $errorCount = ($logContent | Select-String -Pattern "ERROR|Exception|Failed" -CaseSensitive:$false).Count
    $totalLines = $logContent.Count
    
    if ($totalLines -eq 0) {
        return $null
    }
    
    return @{
        ErrorCount = $errorCount
        TotalLines = $totalLines
        ErrorRate = [math]::Round(($errorCount / $totalLines) * 100, 2)
    }
}

function Get-RequestCount {
    param([string]$LogPath)
    
    if (-not (Test-Path $LogPath)) {
        return $null
    }
    
    $logContent = Get-Content $LogPath -Tail 100 -ErrorAction SilentlyContinue
    $requestCount = ($logContent | Select-String -Pattern "GET|POST" -CaseSensitive:$false).Count
    
    return @{
        RequestCount = $requestCount
        TimeWindow = "Last 100 log lines"
    }
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "API HEALTH MONITORING" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`nMonitoring API at: $API_URL" -ForegroundColor Cyan
Write-Host "Check interval: $CheckInterval seconds" -ForegroundColor Cyan
Write-Host "Continuous mode: $Continuous" -ForegroundColor Cyan

$logPath = Join-Path $PSScriptRoot "logs\pricing_api_waitress.log"
$alertThreshold = 10  # Error rate percentage threshold

do {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    Write-Host "`n[$timestamp] Checking API health..." -ForegroundColor Cyan
    
    # Test 1: Health Check
    $health = Test-APIHealth -Url $API_URL -Headers $headers
    if ($health.Status -eq "OK") {
        Write-Host "  [OK] API Health: $($health.Status)" -ForegroundColor Green
        Write-Host "  [OK] Database: $($health.Database)" -ForegroundColor Green
    } else {
        Write-Host "  [ALERT] API Health: $($health.Status)" -ForegroundColor Red
        Write-Host "  [ALERT] Error: $($health.Error)" -ForegroundColor Red
    }
    
    # Test 2: Error Rate
    $errorRate = Get-ErrorRate -LogPath $logPath
    if ($errorRate) {
        if ($errorRate.ErrorRate -gt $alertThreshold) {
            Write-Host "  [ALERT] Error Rate: $($errorRate.ErrorRate)% ($($errorRate.ErrorCount)/$($errorRate.TotalLines))" -ForegroundColor Red
        } else {
            Write-Host "  [OK] Error Rate: $($errorRate.ErrorRate)% ($($errorRate.ErrorCount)/$($errorRate.TotalLines))" -ForegroundColor Green
        }
    } else {
        Write-Host "  [INFO] Error rate: Unable to calculate (log file not accessible)" -ForegroundColor Yellow
    }
    
    # Test 3: Request Count
    $requestCount = Get-RequestCount -LogPath $logPath
    if ($requestCount) {
        Write-Host "  [INFO] Requests: $($requestCount.RequestCount) ($($requestCount.TimeWindow))" -ForegroundColor White
    } else {
        Write-Host "  [INFO] Request count: Unable to calculate (log file not accessible)" -ForegroundColor Yellow
    }
    
    # Test 4: Service Status (Windows only)
    try {
        $service = Get-Service -Name "ContractPricingAPIWaitress" -ErrorAction SilentlyContinue
        if ($service) {
            if ($service.Status -eq "Running") {
                Write-Host "  [OK] Service Status: $($service.Status)" -ForegroundColor Green
            } else {
                Write-Host "  [ALERT] Service Status: $($service.Status)" -ForegroundColor Red
            }
        }
    } catch {
        # Service check failed (may not be Windows or service not found)
    }
    
    if ($Continuous) {
        Write-Host "`nWaiting $CheckInterval seconds until next check..." -ForegroundColor Gray
        Start-Sleep -Seconds $CheckInterval
    }
    
} while ($Continuous)

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "MONITORING COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

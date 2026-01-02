# Setup-EmailAlerts.ps1
# Quick setup script for email alerts
# Configures michaelbryan@woodyspaper.com to receive all order processing alerts

$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Email Alerts Setup - Order Processing" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Email configuration
$alertEmail = "michaelbryan@woodyspaper.com"
$smtpServer = "smtp.woodyspaper.com"
$smtpPort = "587"
$fromEmail = "noreply@woodyspaper.com"

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Alert Email: $alertEmail" -ForegroundColor White
Write-Host "  SMTP Server: $smtpServer" -ForegroundColor White
Write-Host "  SMTP Port: $smtpPort" -ForegroundColor White
Write-Host "  From Email: $fromEmail" -ForegroundColor White
Write-Host ""

# Set environment variables (Machine-level for persistence)
try {
    Write-Host "Setting environment variables..." -ForegroundColor Yellow
    
    [System.Environment]::SetEnvironmentVariable('ORDER_PROCESSING_ALERT_EMAIL', $alertEmail, 'Machine')
    Write-Host "  ✅ ORDER_PROCESSING_ALERT_EMAIL set" -ForegroundColor Green
    
    [System.Environment]::SetEnvironmentVariable('ORDER_PROCESSING_SMTP_SERVER', $smtpServer, 'Machine')
    Write-Host "  ✅ ORDER_PROCESSING_SMTP_SERVER set" -ForegroundColor Green
    
    [System.Environment]::SetEnvironmentVariable('ORDER_PROCESSING_SMTP_PORT', $smtpPort, 'Machine')
    Write-Host "  ✅ ORDER_PROCESSING_SMTP_PORT set" -ForegroundColor Green
    
    [System.Environment]::SetEnvironmentVariable('ORDER_PROCESSING_ALERT_FROM', $fromEmail, 'Machine')
    Write-Host "  ✅ ORDER_PROCESSING_ALERT_FROM set" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "✅ Environment variables set successfully!" -ForegroundColor Green
    Write-Host ""
    
} catch {
    Write-Host "❌ ERROR: Failed to set environment variables: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "You may need to run PowerShell as Administrator." -ForegroundColor Yellow
    exit 1
}

# Verify settings
Write-Host "Verifying settings..." -ForegroundColor Yellow
$verifyEmail = [System.Environment]::GetEnvironmentVariable('ORDER_PROCESSING_ALERT_EMAIL', 'Machine')
$verifySmtp = [System.Environment]::GetEnvironmentVariable('ORDER_PROCESSING_SMTP_SERVER', 'Machine')
$verifyPort = [System.Environment]::GetEnvironmentVariable('ORDER_PROCESSING_SMTP_PORT', 'Machine')
$verifyFrom = [System.Environment]::GetEnvironmentVariable('ORDER_PROCESSING_ALERT_FROM', 'Machine')

if ($verifyEmail -eq $alertEmail) {
    Write-Host "  ✅ Alert email verified: $verifyEmail" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Alert email mismatch: $verifyEmail" -ForegroundColor Yellow
}

if ($verifySmtp -eq $smtpServer) {
    Write-Host "  ✅ SMTP server verified: $verifySmtp" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  SMTP server mismatch: $verifySmtp" -ForegroundColor Yellow
}

if ($verifyPort -eq $smtpPort) {
    Write-Host "  ✅ SMTP port verified: $verifyPort" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  SMTP port mismatch: $verifyPort" -ForegroundColor Yellow
}

if ($verifyFrom -eq $fromEmail) {
    Write-Host "  ✅ From email verified: $verifyFrom" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  From email mismatch: $verifyFrom" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "NEXT STEPS" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Restart the Task Scheduler task to pick up new variables:" -ForegroundColor Yellow
Write-Host "   - Open Task Scheduler" -ForegroundColor White
Write-Host "   - Find: WP_WooCommerce_Order_Processing" -ForegroundColor White
Write-Host "   - Right-click → End → Then Run (to restart)" -ForegroundColor White
Write-Host ""
Write-Host "2. Test email alerts:" -ForegroundColor Yellow
Write-Host "   python check_order_processing_health.py" -ForegroundColor White
Write-Host ""
Write-Host "3. Alerts will be sent for:" -ForegroundColor Yellow
Write-Host "   - Order processing failures" -ForegroundColor White
Write-Host "   - Critical health issues" -ForegroundColor White
Write-Host "   - Failed orders requiring attention" -ForegroundColor White
Write-Host ""
Write-Host "✅ Email alerts configured!" -ForegroundColor Green
Write-Host ""

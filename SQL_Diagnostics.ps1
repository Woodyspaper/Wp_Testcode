"""
REMOTE DIAGNOSTIC SCRIPT FOR ADWPC-MAIN
========================================
Run this script DIRECTLY on ADWPC-MAIN (via RDP)
to diagnose SQL Server authentication and credential issues.

This is a PowerShell script that gathers all necessary information.
"""

# Save as: C:\temp\SQL_Diagnostics.ps1
# Run as Administrator on ADWPC-MAIN

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "SQL Server Diagnostics for ADWPC-MAIN"
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check SQL Server Service Status
Write-Host "[1] SQL SERVER SERVICE STATUS" -ForegroundColor Yellow
Write-Host "------------------------------"
$service = Get-Service -Name MSSQLSERVER -ErrorAction SilentlyContinue
if ($service) {
    Write-Host "  Service: $($service.DisplayName)" -ForegroundColor Green
    Write-Host "  Status: $($service.Status)" -ForegroundColor $(if ($service.Status -eq 'Running') { 'Green' } else { 'Red' })
    Write-Host "  Startup Type: $($service.StartType)" -ForegroundColor Green
} else {
    Write-Host "  ERROR: SQL Server service not found" -ForegroundColor Red
}
Write-Host ""

# 2. Check Authentication Mode
Write-Host "[2] SQL SERVER AUTHENTICATION MODE" -ForegroundColor Yellow
Write-Host "-----------------------------------"
try {
    $regPath = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQLServer'
    $loginMode = (Get-ItemProperty -Path $regPath -Name LoginMode -ErrorAction Stop).LoginMode
    
    $modeText = switch ($loginMode) {
        1 { "Windows Authentication ONLY (❌ Need Mixed Mode)" }
        2 { "Mixed Mode - Windows + SQL Server (✅ GOOD)" }
        default { "Unknown mode: $loginMode" }
    }
    
    Write-Host "  LoginMode Registry Value: $loginMode" -ForegroundColor Cyan
    Write-Host "  Interpretation: $modeText" -ForegroundColor $(if ($loginMode -eq 2) { 'Green' } else { 'Red' })
} catch {
    Write-Host "  ERROR: Could not read LoginMode registry" -ForegroundColor Red
    Write-Host "  Exception: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# 3. Check sa Account Status
Write-Host "[3] SQL SERVER LOGINS (sa, CPSQL, CCCI)" -ForegroundColor Yellow
Write-Host "----------------------------------------"

$sqlQuery = @"
SET NOCOUNT ON;
SELECT 
    name as 'Login',
    is_disabled as 'Disabled',
    create_date as 'Created',
    CAST(CASE WHEN create_date > DATEADD(DAY, -30, GETDATE()) THEN 'RECENT' ELSE 'OLD' END AS VARCHAR(10)) as 'Age'
FROM sys.server_principals
WHERE name IN ('sa', 'CPSQL', 'CCCI')
ORDER BY name;
"@

try {
    # Try with Windows auth first
    $result = Invoke-Sqlcmd -ServerInstance "ADWPC-MAIN" -Query $sqlQuery -ErrorAction Stop
    Write-Host "  ✅ Connected with Windows Authentication" -ForegroundColor Green
    
    if ($result) {
        $result | Format-Table -AutoSize
    } else {
        Write-Host "  No results - logins may not exist" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ⚠️ Windows auth failed, trying sa account..." -ForegroundColor Yellow
    
    try {
        $result = Invoke-Sqlcmd -ServerInstance "ADWPC-MAIN" -Username "sa" -Password "Wpsccc2224!" -Query $sqlQuery -ErrorAction Stop
        Write-Host "  ✅ Connected with sa credentials" -ForegroundColor Green
        
        if ($result) {
            $result | Format-Table -AutoSize
        }
    } catch {
        Write-Host "  ❌ Both auth methods failed" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}
Write-Host ""

# 4. Check TCP/IP Port 1433
Write-Host "[4] TCP/IP PORT 1433 (SQL Server Port)" -ForegroundColor Yellow
Write-Host "---------------------------------------"

try {
    $tcpCheck = netstat -ano | Select-String "1433"
    if ($tcpCheck) {
        Write-Host "  ✅ Port 1433 is LISTENING" -ForegroundColor Green
        Write-Host "  Details:" -ForegroundColor Cyan
        $tcpCheck | ForEach-Object { Write-Host "    $_" }
    } else {
        Write-Host "  ❌ Port 1433 is NOT LISTENING" -ForegroundColor Red
    }
} catch {
    Write-Host "  ERROR checking port: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# 5. Check Firewall
Write-Host "[5] WINDOWS FIREWALL - Port 1433" -ForegroundColor Yellow
Write-Host "---------------------------------"

try {
    $fwRules = Get-NetFirewallRule -DisplayName "*1433*" -ErrorAction SilentlyContinue
    if ($fwRules) {
        Write-Host "  ✅ Found firewall rules for port 1433:" -ForegroundColor Green
        $fwRules | Select-Object DisplayName, Enabled, Direction | Format-Table -AutoSize
    } else {
        Write-Host "  ⚠️ No specific firewall rules found for 1433" -ForegroundColor Yellow
        Write-Host "  (SQL Server may be using default rules)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ERROR checking firewall: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# 6. Check SQL Server Error Log (Recent Errors)
Write-Host "[6] RECENT SQL SERVER ERRORS (Error Log)" -ForegroundColor Yellow
Write-Host "----------------------------------------"

try {
    $errorLogQuery = @"
EXEC xp_readerrorlog 0, 1, 'Error', NULL;
"@
    
    $errors = Invoke-Sqlcmd -ServerInstance "ADWPC-MAIN" -Query $errorLogQuery -ErrorAction Stop 2>$null
    
    if ($errors) {
        Write-Host "  Found recent errors:" -ForegroundColor Cyan
        $errors | Select-Object -First 10 | Format-Table -AutoSize
    } else {
        Write-Host "  ✅ No recent errors in SQL Server log" -ForegroundColor Green
    }
} catch {
    Write-Host "  Could not query error log (may need admin rights in SQL)" -ForegroundColor Yellow
}
Write-Host ""

# 7. Test Connection with Credentials
Write-Host "[7] CONNECTION TEST" -ForegroundColor Yellow
Write-Host "-------------------"

$credentials = @(
    @{User="sa"; Pass="Wpsccc2224!"; Label="sa account"}
    @{User="CPSQL"; Pass="WPSccc2224!"; Label="CPSQL account"}
)

foreach ($cred in $credentials) {
    try {
        $testQuery = "SELECT @@VERSION as Version"
        $result = Invoke-Sqlcmd -ServerInstance "ADWPC-MAIN" -Username $cred.User -Password $cred.Pass -Query $testQuery -ConnectionTimeout 5
        Write-Host "  ✅ $($cred.Label) - CONNECTION SUCCESS" -ForegroundColor Green
        Write-Host "     SQL Server: $($result.Version)" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ $($cred.Label) - CONNECTION FAILED" -ForegroundColor Red
        Write-Host "     Error: $($_.Exception.Message.Split("`n")[0])" -ForegroundColor Red
    }
}
Write-Host ""

# 8. Summary & Recommendations
Write-Host "[8] SUMMARY & RECOMMENDATIONS" -ForegroundColor Yellow
Write-Host "-----------------------------"
Write-Host ""
Write-Host "If you see ✅ for:" -ForegroundColor Cyan
Write-Host "  • Service Status: Running"
Write-Host "  • Authentication Mode: Mixed Mode"
Write-Host "  • Port 1433: Listening"
Write-Host "  • Connection Test: SUCCESS"
Write-Host ""
Write-Host "Then SQL Server is configured correctly!" -ForegroundColor Green
Write-Host ""
Write-Host "If you see ❌ for authentication mode or connection tests:" -ForegroundColor Red
Write-Host "  1. Open SQL Server Configuration Manager"
Write-Host "  2. Right-click 'SQL Server (MSSQLSERVER)' → Properties"
Write-Host "  3. Security tab → Change to 'SQL Server and Windows Authentication mode'"
Write-Host "  4. Click OK"
Write-Host "  5. Right-click 'SQL Server (MSSQLSERVER)' → Restart"
Write-Host ""

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "End of Diagnostics"
Write-Host "======================================" -ForegroundColor Cyan

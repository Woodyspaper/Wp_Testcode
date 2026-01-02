# Run-WooOrderProcessing-Scheduled.ps1
# Simplified wrapper for Task Scheduler (reads from .env or uses defaults)

$ErrorActionPreference = "Stop"

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

# Log directory
$logDir = Join-Path $scriptDir "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath = Join-Path $logDir "woo_order_processing_$ts.log"

function Log($msg) {
  $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg
  Write-Host $line
  $line | Out-File -FilePath $logPath -Append -Encoding UTF8
}

function Send-EmailAlert {
    param(
        [string]$Subject,
        [string]$Body,
        [string[]]$To = @(),
        [string]$SmtpServer = $null,
        [int]$SmtpPort = 25,
        [string]$From = $null
    )
    
    # Check if email is configured
    if (-not $To -or $To.Count -eq 0) {
        # Try to get from environment variable
        $To = $env:ORDER_PROCESSING_ALERT_EMAIL -split ','
    }
    
    if (-not $To -or $To.Count -eq 0) {
        Log "INFO: Email alerts not configured (set ORDER_PROCESSING_ALERT_EMAIL environment variable)"
        return
    }
    
    # Get SMTP server from environment or use default
    if (-not $SmtpServer) {
        $SmtpServer = $env:ORDER_PROCESSING_SMTP_SERVER
        if (-not $SmtpServer) {
            # Try to detect from email domain
            $emailDomain = ($To[0] -split '@')[1]
            if ($emailDomain) {
                $SmtpServer = "smtp.$emailDomain"
            } else {
                Log "WARNING: Cannot determine SMTP server, skipping email alert"
                return
            }
        }
    }
    
    # Get From address
    if (-not $From) {
        $From = $env:ORDER_PROCESSING_ALERT_FROM
        if (-not $From) {
            $From = $To[0]  # Use first recipient as sender
        }
    }
    
    try {
        $mailParams = @{
            From = $From
            To = $To
            Subject = $Subject
            Body = $Body
            SmtpServer = $SmtpServer
            Port = $SmtpPort
            UseSsl = $false
        }
        
        # Try SSL if port is 587 or 465
        if ($SmtpPort -eq 587 -or $SmtpPort -eq 465) {
            $mailParams['UseSsl'] = $true
        }
        
        Send-MailMessage @mailParams -ErrorAction Stop
        Log "Email alert sent to: $($To -join ', ')"
    } catch {
        Log "WARNING: Failed to send email alert: $_"
        # Don't fail the script if email fails
    }
}

Log "============================================================"
Log "Order Processing: Staged Orders → CounterPoint"
Log "============================================================"
Log "Started at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Log "Script directory: $scriptDir"
Log "Log file: $logPath"

# Find Python executable
$pythonExe = "python"
try {
    $pythonVersion = & $pythonExe --version 2>&1
    Log "Python found: $pythonVersion"
} catch {
    Log "ERROR: Python not found in PATH. Trying common locations..."
    $commonPaths = @(
        "C:\Program Files\Python314\python.exe",
        "C:\Python314\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python314\python.exe"
    )
    $found = $false
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            $pythonExe = $path
            Log "Python found at: $pythonExe"
            $found = $true
            break
        }
    }
    if (-not $found) {
        Log "ERROR: Python not found. Please install Python or update PATH."
        exit 1
    }
}

# Find scripts
$processorScript = Join-Path $scriptDir "cp_order_processor.py"
$checkScript = Join-Path $scriptDir "check_order_processing_needed.py"

if (-not (Test-Path $processorScript)) {
    Log "ERROR: Script not found: $processorScript"
    exit 1
}
Log "Processor script: $processorScript"

# Check if processing is needed (smart check logic)
Log "Checking if order processing is needed..."
if (Test-Path $checkScript) {
    try {
        $checkOutput = & $pythonExe $checkScript 2>&1
        $checkOutput | ForEach-Object { Log $_ }
        $checkExitCode = $LASTEXITCODE
        
        if ($checkExitCode -eq 1) {
            # Processing not needed
            Log "============================================================"
            Log "SKIPPED: Order processing not needed at this time"
            Log "Reason: No pending orders or too soon for periodic check"
            Log "============================================================"
            Log "Completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            Log "Log file: $logPath"
            exit 0
        }
        # Exit code 0 means processing is needed, continue below
        Log "Processing is needed - proceeding..."
    } catch {
        Log "WARNING: Could not check processing conditions, proceeding with processing: $_"
        # On error, default to processing (safe fallback)
    }
} else {
    Log "WARNING: check_order_processing_needed.py not found, proceeding with processing"
}

# Run order processing
Log "Starting order processing..."
try {
    # Create temporary output file
    $tempOutput = Join-Path $logDir "temp_output_$ts.txt"
    
    # Run Python script and capture output
    $process = Start-Process -FilePath $pythonExe -ArgumentList @("`"$processorScript`"", "process", "--all") -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tempOutput -RedirectStandardError "$tempOutput.err"
    $exitCode = $process.ExitCode
    
    # Read and log output
    if (Test-Path $tempOutput) {
        $output = Get-Content $tempOutput -Raw
        $output -split "`n" | ForEach-Object { Log $_ }
        Remove-Item $tempOutput -ErrorAction SilentlyContinue
    }
    
    # Read and log errors
    if (Test-Path "$tempOutput.err") {
        $errors = Get-Content "$tempOutput.err" -Raw
        if ($errors) {
            $errors -split "`n" | ForEach-Object { Log "STDERR: $_" }
        }
        Remove-Item "$tempOutput.err" -ErrorAction SilentlyContinue
    }
    
    if ($exitCode -ne 0) {
        Log "ERROR: Order processing failed with exit code $exitCode"
        
        # Send email alert for processing failure
        $emailBody = @"
Order processing failed with exit code $exitCode.

Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Log file: $logPath

Please check the logs for details.
"@
        Send-EmailAlert -Subject "ALERT: Order Processing Failed" -Body $emailBody
        exit $exitCode
    }
    
    # Extract summary
    $successful = ($output | Select-String -Pattern "Successful:\s*(\d+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }) -join ", "
    $failed = ($output | Select-String -Pattern "Failed:\s*(\d+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }) -join ", "
    
    Log "============================================================"
    Log "Summary:"
    Log "  Successful: $successful"
    Log "  Failed: $failed"
    Log "============================================================"
    
    if ($failed -eq "0" -or $failed -eq "") {
        Log "SUCCESS: Order processing completed successfully."
    } else {
        Log "WARNING: Order processing completed with some failures."
        
        # Send email alert for failed orders
        $emailBody = @"
Order processing completed with failures.

Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Successful: $successful
Failed: $failed
Log file: $logPath

Please review failed orders using:
  python cp_order_processor.py list
  -- OR --
  Run: 02_Testing/FIND_FAILED_ORDERS.sql
"@
        Send-EmailAlert -Subject "WARNING: Order Processing Failures" -Body $emailBody
    }
    
    Log "Completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Log "Log file: $logPath"
    exit 0
    
} catch {
    Log "ERROR: Exception occurred: $_"
    Log "Stack trace: $($_.ScriptStackTrace)"
    
    # Send email alert for critical exception
    $emailBody = @"
CRITICAL ERROR: Order processing script crashed.

Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Error: $_
Stack trace: $($_.ScriptStackTrace)
Log file: $logPath

Immediate attention required!
"@
    Send-EmailAlert -Subject "CRITICAL: Order Processing Script Error" -Body $emailBody
    exit 1
}

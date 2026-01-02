# Email Alerts Setup

**Date:** January 2, 2026  
**Purpose:** Configure email alerts for order processing failures

**Primary Recipient:** `michaelbryan@woodyspaper.com`

---

## ✅ **WHAT'S IMPLEMENTED**

Email alerts are now built into:
- ✅ `Run-WooOrderProcessing-Scheduled.ps1` - Sends alerts on processing failures
- ✅ `check_order_processing_health.py` - Sends alerts on critical health issues

---

## ⚙️ **CONFIGURATION**

### **Option 1: Environment Variables (Recommended)**

Set these environment variables:

```powershell
# Required: Email addresses to receive alerts (comma-separated)
$env:ORDER_PROCESSING_ALERT_EMAIL = "michaelbryan@woodyspaper.com"

# Optional: SMTP server (auto-detected if not set)
# For woodyspaper.com, will auto-detect as smtp.woodyspaper.com if not specified
$env:ORDER_PROCESSING_SMTP_SERVER = "smtp.woodyspaper.com"

# Optional: SMTP port (default: 25)
$env:ORDER_PROCESSING_SMTP_PORT = "587"

# Optional: From address (defaults to first recipient)
$env:ORDER_PROCESSING_ALERT_FROM = "noreply@woodyspaper.com"
```

**To make permanent (System-wide):**
```powershell
# Set email address for all alerts
[System.Environment]::SetEnvironmentVariable('ORDER_PROCESSING_ALERT_EMAIL', 'michaelbryan@woodyspaper.com', 'Machine')

# Optional: Set SMTP server
[System.Environment]::SetEnvironmentVariable('ORDER_PROCESSING_SMTP_SERVER', 'smtp.woodyspaper.com', 'Machine')

# Optional: Set SMTP port
[System.Environment]::SetEnvironmentVariable('ORDER_PROCESSING_SMTP_PORT', '587', 'Machine')

# Optional: Set From address
[System.Environment]::SetEnvironmentVariable('ORDER_PROCESSING_ALERT_FROM', 'noreply@woodyspaper.com', 'Machine')
```

**After setting, restart Task Scheduler task** to pick up new environment variables.

---

### **Option 2: Set in Task Scheduler**

1. Open Task Scheduler
2. Find task: `WP_WooCommerce_Order_Processing`
3. Right-click → Properties
4. Go to "Actions" tab
5. Edit the action
6. Add environment variables to "Start in" or use "Add arguments"

---

## 📧 **WHEN ALERTS ARE SENT**

### **Critical Alerts:**
- ❌ Order processing script crashes (exception)
- ❌ Processing fails with error code
- ❌ Health check detects critical issues

### **Warning Alerts:**
- ⚠️ Orders processed with some failures
- ⚠️ Health check detects warnings

---

## 🧪 **TESTING EMAIL ALERTS**

### **Test 1: Test Email Configuration**

```powershell
# Set test email
$env:ORDER_PROCESSING_ALERT_EMAIL = "your-email@example.com"

# Run health check (should send email if critical)
python check_order_processing_health.py
```

### **Test 2: Simulate Failure**

```powershell
# Temporarily break the script to test alerts
# Or manually trigger a processing failure
```

---

## 📋 **EMAIL ALERT CONTENT**

### **Processing Failure Alert:**
```
Subject: ALERT: Order Processing Failed

Order processing failed with exit code 1.

Time: 2026-01-02 10:30:00
Log file: C:\path\to\logs\woo_order_processing_20260102_103000.log

Please check the logs for details.
```

### **Failed Orders Alert:**
```
Subject: WARNING: Order Processing Failures

Order processing completed with failures.

Time: 2026-01-02 10:30:00
Successful: 5
Failed: 2
Log file: C:\path\to\logs\woo_order_processing_20260102_103000.log

Please review failed orders using:
  python cp_order_processor.py list
  -- OR --
  Run: 01_Production/FIND_FAILED_ORDERS.sql
```

### **Critical Health Alert:**
```
Subject: CRITICAL: Order Processing System Issues

CRITICAL: Order Processing System Issues Detected

Issues:
  - CRITICAL: Orders pending > 2 hours (3 orders)
  - CRITICAL: 5 orders failed > 1 hour ago

Recommended actions:
  1. Check logs: logs/woo_order_processing_*.log
  2. Check Task Scheduler: WP_WooCommerce_Order_Processing
  3. Check failed orders: python cp_order_processor.py list
  4. Manually process: python cp_order_processor.py process --all
```

---

## ⚠️ **TROUBLESHOOTING**

### **Email Not Sending:**

1. **Check Environment Variables:**
   ```powershell
   $env:ORDER_PROCESSING_ALERT_EMAIL
   ```

2. **Check SMTP Server:**
   ```powershell
   $env:ORDER_PROCESSING_SMTP_SERVER
   ```

3. **Test SMTP Connection:**
   ```powershell
   Test-NetConnection -ComputerName smtp.example.com -Port 587
   ```

4. **Check Firewall:**
   - Ensure SMTP port (25, 587, or 465) is open
   - Check Windows Firewall rules

5. **Check Logs:**
   - Look for "WARNING: Failed to send email alert" in logs
   - Email failures don't stop processing (non-blocking)

---

## 🔒 **SECURITY NOTES**

- **SMTP Credentials:** If your SMTP server requires authentication, you may need to:
  - Use Windows authentication
  - Store credentials securely (Windows Credential Manager)
  - Or use a service account with email permissions

- **TLS/SSL:** 
  - Port 587 typically uses STARTTLS
  - Port 465 typically uses SSL
  - Port 25 is usually unencrypted (not recommended)

---

## 📝 **QUICK SETUP**

**Easiest Method (Run as Administrator):**

```powershell
# Run the automated setup script
.\Setup-EmailAlerts.ps1
```

This will configure:
- Alert email: `michaelbryan@woodyspaper.com`
- SMTP server: `smtp.woodyspaper.com`
- All error logs and updates will be sent

**Manual Setup (5 minutes):**

1. **Set email address:**
   ```powershell
   [System.Environment]::SetEnvironmentVariable('ORDER_PROCESSING_ALERT_EMAIL', 'michaelbryan@woodyspaper.com', 'Machine')
   ```

2. **Restart Task Scheduler task** (to pick up new environment variable)

3. **Test:**
   ```powershell
   python check_order_processing_health.py
   ```

---

**Last Updated:** January 2, 2026  
**Status:** ✅ **IMPLEMENTED - Ready to Configure**

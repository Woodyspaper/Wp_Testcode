# Order Processing Task Setup - Complete

**Date:** December 31, 2025  
**Status:** ✅ **TASK CREATED SUCCESSFULLY**

---

## ✅ **TASK CREATED**

**Task Name:** `WP_WooCommerce_Order_Processing`  
**Schedule:** Every 5 minutes (check frequency)  
**Processing:** Event-driven (only when orders pending)  
**Fallback:** Periodic check every 2-3 hours

---

## 📋 **WHAT IT DOES**

### **Complete Order Processing Flow:**

1. **Smart Check** - Checks `USER_ORDER_STAGING` for pending orders (`IS_APPLIED = 0`)
2. **Validation** - Validates orders using `sp_ValidateStagedOrder`
3. **Order Creation** - Creates CounterPoint sales tickets:
   - **PS_DOC_HDR** - Sales ticket header (DOC_ID, TKT_NO, CUST_NO, etc.)
   - **PS_DOC_LIN** - Sales ticket line items (ITEM_NO, QTY_SOLD, EXT_PRC, etc.)
   - **PS_DOC_HDR_TOT** - Sales ticket totals (SUBTOT, TAX_AMT, TOT_AMT, etc.)
4. **Status Update** - Updates staging record with DOC_ID and TKT_NO
5. **WooCommerce Sync** - Syncs order status back to WooCommerce (status + notes)

---

## 🔧 **TASK CONFIGURATION**

### **Schedule:**
- **Frequency:** Every 5 minutes
- **Duration:** 1 year (effectively indefinite)
- **Start:** Immediately

### **Processing Logic:**
- **Pending Orders:** Process immediately (no delay)
- **No Orders:** Skip (efficient)
- **Periodic Fallback:** Check every 2-3 hours even if no orders

### **Settings:**
- **Execution Time Limit:** 30 minutes per run
- **Multiple Instances:** Ignore new (if previous run still running)
- **Network Required:** Yes
- **Run on Batteries:** Allowed

---

## 📊 **COUNTERPOINT TERMINOLOGY**

The task uses proper CounterPoint/NCR terminology:

| Term | CounterPoint Table/Field | Description |
|------|-------------------------|-------------|
| **Sales Ticket** | PS_DOC_HDR | Order document header |
| **Document ID** | DOC_ID | Unique identifier (bigint) |
| **Ticket Number** | TKT_NO | Human-readable order number (e.g., "101-000001") |
| **Line Items** | PS_DOC_LIN | Order line items |
| **Document Totals** | PS_DOC_HDR_TOT | Order totals (subtotal, tax, total) |
| **Customer Number** | CUST_NO | Customer identifier (from AR_CUST) |
| **Item Number** | ITEM_NO | Product SKU (from IM_ITEM) |
| **Quantity Sold** | QTY_SOLD | Order quantity |
| **Extended Price** | EXT_PRC | Line item total (quantity × price) |

---

## 🧪 **VERIFICATION**

### **Check Task Status:**

```powershell
# View task details
Get-ScheduledTask -TaskName "WP_WooCommerce_Order_Processing" | Format-List

# Check last run result
$task = Get-ScheduledTask -TaskName "WP_WooCommerce_Order_Processing"
Get-ScheduledTaskInfo $task | Select-Object LastRunTime, LastTaskResult, NextRunTime
```

### **Test Task Manually:**

```powershell
# Run task manually
Start-ScheduledTask -TaskName "WP_WooCommerce_Order_Processing"

# Wait a moment, then check result
Start-Sleep -Seconds 5
$task = Get-ScheduledTask -TaskName "WP_WooCommerce_Order_Processing"
Get-ScheduledTaskInfo $task | Select-Object LastTaskResult
# Result should be 0x0 (success) or 0x1 (success with no processing needed)
```

### **Check Logs:**

```powershell
# View recent log files
Get-ChildItem "logs\woo_order_processing_*.log" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1 | 
    Get-Content -Tail 50
```

### **Check Pending Orders:**

```powershell
# List pending orders
python cp_order_processor.py list

# Check specific order
python cp_order_processor.py show <STAGING_ID>
```

---

## 📝 **MONITORING QUERIES**

### **Check Pending Orders:**

```sql
-- View pending orders
SELECT 
    STAGING_ID,
    WOO_ORDER_ID,
    CUST_NO,
    ORD_DAT,
    TOT_AMT,
    IS_VALIDATED,
    VALIDATION_ERROR,
    CREATED_DT,
    DATEDIFF(MINUTE, CREATED_DT, GETDATE()) AS MinutesWaiting
FROM dbo.USER_ORDER_STAGING
WHERE IS_APPLIED = 0
ORDER BY CREATED_DT ASC;
```

### **Check Processed Orders:**

```sql
-- View recently processed orders
SELECT TOP 20
    STAGING_ID,
    WOO_ORDER_ID,
    CUST_NO,
    CP_DOC_ID,
    TOT_AMT,
    APPLIED_DT,
    DATEDIFF(MINUTE, CREATED_DT, APPLIED_DT) AS ProcessingTimeMinutes
FROM dbo.USER_ORDER_STAGING
WHERE IS_APPLIED = 1
ORDER BY APPLIED_DT DESC;
```

### **Check CounterPoint Orders:**

```sql
-- View recent sales tickets created
SELECT TOP 20
    DOC_ID,
    TKT_NO,
    CUST_NO,
    TKT_DT,
    TOT_AMT,
    DOC_STAT
FROM dbo.PS_DOC_HDR
WHERE TKT_DT >= DATEADD(DAY, -1, GETDATE())
ORDER BY TKT_DT DESC;
```

---

## ⚠️ **TROUBLESHOOTING**

### **Task Not Running:**

1. **Check Task Status:**
   ```powershell
   Get-ScheduledTask -TaskName "WP_WooCommerce_Order_Processing" | Select-Object State
   ```
   - Should be `Ready` or `Running`
   - If `Disabled`, enable it:
     ```powershell
     Enable-ScheduledTask -TaskName "WP_WooCommerce_Order_Processing"
     ```

2. **Check Last Run Result:**
   ```powershell
   $task = Get-ScheduledTask -TaskName "WP_WooCommerce_Order_Processing"
   Get-ScheduledTaskInfo $task | Select-Object LastTaskResult
   ```
   - `0x0` = Success
   - `0x1` = Success (no processing needed)
   - Other codes = Error (check logs)

3. **Check Logs:**
   ```powershell
   Get-ChildItem "logs\woo_order_processing_*.log" | 
       Sort-Object LastWriteTime -Descending | 
       Select-Object -First 1 | 
       Get-Content -Tail 100
   ```

### **Orders Not Processing:**

1. **Check if orders are pending:**
   ```powershell
   python cp_order_processor.py list
   ```

2. **Manually process:**
   ```powershell
   python cp_order_processor.py process --all
   ```

3. **Check validation errors:**
   ```sql
   SELECT STAGING_ID, VALIDATION_ERROR
   FROM dbo.USER_ORDER_STAGING
   WHERE IS_APPLIED = 0 AND VALIDATION_ERROR IS NOT NULL;
   ```

### **Task Fails to Start:**

1. **Check Python path:**
   - Task uses `python` from PATH
   - If not found, script tries common locations
   - Check logs for Python path errors

2. **Check script paths:**
   - Verify `Run-WooOrderProcessing-Scheduled.ps1` exists
   - Verify `cp_order_processor.py` exists
   - Verify `check_order_processing_needed.py` exists

3. **Check permissions:**
   - Task runs as current user
   - User must have access to:
     - Script directory
     - Database (WOODYS_CP)
     - Log directory

---

## 🎯 **NEXT STEPS**

1. ✅ **Task Created** - Task is set up and ready
2. ⏳ **Monitor First Run** - Watch logs for first execution
3. ⏳ **Test with Sample Order** - Create test order to verify processing
4. ⏳ **Verify CounterPoint** - Check PS_DOC_HDR for created orders
5. ⏳ **Verify WooCommerce** - Check order status sync

---

## 📚 **RELATED FILES**

- **Task Creation Script:** `Create-OrderProcessingTask.ps1`
- **Wrapper Script:** `Run-WooOrderProcessing-Scheduled.ps1`
- **Processor Script:** `cp_order_processor.py`
- **Check Script:** `check_order_processing_needed.py`
- **Stored Procedures:**
  - `sp_ValidateStagedOrder`
  - `sp_CreateOrderFromStaging`
  - `sp_CreateOrderLines`

---

**Last Updated:** December 31, 2025

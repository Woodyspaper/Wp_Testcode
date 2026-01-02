# CounterPoint Update Testing Process

**Date:** January 2, 2026  
**Purpose:** Systematic testing process after every CounterPoint update  
**Status:** ✅ **READY FOR USE**

---

## 🎯 **PURPOSE**

**Every time CounterPoint is updated, we must test the system** because:
- Database schema may change
- Column names may change
- Business rules may change
- Required fields may change
- Views may break

**This process ensures we catch issues before they affect production.**

---

## 📋 **PRE-UPDATE CHECKLIST**

### **Before CounterPoint Update:**

- [ ] **Review NCR Release Notes**
  - Check for database schema changes
  - Check for table/column changes
  - Check for new required fields
  - Check for deprecated features

- [ ] **Backup Current System**
  - Backup `USER_ORDER_STAGING` table
  - Backup `USER_CUSTOMER_STAGING` table
  - Document current CounterPoint version

- [ ] **Document Current State**
  - Run health check: `python check_order_processing_health.py`
  - Note any pending orders
  - Note any failed orders

---

## 🧪 **POST-UPDATE TESTING CHECKLIST**

### **Step 1: Basic Connectivity** (5 minutes)

```powershell
# Test database connection
python -c "from database import get_connection; conn = get_connection(); print('✅ Connected'); conn.close()"
```

**Expected:** Connection successful  
**If fails:** Check SQL Server is running, check connection string in `.env`

---

### **Step 2: View Verification** (10 minutes)

```sql
-- Test all views we depend on
SELECT TOP 1 * FROM dbo.VI_EXPORT_PRODUCTS;
SELECT TOP 1 * FROM dbo.VI_INVENTORY_SYNC;
SELECT TOP 1 * FROM dbo.VI_PRODUCT_NCR_TYPE;
SELECT TOP 1 * FROM dbo.VI_EXPORT_CP_ORDERS;
```

**Expected:** All views return data  
**If fails:** View may have been dropped or schema changed - check NCR release notes

---

### **Step 3: Stored Procedure Verification** (15 minutes)

```sql
-- Test stored procedures exist
SELECT name FROM sys.procedures 
WHERE name IN ('sp_ValidateStagedOrder', 'sp_CreateOrderFromStaging', 'sp_CreateOrderLines');

-- Test procedure signatures (check parameters)
EXEC sp_help 'sp_ValidateStagedOrder';
EXEC sp_help 'sp_CreateOrderFromStaging';
EXEC sp_help 'sp_CreateOrderLines';
```

**Expected:** All procedures exist with correct parameters  
**If fails:** Procedures may need to be recreated - check `01_Production/` SQL files

---

### **Step 4: Table Structure Verification** (20 minutes)

```sql
-- Check core tables still exist and have expected columns
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'PS_DOC_HDR'
  AND COLUMN_NAME IN ('DOC_ID', 'DOC_TYP', 'TKT_NO', 'CUST_NO', 'TOT_AMT');

SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'PS_DOC_LIN'
  AND COLUMN_NAME IN ('DOC_ID', 'LIN_SEQ_NO', 'ITEM_NO', 'QTY_SOLD');

SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'IM_INV'
  AND COLUMN_NAME IN ('ITEM_NO', 'LOC_ID', 'QTY_ON_SO', 'QTY_AVAIL');
```

**Expected:** All columns exist with expected data types  
**If fails:** Schema changed - update code and documentation

---

### **Step 5: Order Processing Test** (30 minutes)

#### **5.1 Test Order Staging:**
```powershell
# Stage a test order
python woo_orders.py pull --days 1 --apply
```

**Expected:** Orders staged successfully  
**Check:** `SELECT * FROM USER_ORDER_STAGING WHERE IS_APPLIED = 0`

#### **5.2 Test Order Validation:**
```sql
-- Test validation on staged order
DECLARE @StagingID INT = (SELECT TOP 1 STAGING_ID FROM USER_ORDER_STAGING WHERE IS_APPLIED = 0);
EXEC sp_ValidateStagedOrder @StagingID;
```

**Expected:** Validation passes or returns clear error  
**If fails:** Check validation logic, customer/item existence

#### **5.3 Test Order Creation (DRY RUN):**
```powershell
# Test order processing (use test mode if available)
python cp_order_processor.py process --dry-run
```

**Expected:** Order processing logic works  
**If fails:** Check stored procedures, table structure

#### **5.4 Test Full Order Creation (TEST ORDER ONLY):**
```powershell
# Process a test order (use a test customer/item)
python cp_order_processor.py process <TEST_STAGING_ID>
```

**Expected:** Order created in CounterPoint  
**Check:** Order appears in `PS_DOC_HDR` with correct data

---

### **Step 6: Customer Sync Test** (15 minutes)

```powershell
# Test customer sync
python woo_customers.py pull --apply
```

**Expected:** Customers synced successfully  
**Check:** New customers appear in `AR_CUST`

---

### **Step 7: Product Sync Test** (15 minutes)

```powershell
# Test product sync
python woo_products.py sync --limit 10
```

**Expected:** Products synced to WooCommerce  
**Check:** Products appear/update in WooCommerce

---

### **Step 8: Inventory Sync Test** (15 minutes)

```powershell
# Test inventory sync
python woo_inventory_sync.py sync --limit 10
```

**Expected:** Inventory synced to WooCommerce  
**Check:** Inventory quantities update in WooCommerce

---

### **Step 9: Contract Pricing Test** (15 minutes)

```powershell
# Test contract pricing API
python -c "from woo_contract_pricing import get_contract_price; print(get_contract_price('144319', '01-10100', 1.0, '01'))"
```

**Expected:** Contract price returned  
**If fails:** Check pricing rules table, NCR type view

---

### **Step 10: Health Check** (5 minutes)

```powershell
# Run full health check
python check_order_processing_health.py
```

**Expected:** All systems healthy  
**If fails:** Review error messages, check logs

---

## 🚨 **IF TESTS FAIL**

### **Immediate Actions:**

1. **Stop Automated Processing:**
   ```powershell
   # Disable Task Scheduler tasks
   Disable-ScheduledTask -TaskName "WP_WooCommerce_Order_Processing"
   Disable-ScheduledTask -TaskName "WP_WooCommerce_Product_Sync"
   Disable-ScheduledTask -TaskName "WP_WooCommerce_Inventory_Sync"
   ```

2. **Document the Failure:**
   - What test failed?
   - What error message?
   - What CounterPoint version?
   - What changed in release notes?

3. **Check NCR Release Notes:**
   - Look for schema changes
   - Look for deprecated features
   - Look for breaking changes

4. **Fix or Workaround:**
   - Update code if schema changed
   - Update stored procedures if needed
   - Update views if needed
   - Contact NCR support if needed

5. **Re-test:**
   - Run full test suite again
   - Verify all tests pass
   - Re-enable scheduled tasks

---

## 📊 **TEST RESULTS TEMPLATE**

### **CounterPoint Update Test Results**

**Date:** _______________  
**CounterPoint Version:** _______________ (from: _______________)  
**Tester:** _______________  

| Test | Status | Notes |
|------|--------|-------|
| Basic Connectivity | ⬜ Pass / ⬜ Fail | |
| View Verification | ⬜ Pass / ⬜ Fail | |
| Stored Procedure Verification | ⬜ Pass / ⬜ Fail | |
| Table Structure Verification | ⬜ Pass / ⬜ Fail | |
| Order Processing Test | ⬜ Pass / ⬜ Fail | |
| Customer Sync Test | ⬜ Pass / ⬜ Fail | |
| Product Sync Test | ⬜ Pass / ⬜ Fail | |
| Inventory Sync Test | ⬜ Pass / ⬜ Fail | |
| Contract Pricing Test | ⬜ Pass / ⬜ Fail | |
| Health Check | ⬜ Pass / ⬜ Fail | |

**Issues Found:**
- 

**Actions Taken:**
- 

**System Status:** ⬜ Ready for Production / ⬜ Needs Fixes

---

## 🔄 **AUTOMATED TESTING SCRIPT**

Create a PowerShell script to run all tests:

```powershell
# Test-CounterPointUpdate.ps1
# Runs all tests after CounterPoint update

Write-Host "=== CounterPoint Update Testing ===" -ForegroundColor Cyan

# Test 1: Connectivity
Write-Host "`n1. Testing connectivity..." -ForegroundColor Yellow
python -c "from database import get_connection; conn = get_connection(); print('✅ Connected'); conn.close()"

# Test 2: Health Check
Write-Host "`n2. Running health check..." -ForegroundColor Yellow
python check_order_processing_health.py

# Test 3: Order Processing (dry run)
Write-Host "`n3. Testing order processing..." -ForegroundColor Yellow
python cp_order_processor.py list

# Add more tests...
```

---

## ✅ **SIGN-OFF**

**After all tests pass:**

- [ ] All tests completed
- [ ] All tests passed
- [ ] No schema changes detected
- [ ] System ready for production
- [ ] Scheduled tasks re-enabled
- [ ] Team notified of update completion

**Sign-off:** _______________  
**Date:** _______________

---

**Last Updated:** January 2, 2026  
**Status:** ✅ **READY FOR USE**

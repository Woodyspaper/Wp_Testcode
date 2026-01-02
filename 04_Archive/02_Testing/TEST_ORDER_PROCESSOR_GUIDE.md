# Testing Order Stored Procedures - Quick Guide

**Date:** December 31, 2025  
**Purpose:** Test the order processing stored procedures and Python script

---

## 🧪 **TEST OPTIONS**

### **Option 1: Test in SSMS (SQL Server Management Studio)**

**File:** `02_Testing/TEST_ORDER_STORED_PROCEDURES.sql`

**Steps:**
1. Open SQL Server Management Studio
2. Connect to your database (WOODYS_CP or CPPractice)
3. Open `02_Testing/TEST_ORDER_STORED_PROCEDURES.sql`
4. Review the script (it will find valid test data automatically)
5. Execute the entire script (F5)

**What it tests:**
- ✅ Validation with valid order
- ✅ Validation with invalid order (missing customer)
- ✅ Order creation (creates actual records)
- ✅ Duplicate prevention
- ✅ Verification of created records

**Output:**
- Creates test order in USER_ORDER_STAGING
- Creates actual order in PS_DOC_HDR, PS_DOC_LIN, PS_DOC_HDR_TOT
- Shows verification queries
- Provides cleanup SQL at the end

**Cleanup:**
The script provides SQL statements at the end to clean up test data. You can run them manually after verification.

---

### **Option 2: Test with Python Script**

**File:** `test_order_processor.py`

**Steps:**
1. Open terminal/command prompt
2. Navigate to project directory
3. Run: `python test_order_processor.py`

**What it tests:**
- ✅ Validation function
- ✅ Order creation function
- ✅ Duplicate prevention
- ✅ Database verification
- ✅ Automatic cleanup (optional)

**Requirements:**
- Valid active customer in AR_CUST
- At least 2 active items in IM_ITEM
- Database connection configured

**Output:**
- Creates test order
- Runs all tests
- Shows detailed results
- Offers cleanup option

---

## 📋 **PREREQUISITES**

Before running either test, ensure:

1. **Stored procedures are deployed:**
   - `sp_ValidateStagedOrder`
   - `sp_CreateOrderFromStaging`
   - `sp_CreateOrderLines`

2. **Test data exists:**
   - At least 1 customer in `AR_CUST`
   - At least 2 active items in `IM_ITEM` (STAT = 'A')

3. **Tables exist:**
   - `USER_ORDER_STAGING`
   - `PS_DOC_HDR`
   - `PS_DOC_LIN`
   - `PS_DOC_HDR_TOT`

---

## 🔍 **VERIFICATION CHECKLIST**

After running tests, verify:

### **In USER_ORDER_STAGING:**
```sql
SELECT * FROM dbo.USER_ORDER_STAGING 
WHERE BATCH_ID = 'TEST_ORDER_PROC' OR BATCH_ID = 'TEST_ORDER_PYTHON';
```

**Expected:**
- `IS_APPLIED = 1` (after successful processing)
- `CP_DOC_ID` populated with DOC_ID
- `APPLIED_DT` populated

### **In PS_DOC_HDR:**
```sql
SELECT DOC_ID, TKT_NO, CUST_NO, TKT_DT, ORD_LINS, SAL_LINS
FROM dbo.PS_DOC_HDR
WHERE DOC_ID = <your_test_doc_id>;
```

**Expected:**
- DOC_ID generated
- TKT_NO generated (format: 101-000001)
- CUST_NO matches test customer
- ORD_LINS and SAL_LINS match line item count

### **In PS_DOC_LIN:**
```sql
SELECT DOC_ID, LIN_SEQ_NO, ITEM_NO, QTY_SOLD, PRC, EXT_PRC
FROM dbo.PS_DOC_LIN
WHERE DOC_ID = <your_test_doc_id>
ORDER BY LIN_SEQ_NO;
```

**Expected:**
- Line items created (2 items in test)
- LIN_SEQ_NO sequential (1, 2, ...)
- ITEM_NO matches test items
- QTY_SOLD, PRC, EXT_PRC calculated correctly

### **In PS_DOC_HDR_TOT:**
```sql
SELECT DOC_ID, SUB_TOT, TAX_AMT, TOT, TOT_HDR_DISC, TOT_LIN_DISC, AMT_DUE
FROM dbo.PS_DOC_HDR_TOT
WHERE DOC_ID = <your_test_doc_id>;
```

**Expected:**
- SUB_TOT = 36.75 (21.00 + 15.75)
- TAX_AMT = 2.50
- TOT = 44.25 (subtotal + tax + shipping - discounts)
- AMT_DUE matches TOT

---

## 🧹 **CLEANUP**

### **SQL Cleanup:**
```sql
-- Get test DOC_IDs first
SELECT CP_DOC_ID FROM dbo.USER_ORDER_STAGING 
WHERE BATCH_ID IN ('TEST_ORDER_PROC', 'TEST_ORDER_PYTHON') 
AND CP_DOC_ID IS NOT NULL;

-- Then delete (replace <DOC_ID> with actual IDs)
DELETE FROM dbo.PS_DOC_LIN WHERE DOC_ID = <DOC_ID>;
DELETE FROM dbo.PS_DOC_HDR_TOT WHERE DOC_ID = <DOC_ID>;
DELETE FROM dbo.PS_DOC_HDR WHERE DOC_ID = <DOC_ID>;
DELETE FROM dbo.USER_ORDER_STAGING 
WHERE BATCH_ID IN ('TEST_ORDER_PROC', 'TEST_ORDER_PYTHON');
```

### **Python Cleanup:**
The Python test script offers automatic cleanup. If you need to clean up manually:

```python
from test_order_processor import cleanup_test_data
cleanup_test_data()
```

---

## ⚠️ **TROUBLESHOOTING**

### **Error: "Customer not found"**
- Ensure AR_CUST has at least one customer
- Check that CUST_NO is not NULL in test data

### **Error: "Item not found"**
- Ensure IM_ITEM has at least 2 items with STAT = 'A'
- Verify ITEM_NO values in LINE_ITEMS_JSON match actual items

### **Error: "Staging record not found"**
- Verify the STAGING_ID exists
- Check that IS_APPLIED = 0 (not already processed)

### **Error: "Order already applied"**
- The order was already processed
- Create a new test order or reset IS_APPLIED = 0 (not recommended for production)

### **DOC_ID or TKT_NO generation issues**
- Verify PS_DOC_HDR.DOC_ID is IDENTITY column
- Check TKT_NO generation logic matches CounterPoint format
- May need to adjust stored procedure based on CounterPoint requirements

---

## 📝 **NEXT STEPS AFTER TESTING**

1. ✅ Verify DOC_ID generation works correctly
2. ✅ Verify TKT_NO format matches CounterPoint expectations
3. ✅ Test with real staged orders from WooCommerce
4. ✅ Create scheduled job for automated processing
5. ✅ Monitor for any production issues

---

**Last Updated:** December 31, 2025

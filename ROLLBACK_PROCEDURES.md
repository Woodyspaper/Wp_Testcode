# Rollback Procedures

**Date:** January 2, 2026  
**Purpose:** How to undo order creation if something goes wrong

---

## ⚠️ **WHEN TO USE ROLLBACK**

**Use rollback when:**
- Wrong order created (duplicate, incorrect data)
- Order created in error
- Need to reverse order for testing
- Data corruption detected

**DO NOT use rollback when:**
- Order is correct but needs modification (use CounterPoint UI)
- Order already shipped (use CounterPoint cancellation process)
- Order is in production use (coordinate with operations)

---

## 🔄 **ROLLBACK PROCEDURE**

### **Step 1: Identify the Order**

```sql
-- Find the order in CounterPoint
SELECT 
    h.DOC_ID,
    h.TKT_NO,
    h.CUST_NO,
    h.TKT_DT,
    h.TOT_AMT,
    s.STAGING_ID,
    s.WOO_ORDER_ID
FROM dbo.PS_DOC_HDR h
INNER JOIN dbo.USER_ORDER_STAGING s ON s.CP_DOC_ID = CAST(h.DOC_ID AS VARCHAR(15))
WHERE h.TKT_NO = '101-000002'  -- Replace with your ticket number
  AND h.DOC_TYP = 'O';
```

### **Step 2: Check Inventory Impact**

```sql
-- Check what inventory was updated
SELECT 
    inv.ITEM_NO,
    inv.LOC_ID,
    inv.QTY_ON_SO,
    l.QTY_SOLD AS OrderQty
FROM dbo.PS_DOC_LIN l
INNER JOIN dbo.IM_INV inv ON inv.ITEM_NO = l.ITEM_NO 
    AND inv.LOC_ID = ISNULL(l.STK_LOC_ID, '01')
WHERE l.DOC_ID = 103398648479  -- Replace with your DOC_ID
ORDER BY l.LIN_SEQ_NO;
```

### **Step 3: Reverse Inventory Updates**

```sql
-- Reverse QTY_ON_SO updates
-- WARNING: Only do this if order was just created and not shipped
UPDATE inv
SET inv.QTY_ON_SO = inv.QTY_ON_SO - l.QTY_SOLD
FROM dbo.IM_INV inv
INNER JOIN dbo.PS_DOC_LIN l ON l.ITEM_NO = inv.ITEM_NO 
    AND inv.LOC_ID = ISNULL(l.STK_LOC_ID, '01')
WHERE l.DOC_ID = 103398648479;  -- Replace with your DOC_ID
```

### **Step 4: Delete Order from CounterPoint**

**⚠️ WARNING: Only delete if order was just created and not processed further!**

```sql
-- Delete line items first (foreign key constraint)
DELETE FROM dbo.PS_DOC_LIN
WHERE DOC_ID = 103398648479;  -- Replace with your DOC_ID

-- Delete totals
DELETE FROM dbo.PS_DOC_HDR_TOT
WHERE DOC_ID = 103398648479;  -- Replace with your DOC_ID

-- Delete header
DELETE FROM dbo.PS_DOC_HDR
WHERE DOC_ID = 103398648479;  -- Replace with your DOC_ID
```

### **Step 5: Reset Staging Record**

```sql
-- Reset staging record to allow reprocessing
UPDATE dbo.USER_ORDER_STAGING
SET 
    IS_APPLIED = 0,
    APPLIED_DT = NULL,
    CP_DOC_ID = NULL,
    VALIDATION_ERROR = NULL
WHERE STAGING_ID = 123;  -- Replace with your STAGING_ID
```

### **Step 6: Revert WooCommerce Status (Optional)**

If order status was synced to WooCommerce, you may want to revert it:

```python
# In Python
from woo_client import WooClient

client = WooClient()
client.update_order_status(woo_order_id=12345, status='pending')
```

---

## 🧪 **TESTING ROLLBACK**

**Before rolling back in production:**

1. **Test on a test order first:**
   ```sql
   -- Create test order
   -- Process it
   -- Roll it back
   -- Verify everything is restored
   ```

2. **Verify inventory is restored:**
   ```sql
   -- Check QTY_ON_SO before rollback
   -- Rollback
   -- Check QTY_ON_SO after rollback (should match)
   ```

3. **Verify staging record is reset:**
   ```sql
   -- Check IS_APPLIED = 0
   -- Check CP_DOC_ID = NULL
   ```

---

## ⚠️ **IMPORTANT WARNINGS**

1. **Do NOT rollback if:**
   - Order has been shipped
   - Order has been invoiced
   - Order is in CounterPoint's fulfillment process
   - Other systems depend on the order

2. **Always:**
   - Backup before rollback (if possible)
   - Test on non-production first
   - Document what you're rolling back
   - Coordinate with operations team

3. **Alternative to Rollback:**
   - Use CounterPoint's cancellation process
   - Use CounterPoint's order modification
   - Create credit memo instead of deleting

---

## 📋 **ROLLBACK CHECKLIST**

- [ ] Identify order (DOC_ID, TKT_NO, STAGING_ID)
- [ ] Check inventory impact (QTY_ON_SO)
- [ ] Verify order hasn't been processed further
- [ ] Backup current state (if possible)
- [ ] Reverse inventory updates
- [ ] Delete order from CounterPoint (if safe)
- [ ] Reset staging record
- [ ] Revert WooCommerce status (if needed)
- [ ] Verify rollback successful
- [ ] Document rollback in logs

---

**Last Updated:** January 2, 2026  
**Status:** ✅ **READY FOR USE**

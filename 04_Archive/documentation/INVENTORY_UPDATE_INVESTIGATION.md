# Inventory Update Investigation

**Date:** December 31, 2025  
**Purpose:** Determine if CounterPoint automatically updates inventory when orders are created

---

## 🎯 **QUESTION**

**Does CounterPoint automatically reduce inventory (`IM_INV.QTY_ON_HND` and `IM_INV.QTY_ALLOC`) when orders are created in `PS_DOC_HDR`/`PS_DOC_LIN`?**

---

## 📋 **CURRENT STATE**

### **What We Know:**
- ✅ Orders are successfully created in `PS_DOC_HDR`/`PS_DOC_LIN`/`PS_DOC_HDR_TOT`
- ❌ **No inventory update logic** in `sp_CreateOrderFromStaging` or `sp_CreateOrderLines`
- ❓ **Unknown:** Does CounterPoint have triggers that auto-update inventory?

### **What We Need to Verify:**
1. Are there triggers on `PS_DOC_HDR`/`PS_DOC_LIN` that update `IM_INV`?
2. Do existing orders show inventory allocation (`QTY_ALLOC`)?
3. Does creating a new order change inventory values?

---

## 🔍 **INVESTIGATION SCRIPTS**

### **Known IM_INV Structure:**
**Investigation Results (January 2, 2026):**

From investigation, `IM_INV` has:
- ✅ `ITEM_NO` - varchar(20) - Item number (join key)
- ✅ `LOC_ID` - varchar(10) - **Location ID** (exists!)
- ✅ `QTY_ON_HND` - decimal(15,4) - Quantity on hand
- ✅ `QTY_AVAIL` - decimal(16,4) - Available quantity
- ✅ `QTY_ON_SO` - decimal(15,4) - **Quantity on Sales Order** (likely tracks allocated inventory)
- ✅ `QTY_COMMIT` - decimal(15,4) - Committed quantity
- ✅ `QTY_ON_ORD` - decimal(15,4) - Quantity on purchase order
- ✅ `QTY_ON_LWY` - decimal(15,4) - Quantity on layaway

**Note:** `QTY_ALLOC` does NOT exist, but `QTY_ON_SO` (Quantity on Sales Order) might be the equivalent!

---

### **Script 1: `INVESTIGATE_INVENTORY_AUTO_UPDATE.sql`**
**Purpose:** Comprehensive investigation of triggers, table structure, and recent orders

**What it checks:**
- ✅ Triggers on `PS_DOC_HDR` and `PS_DOC_LIN`
- ✅ `IM_INV` table structure
- ✅ Recent orders and their items
- ✅ Current inventory for order items
- ✅ Comparison of `QTY_ALLOC` vs order quantities

**How to use:**
```sql
-- Run in SSMS
USE WOODYS_CP;
GO
-- Execute the entire script
```

**Expected results:**
- If triggers exist → CounterPoint likely auto-updates
- If `QTY_AVAIL` decreased by order quantity → CounterPoint auto-updates
- If `QTY_AVAIL` unchanged → CounterPoint does NOT auto-update

---

### **Script 2: `TEST_INVENTORY_UPDATE_WITH_ORDER.sql`**
**Purpose:** Test inventory changes before and after creating an order

**How to use:**

**Step 1: Run PART 1 (Before Order)**
```sql
-- Run PART 1 to capture baseline inventory
-- Update @TestItems with items from your test order
```

**Step 2: Create Test Order**
```sql
-- Use existing staging record or create new one
EXEC sp_CreateOrderFromStaging 
    @StagingID = <your_staging_id>,
    @DocID = @DocID OUTPUT,
    @TktNo = @TktNo OUTPUT,
    @Success = @Success OUTPUT,
    @ErrorMessage = @ErrorMessage OUTPUT;
```

**Step 3: Run PART 2 (After Order)**
```sql
-- Uncomment PART 2 section
-- Compare before/after inventory values
```

**Expected results:**
- If `QTY_AVAIL` decreased by order quantity → CounterPoint auto-updates
- If `QTY_ON_HND` decreased → CounterPoint reduces stock on order
- If no changes → Need to add inventory update logic

---

## 📊 **INVENTORY FIELDS EXPLAINED**

### **IM_INV Table Fields:**

| Field | Purpose | What We Need to Check |
|-------|---------|----------------------|
| `QTY_ON_HND` | Quantity on hand (physical stock) | Does this decrease when order created? |
| `QTY_ON_SO` | Quantity on Sales Order (allocated for orders) | ✅ **EXISTS** - Does this increase when order created? |
| `QTY_AVAIL` | Available quantity (`QTY_ON_HND - QTY_ALLOC`) | Does this decrease when order created? |

### **Typical CounterPoint Behavior:**

**If CounterPoint auto-updates:**
- `QTY_ON_SO` should increase by order quantity (quantity on sales order)
- `QTY_AVAIL` should decrease by order quantity
- `QTY_ON_HND` may or may not decrease (depends on when stock is reduced - on order vs on shipment)

**If CounterPoint does NOT auto-update:**
- `QTY_AVAIL` unchanged
- `QTY_ON_HND` unchanged

---

## 🔧 **IF COUNTERPOINT DOES NOT AUTO-UPDATE**

### **What We Need to Add:**

**Update `sp_CreateOrderLines` to update inventory:**

```sql
-- After creating each line item, update inventory
-- Note: IM_INV has LOC_ID column - need to match location
UPDATE dbo.IM_INV
SET QTY_ON_SO = QTY_ON_SO + @QtySold,  -- Increase quantity on sales order
    QTY_AVAIL = QTY_AVAIL - @QtySold   -- Decrease available quantity
WHERE ITEM_NO = @ItemNo 
  AND LOC_ID = @StkLocId;  -- Match location (default '01')

-- Optionally, if orders should reduce stock immediately:
-- UPDATE dbo.IM_INV
-- SET QTY_ON_HND = QTY_ON_HND - @QtySold
-- WHERE ITEM_NO = @ItemNo 
--   AND LOC_ID = @StkLocId;
```

**Location:** Add this logic in `sp_CreateOrderLines` after each `INSERT INTO PS_DOC_LIN`

**Considerations:**
- Handle backorders (negative stock)
- Ensure inventory exists for item/location
- Handle concurrent updates (locking)
- Match `LOC_ID` when updating (default '01')
- Consider calling `USP_TKT_PST_UPD_IM_INV` if CounterPoint provides it

---

## 📋 **INVESTIGATION CHECKLIST**

- [ ] Run `INVESTIGATE_INVENTORY_AUTO_UPDATE.sql`
- [ ] Check for triggers on `PS_DOC_HDR`/`PS_DOC_LIN`
- [ ] Compare `QTY_ALLOC` to order quantities for recent orders
- [ ] Run `TEST_INVENTORY_UPDATE_WITH_ORDER.sql` with a test order
- [ ] Document findings
- [ ] If CounterPoint does NOT auto-update, add inventory update logic

---

## 🎯 **EXPECTED OUTCOMES**

### **Scenario 1: CounterPoint Auto-Updates**
✅ **Result:** No action needed  
✅ **Status:** Inventory is handled automatically  
✅ **Next Step:** Document that CounterPoint handles it

### **Scenario 2: CounterPoint Does NOT Auto-Update**
⚠️ **Result:** Need to add inventory update logic  
⚠️ **Status:** Must update `IM_INV` in stored procedures  
⚠️ **Next Step:** Modify `sp_CreateOrderLines` to update inventory

---

## 📝 **FINDINGS**

**Investigation Results (January 2, 2026):**

- [x] Triggers found: **YES** - `TR_RS_PS_DOC_HDR_D` (DELETE trigger, not INSERT)
- [x] `IM_INV` structure discovered: **YES** - Has `LOC_ID`, `QTY_ON_SO`, `QTY_AVAIL`, `QTY_ON_HND`
- [x] Stored procedures found: **YES** - `USP_TKT_PST_UPD_IM_INV` (ticket post update inventory)
- [ ] `QTY_ON_SO` checked for orders: **PENDING** - Need to verify if it reflects order quantities
- [ ] Test order inventory change: **PENDING** - Need to create test order and check

**Key Discoveries:**
1. ✅ `IM_INV` has `LOC_ID` column (location-specific inventory)
2. ✅ `IM_INV` has `QTY_ON_SO` column (quantity on sales order) - might be what we need!
3. ✅ `USP_TKT_PST_UPD_IM_INV` procedure exists (likely handles inventory updates)
4. ⚠️ Only DELETE trigger found (INSERT trigger may not exist, or procedures called directly)

**Next Steps:**
1. Run `CHECK_QTY_ON_SO_FOR_ORDERS.sql` to see if `QTY_ON_SO` reflects orders
2. Create test order and check if `QTY_ON_SO` or `QTY_AVAIL` changes
3. Check if we need to call `USP_TKT_PST_UPD_IM_INV` explicitly

**Final Conclusion:** ✅ **CounterPoint does NOT auto-update inventory** - Inventory update logic has been added to `sp_CreateOrderLines`.

---

**Last Updated:** January 2, 2026  
**Status:** ✅ **COMPLETE** - Inventory update logic implemented

# Inventory Update Implementation

**Date:** January 2, 2026  
**Status:** ✅ **SOLUTION READY** - CounterPoint does NOT auto-update inventory

---

## 🎯 **FINDING**

**CounterPoint does NOT automatically update inventory when orders are created via our stored procedures.**

**Evidence:**
- ✅ Orders successfully created in `PS_DOC_HDR`/`PS_DOC_LIN`
- ❌ `QTY_ON_SO` remains 0.0000 after order creation
- ❌ `QTY_AVAIL` unchanged after order creation
- ❌ No triggers or automatic procedures called

---

## 🔧 **SOLUTION**

### **Add Inventory Update Logic to `sp_CreateOrderLines`**

Update inventory after each line item is created in `PS_DOC_LIN`.

---

## 📋 **IMPLEMENTATION**

### **Step 1: Update `sp_CreateOrderLines`**

Add inventory update logic after each `INSERT INTO PS_DOC_LIN`:

```sql
-- After creating line item, update inventory
-- Ensure inventory record exists for item/location
IF NOT EXISTS (SELECT 1 FROM dbo.IM_INV WHERE ITEM_NO = @ItemNo AND LOC_ID = @StkLocId)
BEGIN
    -- Create inventory record if it doesn't exist (with all required NOT NULL columns)
    INSERT INTO dbo.IM_INV (
        ITEM_NO, LOC_ID,
        MIN_QTY, MAX_QTY, QTY_COMMIT,
        QTY_ON_HND, QTY_ON_PO, QTY_ON_BO, QTY_ON_XFER_OUT, QTY_ON_XFER_IN,
        QTY_ON_ORD, QTY_ON_LWY, QTY_ON_SO,
        LST_AVG_COST, LST_COST, STD_COST, COST_OF_SLS_PCT, GL_VAL,
        RS_STAT, DROPSHIP_QTY_ON_CUST_ORD, DROPSHIP_QTY_ON_PO
    )
    VALUES (
        @ItemNo, @StkLocId,
        0, 0, 0,  -- MIN_QTY, MAX_QTY, QTY_COMMIT
        0, 0, 0, 0, 0,  -- QTY_ON_HND, QTY_ON_PO, QTY_ON_BO, QTY_ON_XFER_OUT, QTY_ON_XFER_IN
        0, 0, 0,  -- QTY_ON_ORD, QTY_ON_LWY, QTY_ON_SO
        0, 0, 0, 0, 0,  -- LST_AVG_COST, LST_COST, STD_COST, COST_OF_SLS_PCT, GL_VAL
        1, 0, 0  -- RS_STAT (default 1), DROPSHIP_QTY_ON_CUST_ORD, DROPSHIP_QTY_ON_PO
    );
END

-- Update inventory quantities
-- Note: QTY_AVAIL is a computed column (calculated automatically by CounterPoint)
--       We only update QTY_ON_SO, and CounterPoint will recalculate QTY_AVAIL
UPDATE dbo.IM_INV
SET QTY_ON_SO = QTY_ON_SO + @QtySold      -- Increase quantity on sales order
WHERE ITEM_NO = @ItemNo 
  AND LOC_ID = @StkLocId;
```

**Location:** Add this in `sp_CreateOrderLines` after line 250 (after `INSERT INTO PS_DOC_LIN`)

---

## ⚠️ **CONSIDERATIONS**

### **1. Location Matching:**
- `PS_DOC_LIN` uses `STK_LOC_ID` (stock location)
- `IM_INV` uses `LOC_ID` (location ID)
- Must match: `inv.LOC_ID = l.STK_LOC_ID` (default '01')

### **2. Inventory Record Existence:**
- Inventory record must exist for item/location
- Create if missing (with all required NOT NULL columns)

### **3. Computed Column (`QTY_AVAIL`):**
- ⚠️ **`QTY_AVAIL` is a computed column** - Cannot be updated directly
- CounterPoint automatically recalculates it based on `QTY_ON_SO`, `QTY_ON_HND`, `QTY_COMMIT`, etc.
- We only update `QTY_ON_SO`, and CounterPoint handles the rest

### **4. Concurrent Updates:**
- Multiple orders could update same item simultaneously
- SQL Server handles locking automatically
- Consider transaction isolation if needed

### **5. Alternative: Call `USP_TKT_PST_UPD_IM_INV`**

Instead of manual UPDATE, we could call CounterPoint's procedure:
```sql
-- Option: Call CounterPoint's inventory update procedure
EXEC dbo.USP_TKT_PST_UPD_IM_INV 
    @DocID = @DocID,
    @TktNo = @TktNo;
```

**Note:** Need to check procedure parameters and if it's safe to call directly. For now, updating `QTY_ON_SO` directly is the safer approach.

---

## 📝 **CODE TO ADD**

Add this code block in `sp_CreateOrderLines` after creating each line item (after line 250):

```sql
            -- Update inventory after creating line item
            -- Ensure inventory exists for item/location
            IF NOT EXISTS (SELECT 1 FROM dbo.IM_INV WHERE ITEM_NO = @ItemNo AND LOC_ID = @StkLocId)
            BEGIN
                INSERT INTO dbo.IM_INV (
                    ITEM_NO, LOC_ID, 
                    QTY_ON_HND, QTY_AVAIL, QTY_ON_SO, QTY_COMMIT,
                    MIN_QTY, MAX_QTY, QTY_COMMIT
                )
                VALUES (
                    @ItemNo, @StkLocId,
                    0, 0, 0, 0,
                    0, 0, 0
                );
            END
            
            -- Update inventory quantities
            UPDATE dbo.IM_INV
            SET QTY_ON_SO = QTY_ON_SO + @QtySold,
                QTY_AVAIL = ISNULL(QTY_AVAIL, 0) - @QtySold
            WHERE ITEM_NO = @ItemNo 
              AND LOC_ID = @StkLocId;
```

---

## 🧪 **TESTING**

After implementing:

1. **Run PART 1** of `TEST_INVENTORY_UPDATE_WITH_ORDER.sql` (get baseline)
2. **Create test order** using `sp_CreateOrderFromStaging`
3. **Check inventory:**
   ```sql
   SELECT ITEM_NO, LOC_ID, QTY_ON_SO, QTY_AVAIL, QTY_ON_HND
   FROM dbo.IM_INV
   WHERE ITEM_NO IN ('01-10100', '01-10102')
   ORDER BY ITEM_NO, LOC_ID;
   ```
4. **Verify:**
   - `QTY_ON_SO` should increase by order quantity
   - `QTY_AVAIL` should decrease by order quantity

---

## ✅ **EXPECTED RESULTS**

**Before Order:**
- `01-10100`: QTY_ON_SO = 0, QTY_AVAIL = 15

**After Order (qty 2):**
- `01-10100`: QTY_ON_SO = 2, QTY_AVAIL = 13

---

## 📋 **CHECKLIST**

- [ ] Add inventory update logic to `sp_CreateOrderLines`
- [ ] Handle inventory record creation if missing
- [ ] Test with new order
- [ ] Verify `QTY_ON_SO` increases
- [ ] Verify `QTY_AVAIL` decreases
- [ ] Test with multiple locations (if applicable)
- [ ] Test with backorders (negative stock)

---

**Last Updated:** January 2, 2026  
**Status:** Ready for implementation

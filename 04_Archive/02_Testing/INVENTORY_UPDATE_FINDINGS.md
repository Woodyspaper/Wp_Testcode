# Inventory Update Investigation - Findings

**Date:** January 2, 2026  
**Status:** ✅ **INVESTIGATION COMPLETE**

---

## 🔍 **KEY FINDINGS**

### **1. Trigger Found:**
- **Trigger Name:** `TR_RS_PS_DOC_HDR_D`
- **Table:** `PS_DOC_HDR`
- **Type:** DELETE trigger (the `_D` suffix indicates DELETE)
- **Created:** 2024-10-30
- **Status:** Enabled (IsDisabled = 0)

**Analysis:** This is a DELETE trigger, not an INSERT trigger. It likely handles cleanup when orders are deleted, not inventory updates when orders are created.

---

### **2. IM_INV Table Structure Discovered:**

**Key Columns:**
- ✅ `ITEM_NO` - varchar(20) - Item number (join key)
- ✅ `LOC_ID` - varchar(10) - **Location ID EXISTS!** (we were wrong - it does exist)
- ✅ `QTY_ON_HND` - decimal(15,4) - Quantity on hand
- ✅ `QTY_AVAIL` - decimal(16,4) - Available quantity (nullable)
- ✅ `QTY_ON_SO` - decimal(15,4) - **Quantity on Sales Order** (this might be what we need!)
- ✅ `QTY_COMMIT` - decimal(15,4) - Committed quantity
- ✅ `QTY_ON_ORD` - decimal(15,4) - Quantity on purchase order
- ✅ `QTY_ON_LWY` - decimal(15,4) - Quantity on layaway

**Important:** `QTY_ALLOC` does NOT exist, but `QTY_ON_SO` (Quantity on Sales Order) might be the equivalent!

---

### **3. Recent Orders Found:**

| DOC_ID | TKT_NO | Date | Items |
|--------|--------|------|-------|
| 103398648478 | 101-000001 | 2025-12-31 | 01-10100 (qty 2), 01-10102 (qty 1) |
| 101163492218 | O101-000365 | 2025-12-29 | 01-11595 (qty 2) |

---

### **4. Inventory Status for Order Items:**

| ITEM_NO | Qty Ordered | QTY_ON_HND | QTY_AVAIL | Order Date | TKT_NO |
|---------|-------------|------------|-----------|------------|--------|
| 01-10100 | 2.0000 | 495.0000 | 15.0000 | 2025-12-31 | 101-000001 |
| 01-10102 | 1.0000 | 0.0000 | 0.0000 | 2025-12-31 | 101-000001 |
| 01-11595 | 2.0000 | -7000.0000 | -8000.0000 | 2025-12-29 | O101-000365 |

**Key Observations:**
- Item `01-10100`: Has 495 on hand, but only 15 available (480 difference = allocated/reserved)
- Item `01-10102`: Zero stock
- Item `01-11595`: Negative quantities (backorder situation)

**Critical Question:** Does `QTY_ON_SO` reflect the order quantities?

---

### **5. Stored Procedures Found:**

Multiple inventory update procedures exist:
- `USP_TKT_PST_UPD_IM_INV` - **Ticket Post Update Inventory** (most relevant!)
- `USP_PO_RECVR_INV_UPD` - Purchase order receive inventory update
- `USP_IM_XFER_IN_INV_UPD` - Transfer in inventory update
- And many others...

**Key Finding:** `USP_TKT_PST_UPD_IM_INV` suggests CounterPoint has a procedure to update inventory when tickets/orders are posted!

---

## 🎯 **CONCLUSION**

### **CounterPoint DOES NOT Auto-Update Inventory** ❌

**Evidence from Test Results:**
1. ❌ `QTY_ON_SO` = 0.0000 for all orders (should reflect order quantities if auto-updated)
2. ❌ Order `101-000001` (Dec 31): Items `01-10100` (qty 2), `01-10102` (qty 1) - `QTY_ON_SO` = 0
3. ❌ Order `O101-000365` (Dec 29): Item `01-11595` (qty 2) - `QTY_ON_SO` = 0
4. ⚠️ `QTY_COMMIT` shows 480.0000 for `01-10100` (likely from other sources, not our orders)

**Key Finding:**
- Orders are successfully created in `PS_DOC_HDR`/`PS_DOC_LIN`
- **BUT:** `IM_INV.QTY_ON_SO` remains 0.0000
- **Conclusion:** CounterPoint does NOT automatically update inventory when orders are created via our stored procedures

**Why `USP_TKT_PST_UPD_IM_INV` exists but isn't called:**
- This procedure likely needs to be called explicitly after order creation
- Or it's only called when orders are "posted" (not just created)
- Our stored procedures create orders but don't call inventory update procedures

---

## 📋 **NEXT STEPS**

1. **Check `QTY_ON_SO` for test order:**
   ```sql
   SELECT ITEM_NO, LOC_ID, QTY_ON_SO, QTY_AVAIL, QTY_ON_HND
   FROM dbo.IM_INV
   WHERE ITEM_NO IN ('01-10100', '01-10102')
   ORDER BY ITEM_NO, LOC_ID;
   ```

2. **Check if `USP_TKT_PST_UPD_IM_INV` is called:**
   - Check trigger definitions
   - Check if it's called in CounterPoint's order creation process

3. **Test with new order:**
   - Create a test order
   - Check if `QTY_ON_SO` or `QTY_AVAIL` changes

---

## ✅ **RECOMMENDATION**

**CONFIRMED:** CounterPoint does NOT auto-update inventory when orders are created via our stored procedures.

**Action Required:** Add inventory update logic to `sp_CreateOrderLines` to:
1. Update `QTY_ON_SO` (increase by order quantity)
2. Update `QTY_AVAIL` (decrease by order quantity)
3. Optionally call `USP_TKT_PST_UPD_IM_INV` if it's the proper way to update inventory

**Implementation:** See `INVENTORY_UPDATE_IMPLEMENTATION.md` for the solution.

---

**Last Updated:** January 2, 2026

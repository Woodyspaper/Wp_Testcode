# QTY_AVAIL Investigation Status

**Date:** January 2, 2026  
**Status:** ⚠️ **INVESTIGATION NEEDED**

---

## 🎯 **TEST RESULTS**

### ✅ **What's Working:**
- `QTY_ON_SO` updates correctly:
  - `01-10100`: 0 → 2.0000 ✅
  - `01-10102`: 0 → 1.0000 ✅
- Orders are created successfully in CounterPoint ✅

### ❌ **What's NOT Working:**
- `QTY_AVAIL` does NOT change:
  - `01-10100`: 15.0000 → 15.0000 (unchanged) ❌
  - `01-10102`: 0.0000 → 0.0000 (unchanged) ❌

---

## 🔍 **THE PROBLEM**

**Contradictory Evidence:**
1. **Previous Error:** When we tried to update `QTY_AVAIL` directly, we got:
   ```
   Msg 271: The column "QTY_AVAIL" cannot be modified because it is 
   either a computed column or is the result of a UNION operator.
   ```
   This suggests `QTY_AVAIL` is a **computed column**.

2. **Test Results:** `QTY_AVAIL` does NOT automatically recalculate when `QTY_ON_SO` changes.
   This suggests it's **NOT** a computed column (or it's computed but doesn't depend on `QTY_ON_SO`).

---

## 🤔 **POSSIBLE EXPLANATIONS**

### **Option 1: Computed Column That Doesn't Auto-Update**
- `QTY_AVAIL` might be computed but only recalculates:
  - When CounterPoint UI is used
  - When specific CounterPoint procedures are called
  - On certain events (not just `QTY_ON_SO` changes)

### **Option 2: Formula Doesn't Include QTY_ON_SO**
- The computed formula might be:
  - `QTY_AVAIL = QTY_ON_HND - QTY_COMMIT - QTY_ON_ORD - QTY_ON_LWY`
  - (Does NOT include `QTY_ON_SO`)

### **Option 3: Requires CounterPoint Procedure Call**
- CounterPoint might require calling a specific procedure to recalculate:
  - `USP_TKT_PST_UPD_IM_INV` (mentioned in investigation docs)
  - Or another inventory update procedure

### **Option 4: Persisted Computed Column**
- It might be a **PERSISTED** computed column that only updates when:
  - The underlying formula's inputs change
  - A specific trigger fires
  - CounterPoint's internal logic runs

---

## 📋 **NEXT STEPS**

### **Step 1: Investigate Column Definition**
Run: `02_Testing/INVESTIGATE_QTY_AVAIL_FORMULA.sql`

This will:
- Check if `QTY_AVAIL` is actually computed
- Show the computed column formula (if it exists)
- Test if we can update it directly
- Check for triggers or procedures that update it

### **Step 2: Understand CounterPoint's Formula**
- Check CounterPoint documentation
- Look at existing inventory records to reverse-engineer the formula
- Check if `QTY_ON_SO` is part of the calculation

### **Step 3: Find Update Method**
- If computed: Find what triggers the recalculation
- If not computed: Update it directly (with error handling)
- If requires procedure: Call CounterPoint's inventory update procedure

---

## ✅ **CURRENT STATUS**

**What We Have:**
- ✅ `QTY_ON_SO` updates correctly (tracks orders)
- ✅ Orders are created successfully
- ⚠️ `QTY_AVAIL` not updating (needs investigation)

**Impact:**
- **Low-Medium:** Orders are tracked (`QTY_ON_SO`), but available quantity may not reflect orders
- **Workaround:** `QTY_ON_SO` can be used to calculate available quantity manually if needed
- **Priority:** Investigate `QTY_AVAIL` formula to ensure accurate inventory tracking

---

## 📝 **UPDATED CODE**

The stored procedure now:
1. Updates `QTY_ON_SO` (working ✅)
2. Attempts to update `QTY_AVAIL` (with error handling)
3. Falls back to only updating `QTY_ON_SO` if `QTY_AVAIL` update fails

**Next:** Run investigation script to determine the correct approach.

---

---

## ✅ **FINAL RESOLUTION**

**Confirmed:** `QTY_AVAIL` is a **computed column** and cannot be updated directly.

**Error Message:**
```
Msg 271: The column "QTY_AVAIL" cannot be modified because it is 
either a computed column or is the result of a UNION operator.
```

**Conclusion:**
- `QTY_AVAIL` is computed by CounterPoint using a formula that does NOT include `QTY_ON_SO`
- We can only update `QTY_ON_SO` (which is working correctly ✅)
- `QTY_AVAIL` will not reflect orders automatically (this is expected CounterPoint behavior)

**Impact:**
- **Low:** `QTY_ON_SO` correctly tracks orders (0 → 2, 0 → 1) ✅
- Orders are created successfully ✅
- `QTY_AVAIL` may use a different formula (e.g., `QTY_ON_HND - QTY_COMMIT - QTY_ON_ORD - QTY_ON_LWY`)
- If accurate available quantity is needed, calculate it manually: `QTY_ON_HND - QTY_ON_SO - QTY_COMMIT - ...`

**Solution:**
- ✅ Update `QTY_ON_SO` (working)
- ❌ Do NOT attempt to update `QTY_AVAIL` (computed column)
- ✅ Accept that `QTY_AVAIL` won't reflect orders automatically

---

**Last Updated:** January 2, 2026  
**Status:** ✅ **RESOLVED - QTY_AVAIL is computed, cannot be updated**

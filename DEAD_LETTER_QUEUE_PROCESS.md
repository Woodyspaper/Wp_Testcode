# Dead Letter Queue Process

**Date:** January 2, 2026  
**Purpose:** Named process for handling failed orders that need manual review

---

## 🎯 **WHAT IS THE DEAD LETTER QUEUE?**

**Failed orders** that:
- Have validation errors (`VALIDATION_ERROR IS NOT NULL`)
- Have not been applied (`IS_APPLIED = 0`)
- Need manual review and intervention

**These orders are safely isolated** - they won't be processed automatically until fixed.

---

## 📋 **DAILY DEAD LETTER QUEUE REVIEW**

### **Step 1: Find Failed Orders**

Run: `01_Production/FIND_FAILED_ORDERS.sql` (or `04_Archive/02_Testing/FIND_FAILED_ORDERS.sql`)

Or use SQL:
```sql
SELECT 
    STAGING_ID,
    WOO_ORDER_ID,
    WOO_ORDER_NO,
    CUST_NO,
    VALIDATION_ERROR,
    CREATED_DT,
    DATEDIFF(HOUR, CREATED_DT, GETDATE()) AS HoursOld
FROM dbo.USER_ORDER_STAGING
WHERE IS_APPLIED = 0
  AND VALIDATION_ERROR IS NOT NULL
ORDER BY CREATED_DT ASC;
```

### **Step 2: Prioritize by Age**

**Priority Levels:**
- **CRITICAL** - Failed > 24 hours ago (immediate attention)
- **WARNING** - Failed > 6 hours ago (review today)
- **INFO** - Failed < 6 hours ago (review when time permits)

### **Step 3: Review Each Failed Order**

For each failed order:

1. **Get Order Details:**
   ```powershell
   python cp_order_processor.py show <STAGING_ID>
   ```

2. **Review Error Message:**
   - Read `VALIDATION_ERROR` field
   - Understand what's wrong

3. **Common Errors & Fixes:**

   | Error | Cause | Fix |
   |-------|-------|-----|
   | "Customer not found" | CUST_NO doesn't exist in AR_CUST | Create customer or fix CUST_NO |
   | "Item not found" | SKU doesn't exist in IM_ITEM | Verify SKU or create item |
   | "Line items missing" | LINE_ITEMS_JSON is NULL or invalid | Fix JSON format |
   | "Invalid totals" | SUBTOT + TAX + SHIP ≠ TOT_AMT | Recalculate totals |
   | "Order already processed" | IS_APPLIED = 1 | Order already handled, ignore |

### **Step 4: Fix the Issue**

**Option A: Fix in Staging Table**
```sql
-- Fix the data issue
UPDATE dbo.USER_ORDER_STAGING
SET 
    CUST_NO = 'CORRECT_CUST_NO',  -- Example: Fix customer
    VALIDATION_ERROR = NULL        -- Clear error
WHERE STAGING_ID = <ID>;
```

**Option B: Fix in Source (WooCommerce)**
- If data is wrong in WooCommerce, fix it there
- Re-pull the order to staging
- Or manually fix staging record

### **Step 5: Retry Processing**

After fixing:
```powershell
python cp_order_processor.py process <STAGING_ID>
```

### **Step 6: If Cannot Fix**

**Option A: Cancel Order**
- If order is invalid and cannot be fixed
- Cancel in WooCommerce
- Mark staging as skipped:
  ```sql
  UPDATE dbo.USER_ORDER_STAGING
  SET IS_APPLIED = 1,
      VALIDATION_ERROR = 'MANUALLY_SKIPPED: Order cancelled'
  WHERE STAGING_ID = <ID>;
  ```

**Option B: Escalate**
- If issue is complex or unclear
- Document in staging record
- Escalate to technical team

---

## 📊 **DEAD LETTER QUEUE METRICS**

### **Daily Metrics to Track:**

```sql
-- Count by priority
SELECT 
    CASE 
        WHEN DATEDIFF(HOUR, CREATED_DT, GETDATE()) > 24 THEN 'CRITICAL'
        WHEN DATEDIFF(HOUR, CREATED_DT, GETDATE()) > 6 THEN 'WARNING'
        ELSE 'INFO'
    END AS Priority,
    COUNT(*) AS Count
FROM dbo.USER_ORDER_STAGING
WHERE IS_APPLIED = 0
  AND VALIDATION_ERROR IS NOT NULL
GROUP BY 
    CASE 
        WHEN DATEDIFF(HOUR, CREATED_DT, GETDATE()) > 24 THEN 'CRITICAL'
        WHEN DATEDIFF(HOUR, CREATED_DT, GETDATE()) > 6 THEN 'WARNING'
        ELSE 'INFO'
    END;
```

### **Weekly Review:**

- Total failed orders this week
- Most common error types
- Average time to resolution
- Orders that couldn't be fixed

---

## ✅ **DEAD LETTER QUEUE CHECKLIST**

**Daily (Morning):**
- [ ] Run `FIND_FAILED_ORDERS.sql`
- [ ] Review CRITICAL orders (> 24 hours)
- [ ] Fix or escalate CRITICAL orders

**Daily (Afternoon):**
- [ ] Review WARNING orders (> 6 hours)
- [ ] Fix or escalate WARNING orders

**Weekly:**
- [ ] Review all failed orders
- [ ] Analyze error patterns
- [ ] Document recurring issues
- [ ] Update process if needed

---

## 🎯 **SUCCESS CRITERIA**

**Healthy System:**
- No orders in dead letter queue > 24 hours
- Failed orders resolved within 24 hours
- Error patterns identified and addressed

**Unhealthy System:**
- Multiple orders > 24 hours old
- Same errors recurring
- No resolution process

---

**Last Updated:** January 2, 2026  
**Status:** ✅ **PROCESS DEFINED**

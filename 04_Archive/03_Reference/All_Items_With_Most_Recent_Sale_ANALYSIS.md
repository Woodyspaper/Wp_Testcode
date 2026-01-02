# Analysis: All_Items_With_Most_Recent_Sale_And_INV.sql

**Date:** 2025-12-23  
**Source:** Legacy script from previous team  
**Purpose:** Analyze what this script does and if it's useful

---

## 🔍 **What This Script Does**

### **Purpose:**
Shows all items with their **most recent sale date** and **primary vendor information**.

### **Key Components:**

1. **Main Query:**
   ```sql
   SELECT
       IM_ITEM.ITEM_NO AS 'ITEM NUMBER',
       IM_ITEM.DESCR AS 'DESCRIPTION',
       MAX(T2.BUS_DAT) AS 'TRANSACTION Date',
       T3.NAM AS 'PRIMARY VENDOR'
   FROM IM_ITEM
       LEFT JOIN PS_TKT_HIST_LIN T2 ON T2.ITEM_NO = IM_ITEM.ITEM_NO 
           AND BUS_DAT >= '20250301'
       LEFT JOIN PO_VEND T3 ON T3.VEND_NO = IM_ITEM.ITEM_VEND_NO
   GROUP BY IM_ITEM.ITEM_NO, IM_ITEM.DESCR, T3.NAM 
   ORDER BY IM_ITEM.ITEM_NO
   ```

2. **Tables Used:**
   - `IM_ITEM` - Item master (all products)
   - `PS_TKT_HIST_LIN` - **Ticket History Line** (sales transaction history)
   - `PO_VEND` - Vendor master (supplier information)

3. **What It Returns:**
   - Item number (SKU)
   - Item description
   - **Most recent sale date** (from sales history)
   - **Primary vendor name**

---

## ⚠️ **Potential Issue Found**

**Date Filter:** `BUS_DAT >= '20250301'` (March 1, 2025)

- This date is **in the future** (as of Dec 2025)
- Likely should be `'20240301'` (March 1, 2024) or `'20230301'` (March 1, 2023)
- **Impact:** May return no results or incomplete data

**Recommendation:** Update the date filter to a past date, or make it configurable.

---

## ✅ **Potential Uses**

### **1. Slow-Moving Inventory Analysis** ⭐⭐⭐
- **Identify items that haven't sold recently**
- **Dead stock detection** - items with no sales in X months
- **Inventory optimization** - reduce stock of slow movers

### **2. Sales Performance Analysis** ⭐⭐
- **Which items are selling frequently**
- **Sales trends** - compare recent sales dates
- **Product lifecycle tracking**

### **3. Vendor Relationship Tracking** ⭐
- **Which vendors supply which products**
- **Vendor performance analysis**
- **Supplier relationship management**

### **4. E-commerce Product Prioritization** ⭐⭐⭐
- **Focus marketing on recently sold items**
- **Identify products to feature on website**
- **Product recommendation engine data**

---

## 🔧 **How to Use This Script**

### **Option 1: Find Slow-Moving Items**
```sql
-- Items with no sales in last 6 months
SELECT * FROM (
    -- Your script here
) AS SalesData
WHERE [TRANSACTION Date] < DATEADD(MONTH, -6, GETDATE())
   OR [TRANSACTION Date] IS NULL
ORDER BY [TRANSACTION Date] ASC
```

### **Option 2: Find Recently Sold Items**
```sql
-- Items sold in last 30 days
SELECT * FROM (
    -- Your script here
) AS SalesData
WHERE [TRANSACTION Date] >= DATEADD(DAY, -30, GETDATE())
ORDER BY [TRANSACTION Date] DESC
```

### **Option 3: Add Inventory Information**
```sql
-- Add current stock levels
SELECT 
    s.[ITEM NUMBER],
    s.[DESCRIPTION],
    s.[TRANSACTION Date],
    s.[PRIMARY VENDOR],
    ISNULL(SUM(inv.QTY_ON_HND), 0) AS [CURRENT STOCK]
FROM (
    -- Your script here
) AS s
LEFT JOIN IM_INV inv ON inv.ITEM_NO = s.[ITEM NUMBER]
GROUP BY s.[ITEM NUMBER], s.[DESCRIPTION], s.[TRANSACTION Date], s.[PRIMARY VENDOR]
```

---

## 💡 **Recommended Improvements**

### **1. Fix Date Filter**
```sql
-- Use last 12 months instead of hardcoded date
AND BUS_DAT >= DATEADD(MONTH, -12, GETDATE())
```

### **2. Add Inventory Information**
```sql
-- Include current stock levels
LEFT JOIN (
    SELECT ITEM_NO, SUM(QTY_ON_HND) AS TOTAL_STOCK
    FROM IM_INV
    GROUP BY ITEM_NO
) inv ON inv.ITEM_NO = IM_ITEM.ITEM_NO
```

### **3. Add E-commerce Filter**
```sql
-- Only show e-commerce items
WHERE IM_ITEM.IS_ECOMM_ITEM = 'Y'
```

### **4. Add Days Since Last Sale**
```sql
-- Calculate days since last sale
DATEDIFF(DAY, MAX(T2.BUS_DAT), GETDATE()) AS DAYS_SINCE_LAST_SALE
```

---

## 🎯 **Integration with WooCommerce**

### **Potential Use Cases:**

1. **Product Sync Priority:**
   - Sync recently sold items first
   - Deprioritize items with no recent sales

2. **Inventory Management:**
   - Identify items to discontinue on website
   - Focus marketing on active sellers

3. **Reporting:**
   - Sales performance reports
   - Vendor performance tracking
   - Product lifecycle analysis

---

## 📋 **Action Items**

- [ ] **Fix date filter** - Update `'20250301'` to a past date or use dynamic date
- [ ] **Test the query** - Run it and see what data it returns
- [ ] **Add inventory info** - Include current stock levels
- [ ] **Add e-commerce filter** - Only show `IS_ECOMM_ITEM = 'Y'`
- [ ] **Document purpose** - Add comments explaining what it's used for
- [ ] **Consider integration** - Use for product sync prioritization

---

## ✅ **Verdict**

**Keep this script!** It's useful for:
- ✅ Sales analysis
- ✅ Inventory management
- ✅ Product prioritization
- ✅ Vendor tracking

**But fix the date filter first** - it's likely filtering out all data!

---

## 📝 **Improved Version**

See `All_Items_With_Most_Recent_Sale_IMPROVED.sql` for an enhanced version with:
- Dynamic date filtering
- Inventory information
- E-commerce filter
- Days since last sale calculation


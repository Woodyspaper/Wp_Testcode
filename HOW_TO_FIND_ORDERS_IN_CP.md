# How to Find Orders in CounterPoint
**Quick Guide: Finding WooCommerce Orders in CounterPoint**

**Date:** January 5, 2026

---

## 📍 **FINDING YOUR TWO ORDERS**

### **Order #15487 (OSCAR GOMEZ)**
- **WooCommerce Order:** #15487
- **CounterPoint Ticket Number:** `101-000004`
- **CounterPoint DOC_ID:** `103398648481`
- **Customer:** OSCAR GOMEZ

### **Order #15479 (Jon Wittenberg)**
- **WooCommerce Order:** #15479
- **CounterPoint Ticket Number:** `101-000005`
- **CounterPoint DOC_ID:** `103398648482`
- **Customer:** Jon Wittenberg (Minuteman Press)

---

## 🖥️ **METHOD 1: CounterPoint UI (Sales Tickets Screen)**

### **Step-by-Step:**

1. **Open CounterPoint**
   - Launch NCR CounterPoint application

2. **Navigate to Sales Tickets**
   - Go to: **Sales** → **Sales Tickets** (or **Tickets**)
   - Or use shortcut if available

3. **Search for Order**
   - **Option A:** Search by Ticket Number
     - Enter: `101-000004` (for Order #15487)
     - Enter: `101-000005` (for Order #15479)
   - **Option B:** Search by Customer
     - Search for: `OSCAR GOMEZ` (Order #15487)
     - Search for: `Jon Wittenberg` or `Minuteman Press` (Order #15479)

4. **View Order Details**
   - Click on the ticket to open order details
   - You should see:
     - Order header information
     - Line items
     - Totals
     - Shipping address (if linked)

---

## 🔍 **METHOD 2: SQL Query (Direct Database Access)**

### **Quick Verification Query:**

```sql
-- Find both orders by ticket number
SELECT 
    h.DOC_ID,
    h.TKT_NO,
    h.CUST_NO,
    c.NAM AS CustomerName,
    h.TKT_DT AS OrderDate,
    h.SHIP_DAT AS ShipDate,
    h.SHIP_TO_CONTACT_ID,
    t.SUB_TOT,
    t.TAX_AMT,
    t.TOT AS TotalAmount
FROM dbo.PS_DOC_HDR h
LEFT JOIN dbo.AR_CUST c ON h.CUST_NO = c.CUST_NO
LEFT JOIN dbo.PS_DOC_HDR_TOT t ON h.DOC_ID = t.DOC_ID AND t.TOT_TYP = 'S'
WHERE h.TKT_NO IN ('101-000004', '101-000005')
ORDER BY h.TKT_NO
```

### **View Line Items:**

```sql
-- Get line items for both orders
SELECT 
    h.TKT_NO,
    l.LIN_SEQ_NO,
    l.ITEM_NO,
    l.DESCR,
    l.QTY_SOLD,
    l.PRC,
    l.EXT_PRC
FROM dbo.PS_DOC_HDR h
INNER JOIN dbo.PS_DOC_LIN l ON h.DOC_ID = l.DOC_ID
WHERE h.TKT_NO IN ('101-000004', '101-000005')
ORDER BY h.TKT_NO, l.LIN_SEQ_NO
```

### **View Shipping Address:**

```sql
-- Get shipping address for both orders
SELECT 
    h.TKT_NO,
    h.CUST_NO,
    ship.NAM AS ShipToName,
    ship.ADRS_1,
    ship.ADRS_2,
    ship.CITY,
    ship.STATE,
    ship.ZIP_COD,
    ship.PHONE_1
FROM dbo.PS_DOC_HDR h
LEFT JOIN dbo.AR_SHIP_ADRS ship ON ship.CUST_NO = h.CUST_NO 
    AND ship.SHIP_ADRS_ID = CAST(h.SHIP_TO_CONTACT_ID AS VARCHAR(10))
WHERE h.TKT_NO IN ('101-000004', '101-000005')
ORDER BY h.TKT_NO
```

---

## 📋 **WHAT YOU SHOULD SEE**

### **Order Header Information:**
- ✅ **Ticket Number:** `101-000004` or `101-000005`
- ✅ **Customer Number:** Customer's CUST_NO
- ✅ **Order Date:** Date order was created
- ✅ **Ship Date:** NULL (not shipped yet) or date if shipped
- ✅ **Shipping Method:** Shipping code (e.g., "UPS Ground")

### **Line Items:**
- ✅ **Item Numbers:** SKUs from WooCommerce
- ✅ **Descriptions:** Product descriptions
- ✅ **Quantities:** Quantities ordered
- ✅ **Prices:** Unit prices
- ✅ **Extended Prices:** Line totals

### **Totals:**
- ✅ **Subtotal:** Order subtotal
- ✅ **Tax Amount:** Tax charged
- ✅ **Total:** Order total

### **Shipping Address:**
- ✅ **Ship-to Name:** Shipping name
- ✅ **Address:** Shipping address lines
- ✅ **City, State, ZIP:** Shipping location
- ✅ **Phone:** Shipping phone (if provided)

---

## 🔗 **LINKING BACK TO WOOCOMMERCE**

### **Find WooCommerce Order from CounterPoint:**

```sql
-- Find WooCommerce order ID from CounterPoint ticket
SELECT 
    h.TKT_NO AS CPTicketNumber,
    s.WOO_ORDER_ID AS WooCommerceOrderID,
    s.WOO_ORDER_NO AS WooCommerceOrderNumber,
    h.CUST_NO,
    c.NAM AS CustomerName
FROM dbo.PS_DOC_HDR h
INNER JOIN dbo.USER_ORDER_STAGING s ON CAST(s.CP_DOC_ID AS BIGINT) = h.DOC_ID
LEFT JOIN dbo.AR_CUST c ON h.CUST_NO = c.CUST_NO
WHERE h.TKT_NO IN ('101-000004', '101-000005')
ORDER BY h.TKT_NO
```

**Expected Results:**
- `101-000004` → WooCommerce Order #15487
- `101-000005` → WooCommerce Order #15479

---

## 🎯 **QUICK REFERENCE**

### **Order #15487 (OSCAR GOMEZ):**
- **Search by:** Ticket `101-000004` OR Customer "OSCAR GOMEZ"
- **DOC_ID:** `103398648481`
- **Status:** Processing (not yet shipped - SHIP_DAT is NULL)

### **Order #15479 (Jon Wittenberg):**
- **Search by:** Ticket `101-000005` OR Customer "Jon Wittenberg" / "Minuteman Press"
- **DOC_ID:** `103398648482`
- **Status:** Processing (not yet shipped - SHIP_DAT is NULL)

---

## 💡 **TIPS**

1. **If you can't find by ticket number:**
   - Try searching by customer name
   - Use SQL query to verify order exists

2. **If shipping address doesn't show:**
   - Check `SHIP_TO_CONTACT_ID` in order header
   - Verify `AR_SHIP_ADRS` record exists

3. **To see all WooCommerce orders:**
   ```sql
   SELECT h.TKT_NO, s.WOO_ORDER_ID, h.TKT_DT, h.CUST_NO
   FROM dbo.PS_DOC_HDR h
   INNER JOIN dbo.USER_ORDER_STAGING s ON CAST(s.CP_DOC_ID AS BIGINT) = h.DOC_ID
   ORDER BY h.TKT_DT DESC
   ```

---

**Last Updated:** January 5, 2026

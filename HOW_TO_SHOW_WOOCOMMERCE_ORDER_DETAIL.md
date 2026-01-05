# How to Show WooCommerce Order Detail in CounterPoint
**Complete Guide: Getting Full Detail for Unpicked WordPress Orders**

**Date:** January 5, 2026

---

## 🎯 **PROBLEM**

Standard CounterPoint reports show `0.00` for financial fields on unpicked WordPress orders, even though all the detail exists in the database.

---

## ✅ **SOLUTION**

We've created:
1. **SQL Views** - For use in CounterPoint reports
2. **Python Report Script** - For detailed reports outside CounterPoint
3. **SQL Queries** - For direct database access

---

## 📊 **METHOD 1: Use SQL View in CounterPoint Reports**

### **Step 1: Deploy the View**

The view `VI_WOOCOMMERCE_ORDERS_DETAIL` has been created. It includes:
- ✅ All financial totals (Subtotal, Tax, Total, Shipping, Discounts)
- ✅ Customer information (Name, Email, Phone, Address)
- ✅ Shipping information (Complete shipping address)
- ✅ Order status and dates
- ✅ Payment method (from staging)
- ✅ Line items count and totals

### **Step 2: Use in CounterPoint Report Builder**

1. **Open CounterPoint Report Builder**
2. **Create New Report** or **Modify Existing Report**
3. **Add Data Source:**
   - Select: `VI_WOOCOMMERCE_ORDERS_DETAIL`
   - This view contains all fields you need

4. **Add Fields to Report:**
   - `TicketNumber` - CounterPoint ticket number
   - `WooCommerceOrderID` - WooCommerce order ID
   - `OrderDate` - Order date
   - `ShipDate` - Ship date (NULL if not shipped)
   - `OrderStatus` - Open/Shipped/Closed
   - `CustomerName` - Customer name
   - `CustomerEmail` - Customer email
   - `CustomerPhone` - Customer phone
   - `ShipToName` - Shipping name
   - `ShipToAddress1`, `ShipToCity`, `ShipToState`, `ShipToZip` - Shipping address
   - `ShippingMethod` - Shipping method
   - `Subtotal` - Order subtotal
   - `TaxAmount` - Tax amount
   - `ShippingAmount` - Shipping cost
   - `TotalAmount` - Order total
   - `HeaderDiscount` - Order-level discount
   - `LineDiscount` - Line item discounts
   - `PaymentMethod` - Payment method (from WooCommerce)
   - `WooCommerceStatus` - Current WooCommerce status

5. **Filter for Unpicked Orders:**
   - Add filter: `OrderStatus = 'Open'` OR `ShipDate IS NULL`
   - This shows only unpicked orders

6. **Save and Run Report**

---

## 🐍 **METHOD 2: Use Python Report Script**

### **Generate Detailed Report:**

```bash
# Show all WooCommerce orders
python generate_woocommerce_orders_report.py

# Show specific orders
python generate_woocommerce_orders_report.py 101-000004 101-000005
```

### **What the Report Shows:**

- ✅ **Order Information:** Ticket number, WooCommerce ID, dates, status
- ✅ **Customer Information:** Name, email, phone, billing address
- ✅ **Shipping Information:** Complete shipping address and phone
- ✅ **Financial Information:** Subtotal, tax, shipping, discounts, total
- ✅ **Payment Information:** Payment method and status
- ✅ **Line Items:** All line items with quantities, prices, totals

---

## 🔍 **METHOD 3: Direct SQL Query**

### **Quick Query for All Detail:**

```sql
-- Get complete detail for specific orders
SELECT * 
FROM dbo.VI_WOOCOMMERCE_ORDERS_DETAIL
WHERE TicketNumber IN ('101-000004', '101-000005')
ORDER BY OrderDate DESC
```

### **Query for Unpicked Orders Only:**

```sql
-- Get all unpicked/open WooCommerce orders with full detail
SELECT * 
FROM dbo.VI_WOOCOMMERCE_ORDERS_DETAIL
WHERE OrderStatus = 'Open'
   OR ShipDate IS NULL
ORDER BY OrderDate DESC
```

### **Query with Line Items:**

```sql
-- Get orders with line items detail
SELECT 
    h.TKT_NO AS TicketNumber,
    s.WOO_ORDER_ID AS WooCommerceOrderID,
    h.TKT_DT AS OrderDate,
    c.NAM AS CustomerName,
    t.SUB_TOT AS Subtotal,
    t.TAX_AMT AS TaxAmount,
    t.TOT AS TotalAmount,
    t.TOT_MISC AS ShippingAmount,
    l.ITEM_NO AS ItemNumber,
    l.DESCR AS ItemDescription,
    l.QTY_SOLD AS Quantity,
    l.PRC AS UnitPrice,
    l.EXT_PRC AS ExtendedPrice
FROM dbo.PS_DOC_HDR h
INNER JOIN dbo.USER_ORDER_STAGING s ON CAST(s.CP_DOC_ID AS BIGINT) = h.DOC_ID
LEFT JOIN dbo.AR_CUST c ON h.CUST_NO = c.CUST_NO
LEFT JOIN dbo.PS_DOC_HDR_TOT t ON h.DOC_ID = t.DOC_ID AND t.TOT_TYP = 'S'
LEFT JOIN dbo.PS_DOC_LIN l ON h.DOC_ID = l.DOC_ID
WHERE s.SOURCE_SYSTEM = 'WOOCOMMERCE'
  AND h.SHIP_DAT IS NULL  -- Unpicked orders
ORDER BY h.TKT_DT DESC, h.TKT_NO, l.LIN_SEQ_NO
```

---

## 📋 **WHAT DETAIL IS AVAILABLE**

### **Financial Information (from PS_DOC_HDR_TOT):**
- ✅ `SUB_TOT` - Subtotal
- ✅ `TAX_AMT` - Tax amount
- ✅ `TOT` - Total amount
- ✅ `TOT_HDR_DISC` - Header discount
- ✅ `TOT_LIN_DISC` - Line discount
- ✅ `TOT_MISC` - Shipping amount
- ✅ `AMT_DUE` - Amount due

### **Customer Information:**
- ✅ Name, Email, Phone
- ✅ Billing Address
- ✅ Shipping Address (complete)

### **Order Information:**
- ✅ Order dates
- ✅ Order status
- ✅ Shipping method
- ✅ Line items (with quantities, prices, totals)

### **Payment Information:**
- ✅ Payment method (from staging)
- ✅ WooCommerce status

---

## 🎯 **COMPARISON: Standard Report vs. Detail View**

### **Standard CounterPoint Report:**
- ❌ Shows `0.00` for financial fields
- ✅ Shows line items
- ✅ Shows customer number
- ❌ Limited financial detail

### **Detail View/Report:**
- ✅ Shows all financial totals (Subtotal, Tax, Total, Shipping)
- ✅ Shows complete customer information
- ✅ Shows complete shipping information
- ✅ Shows payment method
- ✅ Shows line items with full detail
- ✅ Matches WooCommerce detail level

---

## 💡 **RECOMMENDATIONS**

### **For Daily Operations:**

1. **Use Python Report Script:**
   ```bash
   python generate_woocommerce_orders_report.py
   ```
   - Shows all detail in readable format
   - Can filter by ticket numbers
   - Easy to run anytime

2. **Create Custom CounterPoint Report:**
   - Use `VI_WOOCOMMERCE_ORDERS_DETAIL` view
   - Add all fields you need
   - Filter for unpicked orders
   - Save as "WooCommerce Orders Detail Report"

### **For Quick Checks:**

1. **Use SQL Query:**
   ```sql
   SELECT * FROM dbo.VI_WOOCOMMERCE_ORDERS_DETAIL
   WHERE TicketNumber = '101-000004'
   ```

2. **Use Python Script:**
   ```bash
   python generate_woocommerce_orders_report.py 101-000004
   ```

---

## 📝 **FILES CREATED**

1. **`01_Production/create_woocommerce_orders_detail_view.sql`**
   - Creates `VI_WOOCOMMERCE_ORDERS_DETAIL` view
   - Creates `VI_WOOCOMMERCE_ORDERS_LINES` view
   - Use in CounterPoint reports

2. **`generate_woocommerce_orders_report.py`**
   - Python script for detailed reports
   - Shows all WooCommerce order detail
   - Can filter by ticket numbers

3. **`01_Production/QUERY_WOOCOMMERCE_ORDERS_DETAIL.sql`**
   - SQL queries for direct database access
   - Multiple query options

---

## ✅ **VERIFICATION**

The report script successfully shows:
- ✅ Order #15487 (101-000004): Subtotal $47.80, Tax $1.27, Shipping $18.13, Total $67.20
- ✅ Order #15479 (101-000005): Subtotal $250.10, Tax $0.00, Shipping $13.34, Total $263.44
- ✅ Complete customer information
- ✅ Complete shipping information
- ✅ All line items with quantities and prices

**All detail is available - it just needs to be displayed using the view or report script!**

---

**Last Updated:** January 5, 2026

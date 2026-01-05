# Why Unpicked WordPress Orders Show Less Detail
**Understanding the Difference Between Picked and Unpicked Orders in CounterPoint**

**Date:** January 5, 2026

---

## 🔍 **OBSERVATION**

You've noticed that:
- **Picked Orders** (fully shipped): Show comprehensive financial details (costs, profits, amounts received, etc.)
- **Unpicked Orders** (including WordPress orders): Show `0.00` for all financial totals

**Your WordPress Orders:**
- `101-000004` (Order #15487) - Shows `0.00` for all financial fields
- `101-000005` (Order #15479) - Shows `0.00` for all financial fields

---

## ✅ **THIS IS EXPECTED BEHAVIOR**

### **Why WordPress Orders Show `0.00`:**

1. **Payment Processing Location:**
   - ✅ **WooCommerce Side:** Payment is processed and recorded in WooCommerce
   - ❌ **CounterPoint Side:** Payment information is NOT transferred to CounterPoint
   - **Result:** CounterPoint financial fields show `0.00` because payment happened elsewhere

2. **CounterPoint Financial Fields:**
   - `Order total amt recvd` - Amount received in CounterPoint (not from WooCommerce)
   - `Order amt expended` - Amount expended in CounterPoint
   - `Order cost` - Cost tracked in CounterPoint inventory system
   - `Grs pft` - Gross profit calculated in CounterPoint
   - **These fields are for CounterPoint-managed transactions, not WooCommerce orders**

3. **Order Status:**
   - WordPress orders show `Doc status: Open` (correct - not yet shipped)
   - `Line type: Sale` or `Order` (correct - not yet "Fully shipped")
   - `SHIP_DAT: NULL` (correct - not yet shipped)

---

## 📊 **WHAT INFORMATION IS PRESENT**

### **✅ Available in Unpicked WordPress Orders:**

1. **Order Header:**
   - ✅ Ticket Number (`101-000004`, `101-000005`)
   - ✅ Customer Number (`10057`, `10022`)
   - ✅ Order Date (`08/25/2025`, `08/18/2025`)
   - ✅ Document Status (`Open`)

2. **Line Items:**
   - ✅ Item Numbers (`01-10251`, `01-11051`)
   - ✅ Quantities (`2.0`, `5.0`)
   - ✅ Descriptions (full product descriptions)
   - ✅ Line Type (`Sale` or `Order`)

3. **Customer Information:**
   - ✅ Customer Name (in customer record)
   - ✅ Shipping Address (in `AR_SHIP_ADRS`)
   - ✅ Contact Information (email, phone)

4. **Financial Information (in PS_DOC_HDR_TOT):**
   - ✅ Subtotal (stored in `PS_DOC_HDR_TOT.SUB_TOT`)
   - ✅ Tax Amount (stored in `PS_DOC_HDR_TOT.TAX_AMT`)
   - ✅ Total Amount (stored in `PS_DOC_HDR_TOT.TOT`)
   - ⚠️ **Note:** These may not show in the report view, but they're in the database

---

## 🔄 **WHAT HAPPENS WHEN ORDER IS SHIPPED**

### **When You Ship a WordPress Order in CounterPoint:**

1. **Set SHIP_DAT:**
   - CounterPoint sets `PS_DOC_HDR.SHIP_DAT` to current date
   - Order status may change to "Shipped" or "Closed"

2. **Line Type Changes:**
   - `Line type: Order` → `Line type: Fully shipped`
   - This indicates fulfillment

3. **Report Detail:**
   - Order will appear in "Picked Orders" report
   - May show more detail in fulfillment reports
   - **BUT:** Financial fields will still show `0.00` (payment was on WooCommerce side)

4. **WooCommerce Sync:**
   - Our fulfillment sync detects `SHIP_DAT` is set
   - Updates WooCommerce status to `'completed'`
   - Adds note: "Order fulfilled and shipped from CounterPoint"

---

## 💡 **WHY PICKED ORDERS HAVE MORE DETAIL**

### **Picked Orders (Fully Shipped) Show:**

1. **Fulfillment Information:**
   - `Line type: Fully shipped` (indicates completion)
   - Ship date information
   - Fulfillment tracking

2. **Financial Details (for CounterPoint-managed orders):**
   - `Order cost` - Inventory cost tracked in CounterPoint
   - `Grs pft` - Gross profit calculated in CounterPoint
   - `Order total amt recvd` - Payment received in CounterPoint
   - **These are populated for orders where CounterPoint manages the full transaction**

3. **Complete Transaction History:**
   - Full lifecycle from order to shipment
   - All CounterPoint-managed financial transactions

---

## 🎯 **KEY DIFFERENCES**

| Aspect | Picked Orders (CP-Managed) | Unpicked WordPress Orders |
|--------|---------------------------|---------------------------|
| **Payment Location** | CounterPoint | WooCommerce |
| **Financial Totals** | Populated (CP-managed) | `0.00` (payment elsewhere) |
| **Order Cost** | Tracked in CP | Not tracked (WooCommerce order) |
| **Gross Profit** | Calculated in CP | Not calculated (WooCommerce order) |
| **Line Type** | `Fully shipped` | `Order` or `Sale` |
| **SHIP_DAT** | Set (shipped) | NULL (not shipped) |
| **Line Items** | ✅ Present | ✅ Present |
| **Customer Info** | ✅ Present | ✅ Present |
| **Shipping Address** | ✅ Present | ✅ Present |
| **Order Totals** | ✅ In database | ✅ In database |

---

## ✅ **WHAT'S IMPORTANT FOR WORDPRESS ORDERS**

### **Essential Information (All Present):**

1. ✅ **Order Identification:**
   - Ticket Number
   - Customer Number
   - Order Date

2. ✅ **Product Information:**
   - Line items with SKUs
   - Quantities
   - Descriptions
   - Prices

3. ✅ **Customer Information:**
   - Customer name
   - Shipping address
   - Contact information

4. ✅ **Financial Totals (in Database):**
   - Subtotal
   - Tax
   - Total
   - **Note:** These are stored in `PS_DOC_HDR_TOT` but may not display in all report views

---

## 🔧 **IF YOU NEED FINANCIAL DETAILS IN REPORTS**

### **Option 1: Query Database Directly**

```sql
-- Get complete financial details for WordPress orders
SELECT 
    h.TKT_NO,
    h.CUST_NO,
    t.SUB_TOT,
    t.TAX_AMT,
    t.TOT AS TotalAmount,
    t.TOT_HDR_DISC AS Discount,
    t.TOT_MISC AS Shipping
FROM dbo.PS_DOC_HDR h
LEFT JOIN dbo.PS_DOC_HDR_TOT t ON h.DOC_ID = t.DOC_ID AND t.TOT_TYP = 'S'
WHERE h.TKT_NO IN ('101-000004', '101-000005')
```

### **Option 2: Custom Report**

Create a custom CounterPoint report that includes:
- Fields from `PS_DOC_HDR_TOT` (subtotal, tax, total)
- Fields from `PS_DOC_HDR` (ticket number, customer, date)
- Fields from `PS_DOC_LIN` (line items)

---

## 📝 **SUMMARY**

### **Why Unpicked WordPress Orders Show Less Detail:**

1. ✅ **Expected Behavior:** Payment is processed on WooCommerce side, not CounterPoint
2. ✅ **Financial Fields:** CounterPoint financial fields (`Order total amt recvd`, `Order cost`, etc.) are for CounterPoint-managed transactions
3. ✅ **Essential Info Present:** All important information (line items, customer, shipping) is present
4. ✅ **Totals in Database:** Financial totals ARE stored in `PS_DOC_HDR_TOT`, just not displayed in standard reports

### **When Order is Shipped:**

- `SHIP_DAT` will be set
- Line type may change to "Fully shipped"
- Order will appear in "Picked Orders" report
- WooCommerce status will sync to "completed"
- **BUT:** Financial fields will still show `0.00` (payment was on WooCommerce side)

---

## 🎯 **RECOMMENDATION**

**This is working as designed.** The difference in detail is because:

1. **WooCommerce orders:** Payment processed externally, CounterPoint tracks fulfillment
2. **CounterPoint orders:** Full transaction lifecycle managed in CounterPoint

**All essential information is present** - the financial totals are in the database (`PS_DOC_HDR_TOT`) even if they don't show in the standard report view.

If you need financial details in reports, you can:
- Query the database directly (see SQL above)
- Create a custom CounterPoint report
- Use our Python scripts to generate reports

---

**Last Updated:** January 5, 2026

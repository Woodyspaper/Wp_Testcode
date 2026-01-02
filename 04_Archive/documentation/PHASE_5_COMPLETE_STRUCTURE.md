# Phase 5: Complete Order Structure

**Date:** December 31, 2025  
**Purpose:** Complete reference for creating CounterPoint orders from WooCommerce staging

---

## 📊 **COMPLETE ORDER STRUCTURE**

### **Three Tables Required:**

1. **PS_DOC_HDR** - Order header
2. **PS_DOC_HDR_TOT** - Order totals
3. **PS_DOC_LIN** - Order lines

**All three must be created together!**

---

## 🔄 **COMPLETE MAPPING**

### **1. PS_DOC_HDR (Order Header)**

| Field | Source | Required | Notes |
|-------|--------|----------|-------|
| `DOC_ID` | Generated | YES | CounterPoint generates (bigint) |
| `DOC_TYP` | Set to 'O' | YES | 'O' = Order |
| `STR_ID` | Default '01' | YES | Store ID |
| `STA_ID` | Default '101' | YES | Station ID |
| `TKT_NO` | Generated | YES | CounterPoint generates |
| `CUST_NO` | Staging | YES | From USER_ORDER_STAGING |
| `TKT_DT` | Staging | YES | From ORD_DAT (convert to datetime) |
| `SHIP_DAT` | Staging | NO | From shipping date |
| `SHIP_VIA_COD` | Staging | NO | From SHIP_VIA |
| `SHIP_ZONE_COD` | Staging | NO | Shipping zone |
| `TAX_COD` | Staging | NO | Tax code |
| `TERMS_COD` | Staging | NO | Terms code |
| `CUST_PO_NO` | Staging | NO | Customer PO number |
| `SLS_REP` | Default | NO | Sales rep |
| `STK_LOC_ID` | Default '01' | NO | Stock location |
| `PRC_LOC_ID` | Default '01' | NO | Price location |

### **2. PS_DOC_HDR_TOT (Order Totals)**

| Field | Source | Required | Notes |
|-------|--------|----------|-------|
| `DOC_ID` | From PS_DOC_HDR | YES | Must match header |
| `TOT_TYP` | Set to 'S' | YES | 'S' = Sales |
| `SUB_TOT` | Staging | YES | From SUBTOT |
| `TAX_AMT` | Staging | YES | From TAX_AMT |
| `TOT` | Staging | YES | From TOT_AMT |
| `TOT_HDR_DISC` | Staging | YES | From DISC_AMT |
| `TOT_LIN_DISC` | Calculated | YES | Sum of line discounts |
| `AMT_DUE` | Calculated | YES | Usually = TOT |
| `TOT_MISC` | Staging | NO | Shipping, etc. |

### **3. PS_DOC_LIN (Order Lines)**

| Field | Source | Required | Notes |
|-------|--------|----------|-------|
| `DOC_ID` | From PS_DOC_HDR | YES | Must match header |
| `LIN_SEQ_NO` | Sequential | YES | 1, 2, 3... |
| `ITEM_NO` | Staging | YES | From line_items[].sku |
| `DESCR` | Staging | NO | From line_items[].name |
| `QTY_SOLD` | Staging | YES | From line_items[].quantity |
| `SELL_UNIT` | Product | YES | From IM_ITEM or default '0' |
| `PRC` | Staging | NO | From line_items[].price |
| `EXT_PRC` | Calculated | YES | qty × price |
| `STK_LOC_ID` | Product | NO | From IM_ITEM or default '01' |
| `CATEG_COD` | Product | NO | From IM_ITEM |

---

## ⚠️ **CRITICAL REQUIREMENTS**

### **Document ID Generation:**
- `DOC_ID` - CounterPoint generates (bigint)
- `TKT_NO` - CounterPoint generates (format: Station-TicketNumber)

### **Date/Time:**
- `TKT_DT` - datetime (NOT separate DAT/TIM columns)
- Convert from staging `ORD_DAT` (date) to datetime

### **Totals Calculation:**
- `TOT` = `SUB_TOT` - `TOT_HDR_DISC` - `TOT_LIN_DISC` + `TAX_AMT` + `TOT_MISC`
- `TOT_LIN_DISC` = Sum of all line item discounts

### **Line Sequence:**
- `LIN_SEQ_NO` must be sequential (1, 2, 3...)
- Must increment for each line item

---

## 🔍 **NEXT STEPS**

1. **Create stored procedure** for order header creation
2. **Create stored procedure** for totals creation
3. **Create stored procedure** for line items creation
4. **Create master procedure** that calls all three
5. **Test with sample order** from staging

---

**Last Updated:** December 31, 2025

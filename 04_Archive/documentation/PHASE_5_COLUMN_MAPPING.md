# Phase 5: Column Mapping Reference

**Date:** December 31, 2025  
**Purpose:** Reference for mapping USER_ORDER_STAGING → PS_DOC_HDR and PS_DOC_LIN

---

## 📋 **PS_DOC_HDR (Order Header) MAPPING**

| USER_ORDER_STAGING | PS_DOC_HDR | Notes |
|-------------------|------------|-------|
| `WOO_ORDER_ID` | (stored in meta) | Reference only |
| `CUST_NO` | `CUST_NO` | Must exist in AR_CUST |
| `ORD_DAT` | `TKT_DT` | **datetime (NOT 'DAT')** |
| `ORD_STATUS` | `STAT` | Order status |
| `PMT_METH` | (payment fields) | Payment method |
| `SHIP_VIA` | `SHIP_VIA_COD` | Shipping method code |
| `SUBTOT` | `PS_DOC_HDR_TOT.SUB_TOT` | Subtotal |
| `SHIP_AMT` | (shipping fields) | Shipping amount (may be in TOT_MISC) |
| `TAX_AMT` | `PS_DOC_HDR_TOT.TAX_AMT` | Tax amount |
| `DISC_AMT` | `PS_DOC_HDR_TOT.TOT_HDR_DISC` | Header discount |
| `TOT_AMT` | `PS_DOC_HDR_TOT.TOT` | Total amount |
| `SHIP_NAM` | `SHIP_NAM` | Ship-to name |
| `SHIP_ADRS_1` | `SHIP_ADRS_1` | Ship-to address 1 |
| `SHIP_ADRS_2` | `SHIP_ADRS_2` | Ship-to address 2 |
| `SHIP_CITY` | `SHIP_CITY` | Ship-to city |
| `SHIP_STATE` | `SHIP_STATE` | Ship-to state |
| `SHIP_ZIP_COD` | `SHIP_ZIP_COD` | Ship-to zip |
| `SHIP_CNTRY` | `SHIP_CNTRY` | Ship-to country |
| `SHIP_PHONE` | `SHIP_PHONE` | Ship-to phone |

**Required Fields:**
- `DOC_ID` - **Must be generated** (CounterPoint format, bigint)
- `DOC_TYP` - Document type ('O' for Order, default: 'T')
- `STR_ID` - Store ID (default: '01')
- `STA_ID` - Station ID (default: '101')
- `TKT_NO` - **Must be generated** (CounterPoint format)
- `TKT_DT` - Order date/time (datetime, NOT 'DAT')
- `CUST_NO` - Customer number (from staging)

---

## 📋 **PS_DOC_LIN (Order Lines) MAPPING**

| Source | PS_DOC_LIN | Notes |
|--------|------------|-------|
| `LINE_ITEMS_JSON` (parsed) | - | Parse JSON array |
| `line_items[].sku` | `ITEM_NO` | Must exist in IM_ITEM |
| `line_items[].name` | `DESCR` | Product description |
| `line_items[].quantity` | `QTY_SOLD` | **NOT QTY_ORD** |
| `line_items[].price` | `PRC` | Unit price |
| `line_items[].total` | `EXT_PRC` | **Calculate: qty × price** |
| (from IM_ITEM) | `SELL_UNIT` | Get from product or default '0' |
| (from IM_ITEM) | `STK_LOC_ID` | Get from product or default '01' |
| (from IM_ITEM) | `CATEG_COD` | Get from product |

**Required Fields:**
- `DOC_ID` - From PS_DOC_HDR
- `LIN_SEQ_NO` - Sequential (1, 2, 3...)
- `ITEM_NO` - Product SKU
- `QTY_SOLD` - Quantity (default: 1)
- `SELL_UNIT` - Selling unit (default: '0')
- `EXT_PRC` - Extended price (required, no default)

---

## ⚠️ **CRITICAL FINDINGS**

### **PS_DOC_HDR:**
- ✅ **Date column is `TKT_DT`** (datetime, NOT 'DAT')
- ✅ `DOC_ID` must be generated (CounterPoint format, bigint)
- ✅ `TKT_NO` must be generated (CounterPoint format)
- ✅ `DOC_TYP` required ('O' for Order, default: 'T')

### **PS_DOC_HDR_TOT:**
- ✅ **Totals table found:** `PS_DOC_HDR_TOT`
- ✅ `SUB_TOT` - Subtotal
- ✅ `TAX_AMT` - Tax amount
- ✅ `TOT` - Total amount
- ✅ `TOT_HDR_DISC` - Header discount
- ✅ `TOT_LIN_DISC` - Line discounts (sum)
- ⚠️ **Ship-to address** - May be in separate table

### **PS_DOC_LIN:**
- ✅ `QTY_SOLD` is the quantity column (NOT `QTY_ORD`)
- ✅ `SELL_UNIT` is varchar(1) - single character code
- ✅ `EXT_PRC` is required - must calculate
- ✅ `LIN_SEQ_NO` must be sequential

---

## 🔍 **NEXT STEPS**

1. **Run PS_DOC_HDR discovery** to verify date column name
2. **Create stored procedure** for order header creation
3. **Create stored procedure** for order lines creation
4. **Test with sample order** from staging

---

**Last Updated:** December 31, 2025

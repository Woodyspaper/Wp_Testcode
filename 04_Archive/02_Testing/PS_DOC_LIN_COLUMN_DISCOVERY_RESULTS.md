# PS_DOC_LIN Column Discovery Results

**Date:** December 31, 2025  
**Purpose:** Document actual column names in PS_DOC_LIN for Phase 5: Order Creation

---

## ✅ **KEY COLUMNS FOR ORDER CREATION**

### **Required Columns:**

| Column Name | Data Type | Nullable | Notes |
|-------------|-----------|----------|-------|
| `DOC_ID` | bigint | NO | Document ID (links to PS_DOC_HDR) |
| `LIN_SEQ_NO` | int | NO | Line sequence number |
| `ITEM_NO` | varchar(20) | NO | Product SKU |
| `DESCR` | varchar(250) | YES | Product description |
| `QTY_SOLD` | decimal | NO | **Quantity (default: 1)** |
| `SELL_UNIT` | varchar(1) | NO | **Selling unit (default: '0')** |
| `PRC` | money | YES | Unit price |
| `EXT_PRC` | decimal | NO | Extended price (qty × price) |
| `STK_LOC_ID` | varchar(10) | YES | Stock location ID |
| `CATEG_COD` | varchar(10) | YES | Category code |

### **Important Notes:**

1. **Quantity Column:** `QTY_SOLD` (NOT `QTY_ORD` as assumed)
   - Default: `((1))`
   - Type: `decimal`
   - Required: NO (but has default)

2. **Selling Unit:** `SELL_UNIT` 
   - Type: `varchar(1)`
   - Default: `('0')`
   - Required: NO (but has default)

3. **Price Columns:**
   - `PRC` = Unit price (money)
   - `EXT_PRC` = Extended price (decimal, required, no default)

4. **Location:**
   - `STK_LOC_ID` = Stock location (varchar(10), nullable)

---

## 📊 **SAMPLE DATA STRUCTURE**

From actual row:
```
DOC_ID: 103398648477
LIN_SEQ_NO: 1
ITEM_NO: 01-11174
DESCR: 8.5X11 60# FLUORESCENT PINK PERM SCORED 100/PK 2000/CT WC0616
QTY_SOLD: 3.0000
SELL_UNIT: PK
PRC: 21.1831
EXT_PRC: 63.55
STK_LOC_ID: 01
CATEG_COD: PRINT AND
```

---

## 🔄 **MAPPING FROM USER_ORDER_STAGING**

| Staging Field | PS_DOC_LIN Column | Notes |
|---------------|-------------------|-------|
| `LINE_ITEMS_JSON` (parsed) | - | Parse JSON to get line items |
| `line_items[].sku` | `ITEM_NO` | Product SKU |
| `line_items[].name` | `DESCR` | Product name |
| `line_items[].quantity` | `QTY_SOLD` | Quantity |
| `line_items[].price` | `PRC` | Unit price |
| `line_items[].total` | `EXT_PRC` | Line total |
| (from product mapping) | `SELL_UNIT` | Get from IM_ITEM or default to '0' |
| (from product mapping) | `STK_LOC_ID` | Get from IM_ITEM or default to '01' |
| (from product mapping) | `CATEG_COD` | Get from IM_ITEM |

---

## ⚠️ **IMPORTANT FINDINGS**

1. **No `QTY_ORD` column** - Use `QTY_SOLD` instead
2. **No `QTY_SHIP` column** - Use `QTY_SHIPPED` if needed
3. **`SELL_UNIT` is varchar(1)** - Single character code
4. **`EXT_PRC` is required** - Must calculate: qty × price
5. **`LIN_SEQ_NO` must be sequential** - Start at 1, increment per line

---

**Last Updated:** December 31, 2025

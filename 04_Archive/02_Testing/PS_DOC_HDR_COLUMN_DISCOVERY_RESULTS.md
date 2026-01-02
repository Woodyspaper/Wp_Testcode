# PS_DOC_HDR Column Discovery Results

**Date:** December 31, 2025  
**Purpose:** Document actual column names in PS_DOC_HDR for Phase 5: Order Creation

---

## ✅ **KEY COLUMNS FOR ORDER CREATION**

### **Required Columns:**

| Column Name | Data Type | Nullable | Default | Notes |
|-------------|-----------|----------|---------|-------|
| `DOC_ID` | bigint | NO | NULL | **Must be generated** (CounterPoint format) |
| `DOC_TYP` | varchar(1) | NO | ('T') | Document type (T=Ticket, O=Order, Q=Quote) |
| `STR_ID` | varchar(10) | NO | NULL | Store ID (default: '01') |
| `STA_ID` | varchar(10) | NO | NULL | Station ID |
| `TKT_NO` | varchar(15) | NO | NULL | Ticket number (generated) |
| `CUST_NO` | varchar(15) | YES | NULL | Customer number |
| `TKT_DT` | datetime | YES | NULL | **Order date/time (NOT 'DAT')** |
| `SHIP_DAT` | datetime | YES | NULL | Ship date |
| `SHIP_VIA_COD` | varchar(10) | YES | NULL | Shipping method code |
| `SHIP_ZONE_COD` | varchar(10) | YES | NULL | Shipping zone |
| `TAX_COD` | varchar(10) | YES | NULL | Tax code |
| `TERMS_COD` | varchar(10) | YES | NULL | Terms code |
| `CUST_PO_NO` | varchar(20) | YES | NULL | Customer PO number |
| `SLS_REP` | varchar(10) | YES | NULL | Sales rep |
| `STK_LOC_ID` | varchar(10) | YES | NULL | Stock location |
| `PRC_LOC_ID` | varchar(10) | YES | NULL | Price location |
| `LST_MAINT_DT` | datetime | YES | NULL | Last maintenance date |

### **Line Count Columns (Auto-calculated):**

| Column Name | Data Type | Notes |
|-------------|-----------|-------|
| `ORD_LINS` | int | Order lines count (default: 0) |
| `SAL_LIN_TOT` | decimal | Sales line total (default: 0) |

---

## ⚠️ **CRITICAL FINDINGS**

### **Missing Expected Columns:**
- ❌ **NO `DAT` column** - Use `TKT_DT` instead
- ❌ **NO `TIM` column** - Time is part of `TKT_DT` (datetime)
- ❌ **NO `SUBTOT` column** - May need to calculate or use different field
- ❌ **NO `DISC_AMT` column** - May be in totals table or calculated
- ❌ **NO `TAX_AMT` column** - May be in totals table or calculated
- ❌ **NO `TOT_AMT` column** - May be in totals table or calculated

### **Important Notes:**

1. **Date Column:** `TKT_DT` (datetime) - Contains both date and time
   - NOT `DAT` as expected
   - NOT separate `DAT` and `TIM` columns

2. **Document ID:** `DOC_ID` (bigint) - Must be generated
   - Format appears to be: `103398648477` (large integer)
   - CounterPoint generates this automatically

3. **Document Type:** `DOC_TYP` (varchar(1))
   - Default: 'T' (Ticket)
   - Options: 'T'=Ticket, 'O'=Order, 'Q'=Quote
   - For WooCommerce orders, use 'O' (Order)

4. **Ticket Number:** `TKT_NO` (varchar(15))
   - Format: `Q103-000059` (Station-TicketNumber)
   - Must be generated

5. **Totals:** May be in separate totals table (`PS_DOC_HDR_TOT`) or calculated
   - Need to investigate totals structure

---

## 📊 **SAMPLE DATA STRUCTURE**

From actual row:
```
DOC_ID: 103398648477
DOC_TYP: Q (Quote)
STR_ID: 01
STA_ID: 103
TKT_NO: Q103-000059
CUST_NO: 2221
TKT_DT: 2025-07-17 15:33:50.000
SHIP_DAT: 2025-07-17 19:33:50.000
ORD_LINS: 0
SAL_LINS: 1
SAL_LIN_TOT: 63.55
```

---

## 🔄 **MAPPING FROM USER_ORDER_STAGING**

| Staging Field | PS_DOC_HDR Column | Notes |
|---------------|-------------------|-------|
| `CUST_NO` | `CUST_NO` | Must exist in AR_CUST |
| `ORD_DAT` | `TKT_DT` | **Convert date to datetime** |
| `SHIP_VIA` | `SHIP_VIA_COD` | Shipping method code |
| `SHIP_NAM` | (ship-to fields) | May need separate ship-to table |
| `SHIP_ADRS_1` | (ship-to fields) | May need separate ship-to table |
| `SHIP_CITY` | (ship-to fields) | May need separate ship-to table |
| `SHIP_STATE` | (ship-to fields) | May need separate ship-to table |
| `SHIP_ZIP_COD` | (ship-to fields) | May need separate ship-to table |
| `SHIP_CNTRY` | (ship-to fields) | May need separate ship-to table |
| `PMT_METH` | (payment fields) | May need separate payment table |
| `SUBTOT` | (totals) | **Need to find totals table** |
| `TAX_AMT` | (totals) | **Need to find totals table** |
| `TOT_AMT` | (totals) | **Need to find totals table** |

**Generated Fields:**
- `DOC_ID` - **CounterPoint generates**
- `TKT_NO` - **CounterPoint generates**
- `DOC_TYP` - Set to 'O' for Order
- `STR_ID` - Default to '01'
- `STA_ID` - Default to '101' or similar

---

## 🔍 **NEXT STEPS**

1. **Investigate totals table** - Find where SUBTOT, TAX_AMT, TOT_AMT are stored
2. **Investigate ship-to address** - May be in separate table
3. **Investigate payment fields** - May be in separate table
4. **Test document ID generation** - Understand CounterPoint's ID generation

---

**Last Updated:** December 31, 2025

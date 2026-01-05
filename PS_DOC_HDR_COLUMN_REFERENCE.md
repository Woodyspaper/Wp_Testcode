# PS_DOC_HDR Column Reference
**Source of Truth:** `01_Production/sp_CreateOrderFromStaging.sql`

## ✅ CORRECT COLUMN NAMES

### PS_DOC_HDR (Order Header)
| Column | Type | Notes |
|--------|------|-------|
| `DOC_ID` | bigint | Document ID (generated) |
| `DOC_GUID` | uniqueidentifier | GUID (required, use NEWID()) |
| `DOC_TYP` | varchar(1) | Document type ('O' for Order) |
| `STR_ID` | varchar(10) | Store ID (default: '01') |
| `STA_ID` | varchar(10) | Station ID (default: '101') |
| `TKT_NO` | varchar(15) | **Ticket Number** (generated, format: "101-000004") |
| `CUST_NO` | varchar(15) | Customer number |
| `TKT_DT` | datetime | **Order Date** (NOT `ORD_DAT`, NOT `DAT`) |
| `SHIP_VIA_COD` | varchar(10) | Shipping method code |
| `STK_LOC_ID` | varchar(10) | Stock location |
| `PRC_LOC_ID` | varchar(10) | Price location |
| `ORD_LINS` | int | Order lines count |
| `SAL_LINS` | int | Sales lines count |
| `SAL_LIN_TOT` | decimal | Sales line total |

### PS_DOC_HDR_TOT (Order Totals)
**⚠️ IMPORTANT: Totals are in a SEPARATE table, NOT in PS_DOC_HDR!**

| Column | Type | Notes |
|--------|------|-------|
| `DOC_ID` | bigint | Links to PS_DOC_HDR.DOC_ID |
| `TOT_TYP` | varchar(1) | Total type ('S' for Sales) |
| `SUB_TOT` | decimal | **Subtotal** (NOT `SUBTOT`) |
| `TAX_AMT` | decimal | **Tax Amount** |
| `TOT` | decimal | **Total Amount** (NOT `TOT_AMT`) |
| `TOT_HDR_DISC` | decimal | Header discount (NOT `DISC_AMT`) |
| `TOT_LIN_DISC` | decimal | Line discount |
| `AMT_DUE` | decimal | Amount due |
| `TOT_MISC` | decimal | Miscellaneous charges (shipping) |
| `INITIAL_MIN_DUE` | decimal | Required (cannot be NULL) |
| `TOT_WEIGHT` | money | Total weight (default: 0) |
| `TOT_CUBE` | money | Total cube (default: 0) |
| `TAX_AMT_SHIPPED` | decimal | Required (cannot be NULL) |

### PS_DOC_LIN (Order Lines)
| Column | Type | Notes |
|--------|------|-------|
| `DOC_ID` | bigint | Links to PS_DOC_HDR |
| `TKT_NO` | varchar(15) | Ticket number |
| `LIN_SEQ_NO` | int | Line sequence number |
| `ITEM_NO` | varchar(20) | Item/SKU number |
| `DESCR` | varchar(250) | Description |
| `QTY_SOLD` | decimal(15,4) | Quantity (NOT `QTY_ORD`) |
| `PRC` | money | Unit price |
| `EXT_PRC` | decimal(15,2) | Extended price |

## ❌ COMMON MISTAKES TO AVOID

1. **Date Column:** Use `TKT_DT` (NOT `ORD_DAT`, NOT `DAT`)
2. **Total Amount:** Use `PS_DOC_HDR_TOT.TOT` (NOT `TOT_AMT` in PS_DOC_HDR)
3. **Subtotal:** Use `PS_DOC_HDR_TOT.SUB_TOT` (NOT `SUBTOT` in PS_DOC_HDR)
4. **Tax:** Use `PS_DOC_HDR_TOT.TAX_AMT` (NOT in PS_DOC_HDR)
5. **Discount:** Use `PS_DOC_HDR_TOT.TOT_HDR_DISC` (NOT `DISC_AMT` in PS_DOC_HDR)

## 📝 CORRECT QUERY TEMPLATE

```sql
-- Find orders with correct column names
SELECT 
    h.DOC_ID,
    h.TKT_NO,
    h.CUST_NO,
    h.TKT_DT AS OrderDate,           -- ✅ CORRECT
    t.SUB_TOT AS Subtotal,           -- ✅ From PS_DOC_HDR_TOT
    t.TAX_AMT AS TaxAmount,          -- ✅ From PS_DOC_HDR_TOT
    t.TOT AS TotalAmount             -- ✅ From PS_DOC_HDR_TOT
FROM dbo.PS_DOC_HDR h
LEFT JOIN dbo.PS_DOC_HDR_TOT t ON h.DOC_ID = t.DOC_ID AND t.TOT_TYP = 'S'
WHERE h.DOC_ID IN (103398648481, 103398648482)
ORDER BY h.DOC_ID;
```

## 🔍 SOURCE OF TRUTH

**Always reference:** `01_Production/sp_CreateOrderFromStaging.sql`
- This is the actual code that creates orders
- It shows exactly which columns are used
- It's the definitive source for column names

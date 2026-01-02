# PS_DOC_HDR_TOT Column Discovery Results

**Date:** December 31, 2025  
**Purpose:** Document totals table structure for Phase 5: Order Creation

---

## ✅ **TOTALS TABLE FOUND: PS_DOC_HDR_TOT**

### **Key Totals Columns:**

| Column Name | Data Type | Nullable | Default | Notes |
|-------------|-----------|----------|---------|-------|
| `DOC_ID` | bigint | NO | NULL | Links to PS_DOC_HDR |
| `TOT_TYP` | varchar(1) | NO | NULL | Total type (S=Sales, etc.) |
| `SUB_TOT` | decimal | NO | ((0)) | **Subtotal** |
| `TAX_AMT` | decimal | NO | NULL | **Tax amount** |
| `TOT` | decimal | NO | ((0)) | **Total amount** |
| `TOT_HDR_DISC` | decimal | NO | NULL | **Header discount** |
| `TOT_LIN_DISC` | decimal | NO | NULL | **Line discount** |
| `AMT_DUE` | decimal | NO | ((0)) | Amount due |
| `TOT_MISC` | decimal | NO | ((0)) | Miscellaneous charges |
| `TOT_EXT_COST` | decimal | YES | NULL | Total extended cost |
| `TOT_WEIGHT` | money | NO | NULL | Total weight |
| `TOT_CUBE` | money | NO | NULL | Total cube |

### **Sample Data:**

```
DOC_ID: 103398648477
TOT_TYP: S (Sales)
SUB_TOT: 63.55
TAX_AMT: 0.00
TOT: 63.55
TOT_HDR_DISC: 0.00
TOT_LIN_DISC: 0.00
AMT_DUE: 63.55
```

---

## 🔄 **MAPPING FROM USER_ORDER_STAGING**

| Staging Field | PS_DOC_HDR_TOT Column | Notes |
|---------------|----------------------|-------|
| `SUBTOT` | `SUB_TOT` | Subtotal |
| `TAX_AMT` | `TAX_AMT` | Tax amount |
| `DISC_AMT` | `TOT_HDR_DISC` | Header discount |
| `TOT_AMT` | `TOT` | Total amount |
| (calculated) | `TOT_LIN_DISC` | Sum of line discounts |
| (calculated) | `AMT_DUE` | Usually same as TOT |

---

## ⚠️ **IMPORTANT NOTES**

1. **Required Fields:**
   - `DOC_ID` - Must match PS_DOC_HDR.DOC_ID
   - `TOT_TYP` - Usually 'S' for Sales
   - `SUB_TOT` - Required (default: 0)
   - `TAX_AMT` - Required (no default)
   - `TOT` - Required (default: 0)

2. **Discount Handling:**
   - `TOT_HDR_DISC` - Order-level discount
   - `TOT_LIN_DISC` - Sum of all line item discounts
   - Both are required (no defaults)

3. **Calculation:**
   - `TOT` = `SUB_TOT` - `TOT_HDR_DISC` - `TOT_LIN_DISC` + `TAX_AMT` + `TOT_MISC`
   - `AMT_DUE` = `TOT` (usually)

---

## 📊 **COMPLETE ORDER STRUCTURE**

**Order Creation Flow:**
1. Create `PS_DOC_HDR` (order header)
2. Create `PS_DOC_HDR_TOT` (order totals)
3. Create `PS_DOC_LIN` records (order lines)

**All three tables must be created together!**

---

**Last Updated:** December 31, 2025

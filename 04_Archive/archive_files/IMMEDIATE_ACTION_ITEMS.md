# Immediate Action Items

**Date:** December 18, 2024  
**Priority:** HIGH - Critical gaps identified

---

## 🚨 CRITICAL - Must Fix Immediately

### 1. ⚠️ VERIFY TIER PRICING FIELD

**Issue:** Legacy import shows `PROF_COD_1` used for tier levels, but we're using `CATEG_COD`

**Action Required:**
```sql
-- Check CP database to see which field actually controls tier pricing:
SELECT CUST_NO, NAM, CATEG_COD, PROF_COD_1 
FROM dbo.AR_CUST 
WHERE CATEG_COD IN ('TIER1', 'TIER2', 'TIER3', 'TIER4', 'TIER5', 'RESELLER')
   OR PROF_COD_1 IN ('TIER1', 'TIER2', 'TIER3', 'TIER4', 'TIER5', 'RESELLER')
```

**Files to Check:**
- `TIER_LEVEL_IMPORT.csv` - Shows `PROF_COD_1` used
- `CUSTOMER_IMPORT.csv` - Check which field has tier values

**Impact:** If wrong field, tier pricing won't work!

---

### 2. ⚠️ ADD SHIP-TO ADDRESSES

**Missing:** Customers can have multiple ship-to addresses, we only capture billing

**Files Copied:**
- ✅ `legacy_imports/customers/SHIP_TO_IMPORT.csv`

**Action Required:**
1. Create `USER_SHIP_TO_STAGING` table in `staging_tables.sql`
2. Extract ship-to addresses from WooCommerce orders
3. Create stored procedure `usp_Create_ShipTo_From_Staging`
4. Update `woo_customers.py` to extract ship-to addresses

**Structure:**
```sql
CUST_NO, SHIP_ADRS_ID, NAM, ADRS_1, ADRS_2, ADRS_3, 
CITY, STATE, ZIP_COD, COUNTRY
```

**Impact:** HIGH - Many customers need multiple ship-to addresses

---

### 3. ⚠️ ADD CUSTOMER NOTES

**Missing:** Important business information (PO requirements, special instructions)

**Files Copied:**
- ✅ `legacy_imports/customers/CUSTOMER NOTES IMPORT.csv`

**Action Required:**
1. Create `USER_CUSTOMER_NOTES_STAGING` table
2. Extract notes from WooCommerce customer meta/notes
3. Create stored procedure `usp_Create_CustomerNotes_From_Staging`
4. Update `woo_customers.py` to extract customer notes

**Structure:**
```sql
CUST_NO, NOTE_ID, NOTE_DAT, USR_ID, NOTE, NOTE_TXT
```

**Impact:** MEDIUM - Important business information

---

### 4. ⚠️ CREATE CONFIGURATION FILE

**Missing:** Centralized configuration (location codes, price levels, tax codes, sync schedules)

**Files Copied:**
- ✅ `legacy_docs/appsettings.json`

**Action Required:**
1. Create `config.py` or `settings.json` with:
   - Location codes: `["MAIN", "WEB"]`
   - Price level: `"WEB_PRICE"`
   - Tax code default: `"WEB"`
   - Sync schedules (for future automation)
2. Update existing code to use configuration
3. Add location code to order staging

**Impact:** MEDIUM - Better code organization, future automation

---

## 📋 MEDIUM PRIORITY - Enhancements

### 5. Enhance Order Staging

**Missing:** Payment info, tax breakdown, order notes

**Action Required:**
1. Add payment fields to `USER_ORDER_STAGING`:
   - Payment method
   - Payment amount
   - Transaction ID
2. Add tax breakdown
3. Add order notes
4. Add contact information

**Impact:** MEDIUM - Better order tracking

---

### 6. Add Error Handling Patterns

**Missing:** Validation reports similar to CP import logs

**Action Required:**
1. Add pre-staging validation
2. Add error logging (like `.LOG` files)
3. Add validation reports (updated/skipped counts)

**Impact:** MEDIUM - Better debugging and monitoring

---

## ✅ FILES COPIED

### High Priority:
- ✅ `SHIP_TO_IMPORT.csv` → `legacy_imports/customers/`
- ✅ `CUSTOMER NOTES IMPORT.csv` → `legacy_imports/customers/`
- ✅ `TIER_LEVEL_IMPORT.csv` → `legacy_imports/customers/`
- ✅ `appsettings.json` → `legacy_docs/`
- ✅ `IMPORTANT TABLE NAMES.txt` → `legacy_docs/`
- ✅ `WoodyCP SQL Dbase Table List.csv` → `legacy_docs/`

### Already Had:
- ✅ `IM_PRC_RUL.csv` (pricing rules)
- ✅ `IM_PRC_RUL_BRK_import.csv` (price breaks)
- ✅ `IM_PRC_GRP.csv` (price groups)
- ✅ `Customer Spreadsheet 846.xlsx` (customer format)
- ✅ `TAX_CODES_IMPORT_FL_COUNTIES.xlsx` (tax codes)
- ✅ `Address Guidelines.docx` (address guidelines)
- ✅ `Customer Pricing Discounts.xlsx` (tier discounts)

---

## 🎯 RECOMMENDED ORDER OF IMPLEMENTATION

1. **First:** Verify tier pricing field (5 minutes)
2. **Second:** Create configuration file (30 minutes)
3. **Third:** Add ship-to address staging (2-3 hours)
4. **Fourth:** Add customer notes staging (1-2 hours)
5. **Fifth:** Enhance order staging (2-3 hours)
6. **Sixth:** Add error handling patterns (1-2 hours)

**Total Estimated Time:** 7-11 hours

---

## 📝 NEXT STEPS

1. ✅ Review `COMPREHENSIVE_PIPELINE_AUDIT.md` for full details
2. ✅ Verify tier pricing field in CP database
3. ✅ Start implementing ship-to addresses
4. ✅ Start implementing customer notes
5. ✅ Create configuration file

---

**Status:** Ready to implement improvements!

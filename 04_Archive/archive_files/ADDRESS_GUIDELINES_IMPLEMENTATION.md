# Address Guidelines Implementation

**Date:** December 22, 2024  
**Source:** `legacy_docs/Address Guidelines.docx`

---

## ✅ IMPLEMENTATION COMPLETE

### **1. Address Formatting Functions Added to `data_utils.py`**

#### **`format_address_per_guidelines(address: str) -> str`**
Formats address according to Woody's Paper Company guidelines:
- ✅ All text capitalized
- ✅ Ordinal numbers: 1ST, 2ND, 3RD, 4TH
- ✅ Cardinal directions at end: NE not N.E (no periods)
- ✅ Street abbreviations: AVE, BLVD, CR, CRT, DR, HNGR, HWY, PK, PL, RM, ST, TER, TRL, WHSE
- ✅ **SUITE is NOT abbreviated** (per guidelines)

#### **`format_address_line_2(line2: str) -> str`**
Formats Address Line 2 per guidelines:
- ✅ Unit designators: STE 208, HNGR 4A
- ✅ ATTNs for departments or business names
- ✅ All uppercase, proper spacing

#### **Updated `split_long_address()`**
Now uses `format_address_per_guidelines()` before splitting to ensure proper formatting.

---

## ✅ PREFLIGHT VALIDATION CREATED

### **`preflight_validation.sql` - Stored Procedure**

**Procedure:** `usp_Preflight_Validate_Customer_Staging`

**Validates:**
1. ✅ **CUST_NAM_TYP** - Must be 'B' or 'P', not NULL, no trailing spaces
2. ✅ **Address Completeness** - ZIP_COD, STATE, CITY, ADRS_1 required
3. ✅ **Field Length** - All fields within CounterPoint limits
4. ✅ **Tier Values** - PROF_COD_1 must be valid tier (TIER1-5, RESELLER, RETAIL, GOV TIER1-3)
5. ✅ **Trailing Spaces** - No trailing spaces in key fields

**Usage:**
```sql
-- Validate entire batch
EXEC usp_Preflight_Validate_Customer_Staging @BatchID = 'BATCH_20241222_120000';

-- Validate single record
EXEC usp_Preflight_Validate_Customer_Staging @StagingID = 123;

-- Validate all records
EXEC usp_Preflight_Validate_Customer_Staging;
```

**Output:**
- Lists all validation errors with STAGING_ID, BATCH_ID, ERROR_TYPE, FIELD_NAME, FIELD_VALUE
- Provides summary: Error count, Warning count
- Clear pass/fail status

---

## 📋 ADDRESS GUIDELINES SUMMARY

### **General Rules:**
- ✅ All text capitalized
- ✅ Ordinal numbers: 1ST, 2ND, 3RD, 4TH (not FIRST, SECOND, etc.)
- ✅ Cardinal directions at end: NE not N.E (no periods)

### **Address Line 2:**
- ✅ Unit designators: STE 208, HNGR 4A
- ✅ ATTNs for departments or business names

### **Abbreviations:**
| Term | Abbreviation |
|------|--------------|
| AVENUE | AVE |
| BOULEVARD | BLVD |
| CIRCLE | CR |
| COURT | CRT |
| DRIVE | DR |
| HANGER | HNGR |
| HIGHWAY | HWY |
| PARKWAY | PK |
| PLACE | PL |
| ROOM | RM |
| STREET | ST |
| **SUITE** | **DO NOT ABBREVIATE** |
| TERRANCE | TER |
| TRAIL | TRL |
| WAREHOUSE | WHSE |

---

## 🔧 INTEGRATION

### **Python Code:**
Address formatting is now automatic in `data_utils.py`:
- `format_address_per_guidelines()` - Formats address line 1
- `format_address_line_2()` - Formats address line 2
- `split_long_address()` - Uses formatting before splitting

### **SQL Validation:**
Preflight validation runs BEFORE `usp_Create_Customers_From_Staging`:
1. Run `EXEC usp_Preflight_Validate_Customer_Staging @BatchID = '...'`
2. Fix any errors reported
3. Then run `EXEC usp_Create_Customers_From_Staging @BatchID = '...'`

---

## 🎯 WORKFLOW

### **Before Creating Customers:**
```sql
-- Step 1: Preflight validation
EXEC usp_Preflight_Validate_Customer_Staging @BatchID = 'YOUR_BATCH_ID';

-- Step 2: Review errors (if any)
-- Fix errors in USER_CUSTOMER_STAGING table

-- Step 3: Run again to verify
EXEC usp_Preflight_Validate_Customer_Staging @BatchID = 'YOUR_BATCH_ID';

-- Step 4: Create customers (dry-run first)
EXEC usp_Create_Customers_From_Staging 
    @BatchID = 'YOUR_BATCH_ID',
    @DryRun = 1;

-- Step 5: If dry-run looks good, run live
EXEC usp_Create_Customers_From_Staging 
    @BatchID = 'YOUR_BATCH_ID',
    @DryRun = 0;
```

---

## ✅ BENEFITS

1. **Prevents Constraint Violations** - Catches errors BEFORE insert
2. **Address Consistency** - All addresses formatted per company standards
3. **Early Error Detection** - Find issues before they cause failures
4. **Clear Error Messages** - Know exactly what to fix
5. **Validated Data** - Ensures data quality before insertion

---

## 📝 NEXT STEPS

1. ✅ **Address formatting** - Implemented in `data_utils.py`
2. ✅ **Preflight validation** - Created in `preflight_validation.sql`
3. ⏳ **Update `woo_customers.py`** - Use `format_address_per_guidelines()` when extracting addresses
4. ⏳ **Test preflight validation** - Run on staging data
5. ⏳ **Document workflow** - Add to integration guide

---

**Status:** ✅ **IMPLEMENTATION COMPLETE**

**Files Created/Modified:**
- ✅ `data_utils.py` - Added address formatting functions
- ✅ `preflight_validation.sql` - Created preflight validation procedure


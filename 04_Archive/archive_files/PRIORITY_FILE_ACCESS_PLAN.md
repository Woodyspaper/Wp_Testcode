# Priority File Access Plan

**Date:** December 18, 2024  
**Purpose:** Prioritized list of files to copy from Desktop 003 for integration work

---

## 🎯 IMMEDIATE PRIORITY (Copy These First)

### Critical for Pricing Work

**Location:** `RW Working FIle/CounterPoint Transistion/CP Imports/`

1. ✅ **`IM_PRC_RUL.csv`**
   - **Why:** Our `staging_tables.sql` had schema errors with `IM_PRC_RUL`
   - **Impact:** Will resolve pricing rule import issues
   - **Action:** Copy to `legacy_imports/` folder

2. ✅ **`IM_PRC_RUL_BRK_import.csv`**
   - **Why:** Our `study_cp_pricing.py` failed querying this table
   - **Impact:** Will clarify price break structure
   - **Action:** Copy to `legacy_imports/` folder

3. ✅ **`IM_PRC_GRP.csv`**
   - **Why:** Price groups may relate to our tier pricing
   - **Impact:** May simplify tier implementation
   - **Action:** Copy to `legacy_imports/` folder

### Critical for Customer Data

**Location:** `RW Working FIle/CounterPoint Transistion/CP Imports/`

4. ✅ **`Customer Spreadsheet 846.xlsx`**
   - **Why:** Compare with our `USER_CUSTOMER_STAGING` structure
   - **Impact:** Validate staging table format
   - **Action:** Copy to `legacy_imports/` folder

**Location:** `RW Working FIle/Process Documentation/`

5. ✅ **`Address Guidelines.docx`**
   - **Why:** Our `extract_best_customer_data()` handles addresses
   - **Impact:** Ensure compliance with company standards
   - **Action:** Copy to `legacy_docs/` folder

6. ✅ **`Customer Pricing Discounts.xlsx`**
   - **Why:** We're implementing tier-based pricing
   - **Impact:** Understand existing discount logic
   - **Action:** Copy to `legacy_docs/` folder

### Critical for Tax Handling

**Location:** `RW Working FIle/CounterPoint Transistion/CP Imports/`

7. ✅ **`TAX_CODES_IMPORT_FL_COUNTIES.xlsx`**
   - **Why:** Address validation and tax code assignment
   - **Impact:** Proper tax handling in orders
   - **Action:** Copy to `legacy_imports/` folder

---

## 📋 HIGH PRIORITY (Copy Next)

### Import/Export Procedures

**Location:** `Training/Counterpoint/`

8. ✅ **`Data Interchange_Importing.docx`**
   - **Why:** Understand CP import workflow
   - **Impact:** Align our staging → CP process
   - **Action:** Copy to `legacy_docs/` folder

9. ✅ **`Data Interchange_Exporting.docx`**
   - **Why:** Understand CP export format
   - **Impact:** Validate our export scripts
   - **Action:** Copy to `legacy_docs/` folder

### Category & Product Mapping

**Location:** `RW Working FIle/Process Documentation/`

10. ✅ **`Approved Categories.xlsx`**
    - **Why:** Category mapping between WooCommerce and CP
    - **Impact:** Category sync logic
    - **Action:** Copy to `legacy_docs/` folder

**Location:** `RW Working FIle/CounterPoint Transistion/`

11. ✅ **`Categories.xlsx`**
    - **Why:** May show WooCommerce → CP category mappings
    - **Impact:** Category transition reference
    - **Action:** Copy to `legacy_docs/` folder

**Location:** `RW Working FIle/`

12. ✅ **`Woodys Paper Naming Scheme.xlsx`**
    - **Why:** Product name standardization
    - **Impact:** Ensure product names match standards
    - **Action:** Copy to `legacy_docs/` folder

### WordPress Integration

**Location:** `RW Working FIle/Wordpress/`

13. ✅ **All 6 files** (3 CSV, 2 Excel, 1 SQL)
    - **Why:** May contain existing customer/product mappings
    - **Impact:** Check for existing sync logic
    - **Action:** Copy entire `Wordpress/` folder to `legacy_imports/wordpress/`

---

## 🔍 MEDIUM PRIORITY (Reference)

### API & Configuration

**Location:** `RW Working FIle/`

14. ✅ **`API Login path URL.txt`**
    - **Why:** May include WooCommerce API endpoints
    - **Impact:** Verify API configuration
    - **Action:** Copy to `legacy_docs/` folder

15. ✅ **`WPSERVER1 Info.txt`**
    - **Why:** Server details
    - **Impact:** Verify server configuration
    - **Action:** Copy to `legacy_docs/` folder

### Additional Pricing Files

**Location:** `RW Working FIle/CounterPoint Transistion/CP Imports/`

16. ✅ **`im_prc_group.csv`** / **`im_prc_group_enable_all.csv`** / **`im_prc_group_fix.csv`**
    - **Why:** Price group variations and fixes
    - **Impact:** Understand price group troubleshooting
    - **Action:** Copy to `legacy_imports/` folder

---

## 📁 Recommended Folder Structure

After copying files, organize them in our workspace:

```
WP_Testcode/
├── legacy_imports/          # CP import examples
│   ├── pricing/
│   │   ├── IM_PRC_RUL.csv
│   │   ├── IM_PRC_RUL_BRK_import.csv
│   │   ├── IM_PRC_GRP.csv
│   │   └── im_prc_group*.csv
│   ├── customers/
│   │   └── Customer Spreadsheet 846.xlsx
│   ├── tax/
│   │   └── TAX_CODES_IMPORT_FL_COUNTIES.xlsx
│   └── wordpress/           # WordPress integration files
│       └── (6 files)
├── legacy_docs/             # Documentation
│   ├── Address Guidelines.docx
│   ├── Customer Pricing Discounts.xlsx
│   ├── Approved Categories.xlsx
│   ├── Categories.xlsx
│   ├── Woodys Paper Naming Scheme.xlsx
│   ├── Data Interchange_Importing.docx
│   ├── Data Interchange_Exporting.docx
│   ├── API Login path URL.txt
│   └── WPSERVER1 Info.txt
└── (existing files...)
```

---

## 🚀 Action Plan

### Step 1: Create Folders
```powershell
cd "c:\Users\Administrator.ADWPC-MAIN\OneDrive - woodyspaper.com\Desktop\WP_Testcode"
mkdir legacy_imports\pricing
mkdir legacy_imports\customers
mkdir legacy_imports\tax
mkdir legacy_imports\wordpress
mkdir legacy_docs
```

### Step 2: Copy Priority 1 Files
Copy these 7 files first (most critical):
1. `IM_PRC_RUL.csv`
2. `IM_PRC_RUL_BRK_import.csv`
3. `IM_PRC_GRP.csv`
4. `Customer Spreadsheet 846.xlsx`
5. `Address Guidelines.docx`
6. `Customer Pricing Discounts.xlsx`
7. `TAX_CODES_IMPORT_FL_COUNTIES.xlsx`

### Step 3: Review & Analyze
Once files are copied:
1. **Review pricing rule imports** - Understand CP schema
2. **Compare customer format** - Validate our staging tables
3. **Review address guidelines** - Update our address handling
4. **Analyze discount structure** - Refine tier pricing

### Step 4: Update Code
Based on findings:
1. Fix any schema mismatches in `staging_tables.sql`
2. Update `data_utils.py` address handling if needed
3. Refine tier pricing logic
4. Add category mapping if needed

---

## 📊 Expected Benefits

### Immediate Benefits:
- ✅ **Resolve pricing schema errors** - Understand `IM_PRC_RUL` structure
- ✅ **Validate staging tables** - Ensure format matches CP expectations
- ✅ **Comply with standards** - Address formatting guidelines
- ✅ **Understand discounts** - Existing tier pricing logic

### Long-term Benefits:
- ✅ **Category mapping** - WooCommerce ↔ CP category sync
- ✅ **Product naming** - Standardization compliance
- ✅ **Tax handling** - Proper Florida county tax codes
- ✅ **Import procedures** - Best practices alignment

---

## ⚠️ Notes

- **Desktop 003** is a client machine (not headless server)
- Files need to be copied manually or via network share
- Some files may be outdated - verify against current CP version
- Large files (backups) can be skipped for now
- Focus on import format examples, not full data sets

---

## 🔗 Related Files

After copying, we'll create:
- `analyze_pricing_imports.py` - Script to analyze pricing rule format
- `compare_customer_format.py` - Compare customer import format
- `validate_address_guidelines.py` - Check address compliance
- `category_mapping.py` - Category sync logic

---

**Status:** Waiting for file access/copy  
**Next Step:** Copy Priority 1 files (7 files)  
**Estimated Time:** 15-30 minutes to copy and organize

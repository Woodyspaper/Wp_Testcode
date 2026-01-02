# Legacy Documentation Reference

**Source:** Desktop 003 (Previous IT Guy's Files)  
**Date:** December 18, 2024  
**Purpose:** Map legacy documentation to current WooCommerce ↔ CounterPoint integration

---

## 🎯 Most Relevant to Our Integration

### 1. **CounterPoint Import Files** ⭐ CRITICAL
**Location:** `RW Working FIle/CounterPoint Transistion/CP Imports/`

**28 import files including:**
- ✅ **Pricing rule imports** (`IM_PRC_RUL`, `IM_PRC_RUL_BRK`) - **KEY FOR OUR PRICING WORK!**
- ✅ **Price group imports** (`IM_PRC_GRP`)
- ✅ **Customer imports** - Format examples for our staging tables
- ✅ **Item/Vendor imports** - Product sync reference
- ✅ **Tax code imports** (`TAX_CODES_IMPORT_FL_COUNTIES.xlsx`) - For our address handling

**Action Items:**
- [ ] Review pricing rule import format to understand CP schema
- [ ] Check customer import format vs our `USER_CUSTOMER_STAGING`
- [ ] Review tax code structure for address validation

---

### 2. **Process Documentation** ⭐ HIGH VALUE
**Location:** `RW Working FIle/Process Documentation/`

**Key Files:**
- ✅ `Address Guidelines.docx` - **CRITICAL** for our customer address handling
- ✅ `Customer Pricing Discounts.xlsx` - **RELEVANT** to our tier pricing work
- ✅ `Approved Categories.xlsx` - Category mapping reference
- ✅ `Reference Tool.xlsx` - General reference

**Action Items:**
- [ ] Review address guidelines to ensure our `extract_best_customer_data()` follows standards
- [ ] Check customer pricing discounts format
- [ ] Map approved categories to WooCommerce categories

---

### 3. **Training Materials** ⭐ REFERENCE
**Location:** `Training/Counterpoint/`

**Key Files:**
- ✅ `Data Interchange_Exporting.docx` - Export procedures
- ✅ `Data Interchange_Importing.docx` - **IMPORTANT** for understanding CP import process
- ✅ `Counterpoint Reports Needed_custom rpts to create.docx` - Custom report requirements

**Action Items:**
- [ ] Review import procedures to ensure our staging tables align
- [ ] Check if custom reports are needed for our integration

---

### 4. **API & Configuration** ⭐ USEFUL
**Location:** `RW Working FIle/`

**Files:**
- ✅ `API Login path URL.txt` - API authentication paths (may include WooCommerce API info)
- ✅ `WPSERVER1 Info.txt` - Server information

**Action Items:**
- [ ] Check if API paths include WooCommerce endpoints
- [ ] Verify server info matches our current setup

---

### 5. **WordPress Files** ⭐ DIRECTLY RELEVANT
**Location:** `RW Working FIle/Wordpress/`

**6 files** (CSV, Excel, SQL)
- WordPress data exports/imports
- May contain customer/product mappings

**Action Items:**
- [ ] Review WordPress files for existing customer/product mappings
- [ ] Check if any existing sync logic exists

---

## 📋 File Mapping to Our Current Code

### Our Code → Legacy Files Reference

| Our Code/Feature | Relevant Legacy File | Purpose |
|------------------|---------------------|---------|
| `woo_customers.py` | `CP Imports/*customer*.csv` | Customer import format reference |
| `woo_orders.py` | `Data Interchange_Importing.docx` | Order import procedures |
| `staging_tables.sql` | `CP Imports/IM_PRC_RUL*.csv` | Pricing rule schema reference |
| `data_utils.py` (address handling) | `Address Guidelines.docx` | Address formatting standards |
| `manage_woo_customers.py` | `Customer Pricing Discounts.xlsx` | Tier pricing reference |
| `export_woo_customers.py` | `Data Interchange_Exporting.docx` | Export format reference |
| Tax code handling | `TAX_CODES_IMPORT_FL_COUNTIES.xlsx` | Tax code structure |

---

## 🔍 Specific Files to Review

### Priority 1 (CRITICAL - Immediate Value)

#### Pricing Rule Imports ⭐⭐⭐
1. **`CP Imports/IM_PRC_RUL.csv`** - Pricing rule import format
   - **Why:** We're working with `IM_PRC_RUL` table in `staging_tables.sql`
   - **Use:** Understand CP pricing rule structure and column names
   - **Current Issue:** We had schema mismatch errors - this will clarify!

2. **`CP Imports/IM_PRC_RUL_BRK_import.csv`** - Pricing rule break import
   - **Why:** We're working with `IM_PRC_RUL_BRK` table
   - **Use:** Understand price break structure (quantity tiers)
   - **Current Issue:** Our `study_cp_pricing.py` failed on this table

3. **`CP Imports/IM_PRC_GRP.csv`** - Price group import
   - **Why:** Price groups may be related to our tier pricing
   - **Use:** Understand how price groups work in CP

#### Address & Customer Data ⭐⭐⭐
4. **`Address Guidelines.docx`** - Address formatting standards
   - **Why:** Our `extract_best_customer_data()` handles addresses
   - **Use:** Ensure we follow company standards
   - **Location:** Root + Process Documentation folder

5. **`Customer Pricing Discounts.xlsx`** - Discount structure
   - **Why:** We're implementing tier-based pricing
   - **Use:** Understand existing discount logic
   - **Location:** Process Documentation folder

6. **`CP Imports/Customer Spreadsheet 846.xlsx`** - Customer import format
   - **Why:** Compare with our `USER_CUSTOMER_STAGING` structure
   - **Use:** Validate our staging table format matches CP expectations

#### Tax & Location Data ⭐⭐
7. **`TAX_CODES_IMPORT_FL_COUNTIES.xlsx`** - Florida county tax codes
   - **Why:** Address validation and tax handling
   - **Use:** Implement proper tax code assignment
   - **Location:** CP Transition folder + CP Imports folder

### Priority 2 (HIGH VALUE - Reference)

#### Import Procedures ⭐⭐
8. **`Training/Counterpoint/Data Interchange_Importing.docx`** - Import procedures
   - **Why:** Understand CP import workflow
   - **Use:** Ensure our staging → CP process aligns with best practices

9. **`Training/Counterpoint/Data Interchange_Exporting.docx`** - Export procedures
   - **Why:** Understand CP export format
   - **Use:** Validate our export scripts match CP standards

#### Category & Product Data ⭐⭐
10. **`Approved Categories.xlsx`** - Approved category list
    - **Why:** Category mapping between WooCommerce and CP
    - **Use:** Create category mapping table
    - **Location:** Process Documentation folder

11. **`CP Imports/Categories.xlsx`** - Category mapping for transition
    - **Why:** May show WooCommerce → CP category mappings
    - **Use:** Category sync logic

12. **`Woodys Paper Naming Scheme.xlsx`** - Naming conventions
    - **Why:** Product name standardization
    - **Use:** Ensure product names match company standards

#### WordPress Integration ⭐⭐
13. **`Wordpress/` folder (6 files)** - WordPress data exports
    - **Why:** May contain existing customer/product mappings
    - **Use:** Check for existing sync logic or mappings
    - **Files:** 3 CSV, 2 Excel, 1 SQL

### Priority 3 (USEFUL - Background)

#### API & Configuration ⭐
14. **`API Login path URL.txt`** - API authentication paths
    - **Why:** May include WooCommerce API endpoints
    - **Use:** Verify API configuration

15. **`WPSERVER1 Info.txt`** - Server information
    - **Why:** Server details for our integration
    - **Use:** Verify server configuration

#### Vendor & Terms ⭐
16. **`Vendors.xlsx`** - Vendor information
    - **Why:** Vendor data structure reference
    - **Use:** Future vendor sync work

17. **`Terms.xlsx`** - Terms and conditions
    - **Why:** Payment terms reference
    - **Use:** Order processing logic

### Priority 2 (Reference)
4. **`CP Imports/*customer*.csv`** - Customer import examples
   - **Why:** Validate our staging table format
   - **Use:** Compare with `USER_CUSTOMER_STAGING`

5. **`Data Interchange_Importing.docx`** - Import procedures
   - **Why:** Understand CP import workflow
   - **Use:** Ensure our staging → CP process aligns

6. **`TAX_CODES_IMPORT_FL_COUNTIES.xlsx`** - Tax code structure
   - **Why:** Address validation and tax handling
   - **Use:** Implement proper tax code assignment

---

## 💡 Integration Insights

### What We Can Learn:

1. **Pricing Rules Format:**
   - Legacy files show how pricing rules were imported
   - May reveal CP schema details we're missing
   - Could help with our contract pricing work

2. **Address Standards:**
   - Company has specific address formatting guidelines
   - Our code should align with these standards
   - May need to update `data_utils.py` address handling

3. **Import Workflow:**
   - Previous IT guy had established import procedures
   - We should align our staging → CP process with these
   - May reveal best practices we're missing

4. **Category Mapping:**
   - Approved categories list exists
   - Should map WooCommerce categories to CP categories
   - May need category mapping table

---

## 🚀 Recommended Next Steps

### Immediate Actions:
1. **Access Desktop 003** and copy these files to our workspace:
   - `CP Imports/IM_PRC_RUL*.csv` (pricing rules)
   - `Address Guidelines.docx`
   - `Customer Pricing Discounts.xlsx`
   - `TAX_CODES_IMPORT_FL_COUNTIES.xlsx`

2. **Review pricing rule imports** to understand CP schema:
   ```bash
   # After copying files:
   # Review IM_PRC_RUL import format
   # Compare with our staging_tables.sql
   ```

3. **Update address handling** based on guidelines:
   - Review `Address Guidelines.docx`
   - Update `data_utils.py` if needed
   - Test with real customer addresses

### Future Enhancements:
4. **Create category mapping** based on approved categories
5. **Document import workflow** aligning with legacy procedures
6. **Review tax code handling** using Florida county codes

---

## 📝 Notes

- **Desktop 003** is a client machine, not the headless server
- Files were copied/pasted (not directly accessible)
- May need to request access or have files copied to network share
- Some files may be outdated - verify against current CP version

---

## 🔗 Related Documentation

- `staging_tables.sql` - Our staging table definitions
- `WOOCOMMERCE_KNOWN_ISSUES.md` - WooCommerce quirks
- `EDGE_CASES_COVERED.md` - Edge case handling
- `data_utils.py` - Data sanitization (address handling)

---

**Last Updated:** December 18, 2024  
**Status:** Reference document - needs file access to complete review

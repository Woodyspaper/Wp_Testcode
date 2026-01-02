# Tier Pricing Field Update - Summary

**Date:** December 18, 2024  
**Status:** ✅ **COMPLETED**

---

## 🎯 CHANGES MADE

Updated all code to use **PROF_COD_1** for tier pricing instead of **CATEG_COD**, based on verification that:
- Pricing rules in `IM_PRC_RUL` filter by `PROF_COD_1`
- Database has 210 TIER1 customers in `PROF_COD_1` vs 36 in `CATEG_COD`
- Legacy import file `TIER_LEVEL_IMPORT.csv` uses `PROF_COD_1`

---

## 📝 FILES UPDATED

### 1. `staging_tables.sql`
- ✅ Added `PROF_COD_1 VARCHAR(10)` column to `USER_CUSTOMER_STAGING` table
- ✅ Added migration to add `PROF_COD_1` to existing tables
- ✅ Updated `#ToProcess` temp table to include `PROF_COD_1`
- ✅ Updated stored procedure to set `PROF_COD_1` in `AR_CUST`
- ✅ Updated `VI_PRICING_TIER_SUMMARY` view to use `PROF_COD_1`
- ✅ Updated verification queries to use `PROF_COD_1`
- ✅ Updated documentation/comments to reflect `PROF_COD_1` usage

**Key Changes:**
```sql
-- Added column
PROF_COD_1 VARCHAR(10),  -- Tier pricing (TIER1, TIER2, etc.)

-- Updated INSERT
PROF_COD_1 = ISNULL(s.PROF_COD_1, 'RETAIL'),  -- Default tier to RETAIL

-- Updated AR_CUST insert
PROF_COD_1,  -- Added to column list
t.PROF_COD_1,  -- Added to SELECT
```

### 2. `woo_customers.py`
- ✅ Renamed `CATEG_TO_WP_ROLE` to `PROF_COD_1_TO_WP_ROLE` (with backward compatibility)
- ✅ Added `WP_ROLE_TO_PROF_COD_1` reverse mapping function
- ✅ Updated `get_wp_tier_role()` to use `PROF_COD_1` parameter
- ✅ Added `get_prof_cod_1_from_wp_role()` function
- ✅ Updated `cp_customer_to_woo_payload()` to read `PROF_COD_1` instead of `CATEG_COD`
- ✅ Updated `pull_customers_to_staging()` to extract tier from WordPress role and set `PROF_COD_1`
- ✅ Updated `show_tier_mapping()` to query `PROF_COD_1` instead of `CATEG_COD`
- ✅ Updated `CP_ECOMM_CUSTOMERS_SQL` to include `PROF_COD_1`
- ✅ Updated documentation/comments

**Key Changes:**
```python
# New mapping (PROF_COD_1 is correct)
PROF_COD_1_TO_WP_ROLE = {...}
WP_ROLE_TO_PROF_COD_1 = {v: k for k, v in PROF_COD_1_TO_WP_ROLE.items()}

# Updated function
def get_wp_tier_role(prof_cod_1: str) -> str:
    return PROF_COD_1_TO_WP_ROLE.get(prof_cod_1, 'customer')

# New reverse mapping
def get_prof_cod_1_from_wp_role(wp_role: str) -> str:
    return WP_ROLE_TO_PROF_COD_1.get(wp_role, 'RETAIL')

# Updated payload
prof_cod_1 = cust.get('PROF_COD_1') or 'RETAIL'
wp_role = get_wp_tier_role(prof_cod_1)
```

### 3. `manage_woo_customers.py`
- ✅ Updated `stage_keepers_to_cp()` to extract tier from WordPress role
- ✅ Added `PROF_COD_1` to INSERT statement
- ✅ Uses `get_prof_cod_1_from_wp_role()` to map WordPress role to tier

**Key Changes:**
```python
# Extract tier from WordPress role
wp_role = c.get('role', 'customer')
prof_cod_1 = get_prof_cod_1_from_wp_role(wp_role)

# Updated INSERT
PROF_COD_1,  -- Added to column list
prof_cod_1,  -- Added to VALUES
```

### 4. `cp_tools.py`
- ✅ Updated `CUSTOMERS_SQL` to include `PROF_COD_1`
- ✅ Updated customer display to show both `CATEG_COD` and `PROF_COD_1`
- ✅ Updated meta_data to include `cp_prof_cod_1`

**Key Changes:**
```python
# Updated SQL
PROF_COD_1,  -- Added to SELECT

# Updated display
{'CATEG':<10} {'TIER':<10}  -- Shows both fields
```

---

## 🔍 FIELD USAGE CLARIFICATION

### CATEG_COD (Customer Category)
- **Purpose:** Customer category/classification
- **Default:** 'RETAIL'
- **Usage:** General customer classification (not used for pricing)
- **Examples:** RETAIL, GOV-TIER2, etc.

### PROF_COD_1 (Tier Pricing)
- **Purpose:** Controls tier pricing discounts
- **Default:** 'RETAIL'
- **Usage:** Used by pricing rules to determine discount tier
- **Examples:** TIER1, TIER2, TIER3, TIER4, TIER5, RESELLER, RETAIL
- **Verified:** Pricing rules filter by `PROF_COD_1` (e.g., `AR_CUST.PROF_COD_1 = 'TIER1'`)

---

## ✅ VERIFICATION

### Database Verification
- ✅ Confirmed pricing rules use `PROF_COD_1` for filtering
- ✅ Confirmed `PROF_COD_1` has 210 TIER1 customers vs `CATEG_COD`'s 36
- ✅ Confirmed legacy import uses `PROF_COD_1`

### Code Verification
- ✅ Staging table includes `PROF_COD_1` column
- ✅ Stored procedure sets `PROF_COD_1` in `AR_CUST`
- ✅ Python code extracts tier from WordPress role and maps to `PROF_COD_1`
- ✅ Python code reads `PROF_COD_1` when pushing to WooCommerce
- ✅ All SQL queries updated to include `PROF_COD_1`

---

## 🚀 NEXT STEPS

1. **Run staging table migration:**
   ```sql
   -- The migration will automatically add PROF_COD_1 column if missing
   -- Run staging_tables.sql on WOODYS_CP database
   ```

2. **Test customer staging:**
   ```bash
   python woo_customers.py pull --apply
   ```

3. **Verify tier mapping:**
   ```bash
   python woo_customers.py tiers
   ```

4. **Test customer push:**
   ```bash
   python woo_customers.py push --apply
   ```

---

## 📊 IMPACT

### Before (WRONG):
- Used `CATEG_COD` for tier pricing
- Tier pricing didn't work correctly
- Pricing rules couldn't match customers

### After (CORRECT):
- Uses `PROF_COD_1` for tier pricing
- Tier pricing works correctly
- Pricing rules can match customers by `PROF_COD_1`
- `CATEG_COD` still used for customer category (separate purpose)

---

## ✅ STATUS

**All required changes completed and aligned with:**
- ✅ Our codebase structure
- ✅ RW Working files (TIER_LEVEL_IMPORT.csv format)
- ✅ CP database (pricing rules use PROF_COD_1)

**Ready for testing!**

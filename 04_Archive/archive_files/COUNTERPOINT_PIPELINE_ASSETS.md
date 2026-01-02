# CounterPoint Pipeline Assets Reference

**Date:** December 18, 2024  
**Source:** Woodys Paper Company Folder Analysis  
**Purpose:** Map existing CounterPoint → WordPress/WooCommerce assets to our current integration code

---

## 🎯 CRITICAL FINDINGS

### 1. **Existing Plugin Configuration** ⭐⭐⭐
**Location:** `COUNTERPOINT/eComm Plugin/cp-counterpoint/cp_wp_installer_kit/appsettings.json`

**Key Configuration:**
```json
{
  "WordPress": {
    "BaseUrl": "https://www.woodyspaper.com",
    "ApiKey": "7B6310E8EF709FF86D1639F0A7197B96",
    "TimeoutSeconds": 30
  },
  "CounterPoint": {
    "ConnectionString": "Driver={ODBC Driver 17 for SQL Server};Server=adwpc-main;Database=WOODYS_CP;Trusted_Connection=Yes;",
    "LocationCodes": ["MAIN", "WEB"],
    "PriceLevel": "WEB_PRICE",
    "TaxCodeDefault": "WEB"
  },
  "Schedules": {
    "CatalogSyncCron": "0 */6 * * *",      // Every 6 hours
    "InventorySyncCron": "*/5 * * * *",    // Every 5 minutes
    "OrderPushCron": "*/2 * * * *"         // Every 2 minutes
  }
}
```

**Impact on Our Code:**
- ✅ **Sync Schedules:** We should align our sync frequency with these
- ✅ **Price Level:** Use `WEB_PRICE` for WooCommerce pricing
- ✅ **Location Codes:** Handle `MAIN` and `WEB` locations
- ✅ **Tax Code:** Default to `WEB` for e-commerce orders

**Action Items:**
- [ ] Review `woo_client.py` - verify API key matches
- [ ] Update `sync.py` - implement scheduled syncs
- [ ] Add price level handling to pricing sync
- [ ] Document location code logic

---

### 2. **Import Templates & CSV Formats** ⭐⭐⭐
**Location:** `COUNTERPOINT/Archives/Migration Files/`

**Critical Files:**
- `CUSTOMER_IMPORT.csv` - **Customer format reference**
- `ITEM_IMPORT_TEST.csv` - **Product format reference**
- `ECOM_DESCRIPTION_IMPORT.csv` - **E-commerce descriptions**
- `CATEGORY_IMPORT.csv` - **Category mappings**
- `TIER_LEVEL_IMPORT.csv` - **Pricing tiers**
- `SHIP_TO_IMPORT.csv` - **Ship-to addresses**

**Impact on Our Code:**
- ✅ **Customer Format:** Compare with our `USER_CUSTOMER_STAGING` structure
- ✅ **Product Format:** Reference for `woo_products.py` (future)
- ✅ **Category Mapping:** Use for category sync logic
- ✅ **Tier Levels:** Validate our tier pricing implementation

**Action Items:**
- [ ] Compare `CUSTOMER_IMPORT.csv` with our staging table
- [ ] Review `TIER_LEVEL_IMPORT.csv` for tier structure
- [ ] Use `CATEGORY_IMPORT.csv` for category mapping
- [ ] Study `ECOM_DESCRIPTION_IMPORT.csv` for product descriptions

---

### 3. **Database Schema Documentation** ⭐⭐⭐
**Location:** `E-commerce & related/WoodyCP SQL Dbase Table List.csv`

**Key Tables (from IMPORTANT TABLE NAMES.txt):**
- `AR_CUST` - Customer master ✅ (we use this)
- `IM_ITEM` - Item master (for product sync)
- `IM_INV` - Inventory (for inventory sync)
- `IM_PRC` - Pricing ✅ (we use this)
- `PS_DOC_HDR` / `PS_DOC_LIN` - Documents/Orders ✅ (we use this)

**Impact on Our Code:**
- ✅ **Validates our table usage** - We're using the right tables
- ✅ **Schema reference** - Complete table list for future work
- ✅ **Field mapping** - Understand all available fields

**Action Items:**
- [ ] Review complete table list for future features
- [ ] Map WooCommerce fields to CP table fields
- [ ] Document field transformations

---

### 4. **Error Patterns & Validation** ⭐⭐
**Location:** `COUNTERPOINT/Archives/Migration Files/*.ERR` and `*.LOG`

**Examples:**
- `CUS_TAX_EX.csv.ERR` / `CUS_TAX_EX.LOG` - Customer tax errors
- `Customer Contract Test.csv.ERR` - Contract validation
- `INV_FIX.csv` / `INV_FIX.LOG` - Inventory corrections
- `M Items Update Decimals.csv` - Decimal precision fixes

**Impact on Our Code:**
- ✅ **Error Handling:** Learn from common import errors
- ✅ **Validation Rules:** Build validation based on error patterns
- ✅ **Fix Routines:** Create automated fix scripts

**Action Items:**
- [ ] Review error logs to understand validation requirements
- [ ] Add validation rules to our staging procedures
- [ ] Create error reporting similar to `.ERR` files

---

### 5. **WooCommerce Export Examples** ⭐⭐
**Location:** `E-commerce & related/wc-product-export-19-8-2025-1755614763998_Edited for import.csv`

**Impact on Our Code:**
- ✅ **Product Structure:** Understand WooCommerce product format
- ✅ **Field Mapping:** Map CP fields to WooCommerce fields
- ✅ **Data Transformation:** See how data is transformed for import

**Action Items:**
- [ ] Review WooCommerce export format
- [ ] Map CP `IM_ITEM` fields to WooCommerce product fields
- [ ] Create product sync script (future)

---

## 📋 Mapping to Our Current Code

### Our Code → Legacy Assets

| Our Code | Legacy Asset | Purpose |
|----------|--------------|---------|
| `woo_customers.py` | `CUSTOMER_IMPORT.csv` | Customer format validation |
| `woo_orders.py` | `PS_DOC_HDR` / `PS_DOC_LIN` | Order structure reference |
| `staging_tables.sql` | `IMPORTANT TABLE NAMES.txt` | Table name validation |
| `manage_woo_customers.py` | `TIER_LEVEL_IMPORT.csv` | Tier pricing structure |
| `data_utils.py` | `SHIP_TO_IMPORT.csv` | Address handling |
| `sync.py` (future) | `appsettings.json` schedules | Sync frequency |
| `woo_products.py` (future) | `ITEM_IMPORT_TEST.csv` | Product format |
| `woo_inventory.py` (future) | `Current_INV_3.28.25.xlsx` | Inventory structure |

---

## 🚀 Immediate Action Items

### Priority 1: Validate Current Implementation

1. **Compare Customer Format**
   ```bash
   # Review CUSTOMER_IMPORT.csv
   # Compare with USER_CUSTOMER_STAGING structure
   # Ensure we're using correct field names
   ```

2. **Review Tier Pricing**
   ```bash
   # Review TIER_LEVEL_IMPORT.csv
   # Validate our tier implementation
   # Ensure CATEG_COD mapping is correct
   ```

3. **Check Sync Schedules**
   ```bash
   # Review appsettings.json schedules
   # Plan our sync.py implementation
   # Document sync frequency requirements
   ```

### Priority 2: Enhance Current Code

4. **Add Price Level Handling**
   - Update pricing sync to use `WEB_PRICE`
   - Handle location codes (`MAIN`, `WEB`)
   - Default tax code to `WEB`

5. **Improve Error Handling**
   - Review `.ERR` and `.LOG` files
   - Add similar error reporting
   - Create validation rules

6. **Category Mapping**
   - Review `CATEGORY_IMPORT.csv`
   - Implement category sync logic
   - Map WooCommerce categories to CP categories

### Priority 3: Future Development

7. **Product Sync** (Phase 2)
   - Use `ITEM_IMPORT_TEST.csv` as reference
   - Map `IM_ITEM` → WooCommerce products
   - Handle e-commerce descriptions

8. **Inventory Sync** (Phase 3)
   - Use `Current_INV_3.28.25.xlsx` as baseline
   - Sync `IM_INV` → WooCommerce stock
   - Implement 5-minute sync

9. **Order Push** (Phase 4)
   - Review order structure
   - Implement WooCommerce → CP order creation
   - Handle order status sync

---

## 📁 File Access Plan

### Immediate Access Needed

**From `COUNTERPOINT/Archives/Migration Files/`:**
1. ✅ `CUSTOMER_IMPORT.csv` - Customer format
2. ✅ `TIER_LEVEL_IMPORT.csv` - Tier pricing
3. ✅ `CATEGORY_IMPORT.csv` - Category mapping
4. ✅ `SHIP_TO_IMPORT.csv` - Address format
5. ✅ `ECOM_DESCRIPTION_IMPORT.csv` - Product descriptions
6. ✅ `IMPORTANT TABLE NAMES.txt` - Table reference

**From `COUNTERPOINT/eComm Plugin/`:**
7. ✅ `appsettings.json` - Configuration reference
8. ✅ `Counterpoint_WordPress_Plugin_Spec Copy.pdf` - Plugin spec

**From `E-commerce & related/`:**
9. ✅ `WoodyCP SQL Dbase Table List.csv` - Schema reference
10. ✅ `wc-product-export-19-8-2025-1755614763998_Edited for import.csv` - WooCommerce format

---

## 🔧 Code Updates Needed

### 1. Update `sync.py` (Future)
```python
# Add sync schedules based on appsettings.json
SYNC_SCHEDULES = {
    'catalog': '0 */6 * * *',      # Every 6 hours
    'inventory': '*/5 * * * *',    # Every 5 minutes
    'orders': '*/2 * * * *'        # Every 2 minutes
}
```

### 2. Update Pricing Logic
```python
# Use WEB_PRICE price level
PRICE_LEVEL = 'WEB_PRICE'
TAX_CODE_DEFAULT = 'WEB'
LOCATION_CODES = ['MAIN', 'WEB']
```

### 3. Add Category Mapping
```python
# Use CATEGORY_IMPORT.csv for mapping
# Map WooCommerce categories to CP categories
```

### 4. Enhance Error Reporting
```python
# Generate .ERR and .LOG files similar to legacy imports
# Add validation rules based on error patterns
```

---

## 📊 Sync Frequency Requirements

Based on `appsettings.json`:

| Sync Type | Frequency | Our Status |
|-----------|-----------|------------|
| **Catalog** | Every 6 hours | ⏳ Not implemented |
| **Inventory** | Every 5 minutes | ⏳ Not implemented |
| **Orders** | Every 2 minutes | ⏳ Not implemented |
| **Customers** | On-demand | ✅ Implemented |
| **Pricing** | On-demand | ✅ Partially implemented |

---

## 🎯 Integration Phases

### Phase 1: Customer & Order Sync ✅ (Current)
- ✅ Customer sync (WooCommerce → CP)
- ✅ Order staging (WooCommerce → CP)
- ✅ Customer mapping
- ⏳ Order creation in CP (staging only)

### Phase 2: Product Sync (Next)
- ⏳ Product sync (CP → WooCommerce)
- ⏳ Category mapping
- ⏳ E-commerce descriptions
- ⏳ Product images

### Phase 3: Inventory Sync
- ⏳ Inventory sync (CP → WooCommerce)
- ⏳ Stock level updates (5-minute sync)
- ⏳ Location handling (MAIN, WEB)

### Phase 4: Pricing Sync
- ⏳ Price sync (CP → WooCommerce)
- ⏳ Tier-based pricing
- ⏳ Customer-specific pricing
- ⏳ Price level handling (WEB_PRICE)

### Phase 5: Order Push
- ⏳ Order creation (WooCommerce → CP)
- ⏳ Order status sync
- ⏳ Payment processing
- ⏳ Shipping integration

---

## 📝 Key Insights

### 1. Configuration Structure
- ✅ Plugin uses `appsettings.json` for configuration
- ✅ Sync schedules are well-defined
- ✅ Connection strings use Windows Auth
- ✅ Price level and tax codes are standardized

### 2. Data Formats
- ✅ CSV imports are well-documented
- ✅ Error logs show validation patterns
- ✅ Fix files show common issues
- ✅ Templates provide format reference

### 3. Database Schema
- ✅ Complete table list available
- ✅ Table relationships documented
- ✅ Field mappings exist
- ✅ Import patterns established

### 4. Error Handling
- ✅ `.ERR` files show validation errors
- ✅ `.LOG` files show import results
- ✅ Fix files show correction patterns
- ✅ Validation rules are documented

---

## 🔗 Related Documentation

- `staging_tables.sql` - Our staging table definitions
- `WOOCOMMERCE_KNOWN_ISSUES.md` - WooCommerce quirks
- `LEGACY_DOCUMENTATION_REFERENCE.md` - Desktop 003 files
- `PRIORITY_FILE_ACCESS_PLAN.md` - File access plan

---

**Last Updated:** December 18, 2024  
**Status:** Reference document - needs file access to complete review  
**Next Step:** Copy Priority 1 files and validate our implementation

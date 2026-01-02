# Root Files Review - What to Keep vs Archive

**Date:** December 30, 2025  
**Purpose:** Review all root-level files to determine what's essential vs what can be archived

---

## ✅ **ESSENTIAL FILES (KEEP IN ROOT)**

### **Core Python Scripts (Active/Production):**
- ✅ `woo_client.py` - WooCommerce API client (used by multiple scripts)
- ✅ `woo_contract_pricing.py` - Contract pricing logic (used by API)
- ✅ `woo_customers.py` - Customer sync (production)
- ✅ `woo_orders.py` - Order sync (production)
- ✅ `woo_products.py` - Product sync (production)
- ✅ `cp_orders_display.py` - CP orders display (used by API)
- ✅ `database.py` - Database connection (used by all scripts)
- ✅ `data_utils.py` - Data utilities (used by multiple scripts)
- ✅ `config.py` - Configuration (used by all scripts)

### **API Code:**
- ✅ `api/` folder - Production API code

### **WordPress Plugins:**
- ✅ `wordpress/` folder - Production WordPress plugins
- ✅ `woocommerce-contract-pricing-plugin.zip` - Plugin package

### **Configuration:**
- ✅ `rules.md` - **CRITICAL** - Project rules
- ✅ `requirements.txt` - Python dependencies
- ✅ `pyrightconfig.json` - Python type checking config
- ✅ `.gitignore` - Git ignore rules

### **Essential Documentation:**
- ✅ `DEPLOYMENT_COMPLETE.md` - Current deployment status
- ✅ `DEPLOYMENT_PROGRESS.md` - Deployment progress tracking
- ✅ `FINAL_STATUS_AND_NEXT_STEPS.md` - Current status
- ✅ `PRODUCTION_READINESS_CHECKLIST.md` - Pre-production checklist
- ✅ `WORDPRESS_CUSTOMER_SETUP_GUIDE.md` - Customer setup guide
- ✅ `SMOKE_TEST_CHECKLIST.md` - Testing checklist
- ✅ `ALL_RECOMMENDATIONS_COMPLETE.md` - Testing summary
- ✅ `TESTING_COMPLETE_SUMMARY.md` - Testing summary

### **Production Scripts:**
- ✅ `create_nssm_waitress_service.ps1` - Service creation (production)
- ✅ `download_nssm.ps1` - NSSM download (production)
- ✅ `deploy_setup.ps1` - Deployment setup (production)
- ✅ `start_api_waitress.ps1` - Start API (production)
- ✅ `start_api_waitress.bat` - Start API batch (production)
- ✅ `Run-WooCustomerSync.ps1` - Customer sync (production)
- ✅ `sync_all_sql_folders.ps1` - SQL sync (production)
- ✅ `sync_sql_files.ps1` - SQL sync (production)

### **Test Scripts (Active/Useful):**
- ✅ `test_wordpress_integration.ps1` - WordPress integration tests
- ✅ `test_all_pricing_methods.ps1` - Pricing method tests
- ✅ `test_edge_cases.ps1` - Edge case tests
- ✅ `monitor_api_health.ps1` - API health monitoring
- ✅ `test_api_health.py` - API health check

---

## ⚠️ **FILES TO REVIEW (Potentially Archive)**

### **Analysis/Reporting Scripts (May be useful for troubleshooting):**
- ⚠️ `analyze_cp_product_status.py` - Product status analysis
  - **Status:** Useful for troubleshooting product sync issues
  - **Recommendation:** Keep or move to `tests/` or `03_Reference/`

- ⚠️ `cp_product_summary.py` - Product summary report
  - **Status:** Useful for generating reports
  - **Recommendation:** Keep or move to `tests/` or `03_Reference/`

- ⚠️ `compare_products.py` - Compare CP vs WooCommerce products
  - **Status:** Useful for troubleshooting product differences
  - **Recommendation:** Keep or move to `tests/` or `03_Reference/`

- ⚠️ `generate_product_sync_report.py` - Generate sync reports
  - **Status:** Useful for generating reports
  - **Recommendation:** Keep or move to `tests/` or `03_Reference/`

### **Test Scripts (May be redundant):**
- ⚠️ `test_api_direct.ps1` - Direct API test
  - **Status:** Similar to `test_wordpress_integration.ps1`
  - **Recommendation:** Archive if redundant

- ⚠️ `test_connection.py` - Connection test
  - **Status:** Basic connection test
  - **Recommendation:** Keep in `tests/` folder

- ⚠️ `test_customer_sync.py` - Customer sync test
  - **Status:** Useful for testing customer sync
  - **Recommendation:** Keep in `tests/` folder

### **Utility Scripts:**
- ⚠️ `fix_all_imports.py` - Fix import statements
  - **Status:** One-time fix script (already run)
  - **Recommendation:** Archive to `04_Archive/`

### **Cleanup Scripts:**
- ⚠️ `CLEANUP_EXECUTION.ps1` - Cleanup script (already run)
  - **Status:** One-time cleanup script
  - **Recommendation:** Archive to `04_Archive/`

- ⚠️ `CLEANUP_SUMMARY.md` - Cleanup summary
  - **Status:** Historical record
  - **Recommendation:** Archive to `04_Archive/docs/`

### **SQL Scripts:**
- ⚠️ `SQL_VERIFICATION_SCRIPT.sql` - SQL verification
  - **Status:** Useful for verification
  - **Recommendation:** Move to `02_Testing/` or keep in root

---

## 📋 **RECOMMENDATIONS**

### **Option 1: Conservative (Keep Everything Useful)**
- Keep all analysis/reporting scripts in root (they're useful for troubleshooting)
- Move test scripts to `tests/` folder
- Archive one-time scripts (`fix_all_imports.py`, `CLEANUP_EXECUTION.ps1`)

### **Option 2: Organized (Move to Appropriate Folders)**
- Move analysis scripts to `03_Reference/` or `tests/`
- Move test scripts to `tests/`
- Archive one-time scripts

### **Option 3: Minimal (Archive Non-Essential)**
- Archive analysis scripts (can be retrieved if needed)
- Archive one-time scripts
- Keep only production scripts in root

---

## ✅ **FINAL RECOMMENDATION**

**Move to appropriate folders:**
1. `test_connection.py` → `tests/`
2. `test_customer_sync.py` → `tests/`
3. `fix_all_imports.py` → `04_Archive/` (one-time script)
4. `CLEANUP_EXECUTION.ps1` → `04_Archive/` (one-time script)
5. `CLEANUP_SUMMARY.md` → `04_Archive/docs/` (historical record)
6. `SQL_VERIFICATION_SCRIPT.sql` → `02_Testing/` (test script)

**Keep in root (useful for troubleshooting):**
- `analyze_cp_product_status.py` - Useful for product analysis
- `cp_product_summary.py` - Useful for reports
- `compare_products.py` - Useful for troubleshooting
- `generate_product_sync_report.py` - Useful for reports
- `test_api_direct.ps1` - Useful for direct API testing

---

**Last Updated:** December 30, 2025

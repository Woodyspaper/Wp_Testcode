# Essential Files Reference

**Date:** December 22, 2024  
**Purpose:** Quick reference to essential files after cleanup

---

## 🎯 **ESSENTIAL SQL FILES**

### **Database Setup & Maintenance**
- **`staging_tables.sql`** - Main database setup (run this first)
- **`preflight_validation.sql`** - Preflight validation procedure
- **`fix_missing_components.sql`** - Fix script (if components missing)

### **Testing & Daily Use**
- **`MASTER_TEST_SCRIPT.sql`** - Complete test workflow (use this for testing)
- **`QUICK_REFERENCE_QUERIES.sql`** - Daily-use queries (keep open)

---

## 🐍 **ESSENTIAL PYTHON FILES**

### **Core Integration Scripts**
- **`woo_customers.py`** - Customer sync from WooCommerce
- **`woo_orders.py`** - Order staging from WooCommerce
- **`data_utils.py`** - Data sanitization utilities
- **`sync.py`** - Main sync orchestration

### **Testing**
- **`test_customer_sync.py`** - Test customer sync

### **Configuration**
- **`config.py`** - Configuration management

---

## 📚 **ESSENTIAL DOCUMENTATION**

### **Status & Readiness**
- **`PIPELINE_READINESS_ASSESSMENT.md`** - Final readiness status
- **`FINAL_REVIEW_STATUS.md`** - Complete file review summary
- **`WHAT_IS_LEFT_COMPREHENSIVE.md`** - Remaining work summary

### **Testing & Usage**
- **`TESTING_GUIDE.md`** - Step-by-step testing instructions
- **`TROUBLESHOOTING_GUIDE.md`** - Common errors and solutions (⚠️ READ THIS FIRST when errors occur)

### **Legacy Reference**
- **`legacy_docs/`** - Reference files (Address Guidelines, etc.)
- **`legacy_imports/`** - Import format examples

---

## 🔧 **USEFUL SCRIPTS (Keep)**

- **`test_network_share.ps1`** - Network share testing (may be useful later)

---

## 📋 **QUICK START**

### **First Time Setup:**
1. Run `staging_tables.sql` on database
2. Run `fix_missing_components.sql` if needed
3. Run `preflight_validation.sql` if needed

### **Testing:**
1. Use `MASTER_TEST_SCRIPT.sql` for complete testing
2. Use `test_customer_sync.py` for Python testing

### **Daily Operations:**
1. Keep `QUICK_REFERENCE_QUERIES.sql` open
2. Use `woo_customers.py` for customer sync
3. Use `woo_orders.py` for order staging

---

**All redundant files removed. Project is clean and organized!**


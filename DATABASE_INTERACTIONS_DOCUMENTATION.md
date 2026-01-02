# Database Interactions Documentation

**Date:** January 2, 2026  
**Purpose:** Document all direct SQL database interactions for maintenance and troubleshooting  
**Status:** 📋 **IN PROGRESS - Living Document**

---

## 🎯 **PURPOSE**

This document tracks **every direct SQL interaction** with the CounterPoint database to:
- Understand what tables/columns are used
- Identify schema dependencies
- Plan for CounterPoint updates
- Troubleshoot issues
- Plan potential NCR API migration

---

## 📋 **DOCUMENTATION TEMPLATE**

For each database interaction, document:

1. **Operation Name** - What this interaction does
2. **File/Function** - Where it's implemented
3. **Tables Used** - All tables accessed
4. **Columns Used** - Specific columns read/written
5. **Operations** - SELECT, INSERT, UPDATE, DELETE
6. **Dependencies** - Foreign keys, constraints, triggers
7. **Business Logic** - Any CounterPoint business rules implemented
8. **Risk Level** - High/Medium/Low if schema changes

---

## 📊 **DATABASE INTERACTIONS INVENTORY**

### **1. Order Processing**

#### **1.1 Order Staging (woo_orders.py)**
- **File:** `woo_orders.py` → `USER_ORDER_STAGING` table
- **Operations:** INSERT
- **Tables:**
  - `USER_ORDER_STAGING` (INSERT)
- **Columns Used:**
  - `STAGING_ID` (IDENTITY)
  - `WOO_ORDER_ID`
  - `WOO_ORDER_NO`
  - `CUST_NO`
  - `LINE_ITEMS_JSON`
  - `SUBTOT`, `TAX_AMT`, `SHIP_AMT`, `TOT_AMT`
  - `CREATED_DT`
  - `IS_APPLIED`
  - `VALIDATION_ERROR`
- **Dependencies:** None (staging table)
- **Risk Level:** 🟢 **LOW** (user table, not CounterPoint core)

#### **1.2 Order Validation (sp_ValidateStagedOrder)**
- **File:** `01_Production/sp_ValidateStagedOrder.sql`
- **Operations:** SELECT
- **Tables:**
  - `USER_ORDER_STAGING` (SELECT)
  - `AR_CUST` (SELECT) - Customer validation
  - `IM_ITEM` (SELECT) - Item validation
- **Columns Used:**
  - `AR_CUST.CUST_NO`, `AR_CUST.CUST_NAM`
  - `IM_ITEM.ITEM_NO`, `IM_ITEM.DESCR`
  - `USER_ORDER_STAGING.*`
- **Dependencies:**
  - Customer must exist in `AR_CUST`
  - Items must exist in `IM_ITEM`
- **Business Logic:**
  - Validates customer exists
  - Validates all items exist
  - Validates totals match
- **Risk Level:** 🟡 **MEDIUM** (depends on CounterPoint core tables)

#### **1.3 Order Header Creation (sp_CreateOrderFromStaging)**
- **File:** `01_Production/sp_CreateOrderFromStaging.sql`
- **Operations:** INSERT
- **Tables:**
  - `PS_DOC_HDR` (INSERT) - Order header
- **Columns Used:**
  - `DOC_ID` (IDENTITY)
  - `DOC_TYP` = 'O'
  - `TKT_NO`
  - `CUST_NO`
  - `TKT_DT`
  - `SUBTOT`, `TAX_AMT`, `SHIP_AMT`, `TOT_AMT`
  - `LOC_ID`
  - `SHIP_TO_ID`
  - `SHIP_VIA_COD`
  - `TAX_COD`
  - `SAL_REP`
  - `TERMS_COD`
- **Dependencies:**
  - Customer must exist (`AR_CUST`)
  - Location must exist
  - Tax code must exist
  - Terms code must exist
- **Business Logic:**
  - Generates `TKT_NO` (ticket number)
  - Sets order date
  - Calculates totals
- **Risk Level:** 🔴 **HIGH** (core CounterPoint order table)

#### **1.4 Order Line Items Creation (sp_CreateOrderLines)**
- **File:** `01_Production/sp_CreateOrderLines.sql`
- **Operations:** INSERT, UPDATE
- **Tables:**
  - `PS_DOC_LIN` (INSERT) - Order line items
  - `PS_DOC_HDR_TOT` (INSERT) - Order totals
  - `IM_INV` (UPDATE) - Inventory updates
- **Columns Used:**
  - `PS_DOC_LIN`: `DOC_ID`, `LIN_SEQ_NO`, `ITEM_NO`, `QTY_SOLD`, `UNIT_PRC`, `EXT_PRC`, `STK_LOC_ID`
  - `PS_DOC_HDR_TOT`: `DOC_ID`, `TOT_TYP`, `TOT_AMT`
  - `IM_INV`: `QTY_ON_SO` (UPDATE - increases by order quantity)
- **Dependencies:**
  - `PS_DOC_HDR` must exist (foreign key)
  - `IM_ITEM` must exist (item validation)
  - `IM_INV` must exist (inventory location)
- **Business Logic:**
  - Creates line items from JSON
  - Updates `QTY_ON_SO` (quantity on sales order)
  - Creates totals records
- **Risk Level:** 🔴 **HIGH** (core CounterPoint tables)

---

### **2. Customer Management**

#### **2.1 Customer Sync (woo_customers.py)**
- **File:** `woo_customers.py`
- **Operations:** INSERT, UPDATE, SELECT
- **Tables:**
  - `USER_CUSTOMER_STAGING` (INSERT) - Staging table
  - `AR_CUST` (SELECT, INSERT, UPDATE) - Customer master
  - `AR_SHP_TO` (INSERT) - Ship-to addresses
- **Columns Used:**
  - `AR_CUST`: `CUST_NO`, `CUST_NAM`, `ADRS_1`, `ADRS_2`, `CITY`, `STATE`, `ZIP_COD`, `PHONE_1`, `EMAIL_ADRS_1`
  - `AR_SHP_TO`: `CUST_NO`, `SHIP_TO_ID`, `SHIP_TO_NAM`, `ADRS_1`, `CITY`, `STATE`, `ZIP_COD`
- **Dependencies:**
  - Customer number generation
  - Address validation
- **Business Logic:**
  - Creates customers from WooCommerce
  - Handles duplicate emails
  - Creates ship-to addresses
- **Risk Level:** 🟡 **MEDIUM** (core customer tables)

---

### **3. Product & Inventory**

#### **3.1 Product Sync (woo_products.py)**
- **File:** `woo_products.py`
- **Operations:** SELECT
- **Tables:**
  - `VI_EXPORT_PRODUCTS` (SELECT) - Product view
  - `IM_ITEM` (SELECT) - Item master
  - `IM_INV` (SELECT) - Inventory
- **Columns Used:**
  - `VI_EXPORT_PRODUCTS`: `SKU`, `DESCR`, `PRICE`, `QTY_AVAIL`, etc.
  - `IM_ITEM`: `ITEM_NO`, `DESCR`, `SHORT_DESCR`
  - `IM_INV`: `QTY_ON_HND`, `QTY_AVAIL`
- **Dependencies:**
  - Product view must exist
- **Risk Level:** 🟡 **MEDIUM** (depends on view structure)

#### **3.2 Inventory Sync (woo_inventory_sync.py)**
- **File:** `woo_inventory_sync.py`
- **Operations:** SELECT
- **Tables:**
  - `IM_INV` (SELECT) - Inventory
  - `VI_INVENTORY_SYNC` (SELECT) - Inventory view
- **Columns Used:**
  - `IM_INV`: `ITEM_NO`, `LOC_ID`, `QTY_ON_HND`, `QTY_AVAIL`, `QTY_ON_SO`
  - `VI_INVENTORY_SYNC`: All inventory columns
- **Dependencies:**
  - Inventory view must exist
- **Risk Level:** 🟡 **MEDIUM** (depends on view structure)

---

### **4. Contract Pricing**

#### **4.1 Contract Price Calculation (woo_contract_pricing.py)**
- **File:** `woo_contract_pricing.py`
- **Operations:** SELECT
- **Tables:**
  - `IM_PRC_RUL` (SELECT) - Pricing rules
  - `AR_CUST` (SELECT) - Customer (for NCR BID)
  - `IM_ITEM` (SELECT) - Items
  - `VI_PRODUCT_NCR_TYPE` (SELECT) - NCR type view
- **Columns Used:**
  - `IM_PRC_RUL`: `GRP_COD`, `ITEM_FILT_TEXT`, `PRC_METH`, `PRC_AMT`, `DISC_PCT`
  - `AR_CUST`: `CUST_NO`, `GRP_COD` (NCR BID)
  - `IM_ITEM`: `ITEM_NO`, `BASE_PRC`
  - `VI_PRODUCT_NCR_TYPE`: `ITEM_NO`, `NCR_TYPE`
- **Dependencies:**
  - Pricing rules table
  - NCR type view
- **Business Logic:**
  - Complex pricing rule matching
  - NCR type extraction
  - Discount calculations
- **Risk Level:** 🟡 **MEDIUM** (pricing rules are complex)

---

## 🔍 **SCHEMA DEPENDENCIES SUMMARY**

### **Core CounterPoint Tables (HIGH RISK):**
- `PS_DOC_HDR` - Order headers
- `PS_DOC_LIN` - Order line items
- `PS_DOC_HDR_TOT` - Order totals
- `IM_INV` - Inventory (QTY_ON_SO updates)

### **Customer Tables (MEDIUM RISK):**
- `AR_CUST` - Customer master
- `AR_SHP_TO` - Ship-to addresses

### **Product Tables (MEDIUM RISK):**
- `IM_ITEM` - Item master
- `IM_PRC_RUL` - Pricing rules

### **User Tables (LOW RISK):**
- `USER_ORDER_STAGING` - Order staging
- `USER_CUSTOMER_STAGING` - Customer staging
- `USER_SYNC_LOG` - Sync logging

### **Views (MEDIUM RISK):**
- `VI_EXPORT_PRODUCTS` - Product export view
- `VI_INVENTORY_SYNC` - Inventory sync view
- `VI_PRODUCT_NCR_TYPE` - NCR type view
- `VI_EXPORT_CP_ORDERS` - CP orders view (for display plugin)

---

## 📝 **MAINTENANCE CHECKLIST**

### **When CounterPoint Updates:**
- [ ] Review NCR release notes for schema changes
- [ ] Test order creation (sp_CreateOrderFromStaging, sp_CreateOrderLines)
- [ ] Test customer sync (woo_customers.py)
- [ ] Test product sync (woo_products.py)
- [ ] Test inventory sync (woo_inventory_sync.py)
- [ ] Test contract pricing (woo_contract_pricing.py)
- [ ] Verify all views still work
- [ ] Check for new required columns
- [ ] Check for deprecated columns
- [ ] Update this documentation if schema changes

---

## 🔄 **UPDATE LOG**

| Date | CounterPoint Version | Changes Made | Tested By | Status |
|------|---------------------|--------------|-----------|--------|
| 2026-01-02 | Current | Initial documentation | - | ✅ Complete |

---

**Last Updated:** January 2, 2026  
**Status:** 📋 **LIVING DOCUMENT - Update after each CounterPoint update**

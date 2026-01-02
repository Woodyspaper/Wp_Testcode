# Phase 5: Order Creation - Implementation Plan

**Date:** December 31, 2025  
**Status:** Starting implementation  
**Purpose:** Create CounterPoint orders from staged WooCommerce orders

---

## 🎯 **OVERVIEW**

**Phase 5: Order Creation**
- Converts staged orders (`USER_ORDER_STAGING`) → CounterPoint sales tickets
- Creates `PS_DOC_HDR` (order header)
- Creates `PS_DOC_LIN` (order lines)
- Updates inventory when orders created
- Syncs order status back to WooCommerce

---

## 📋 **CURRENT STATE**

### **What Exists:**
- ✅ `USER_ORDER_STAGING` table (orders are being staged)
- ✅ `woo_orders.py` (pulls orders to staging)
- ✅ Order staging working

### **What's Needed:**
- ⏳ Stored procedure to create `PS_DOC_HDR`
- ⏳ Stored procedure to create `PS_DOC_LIN`
- ⏳ Python script to process staged orders
- ⏳ Inventory update logic
- ⏳ Order status sync back to WooCommerce
- ⏳ Scheduled job for order processing

---

## 🔧 **IMPLEMENTATION STEPS**

### **Step 1: Discover CounterPoint Order Tables**
- Discover `PS_DOC_HDR` columns
- Discover `PS_DOC_LIN` columns
- Understand required fields
- Understand document ID generation

### **Step 2: Create Validation Stored Procedure**
- Validate staged orders before processing
- Check customer exists
- Check products exist
- Check inventory availability
- Return validation results

### **Step 3: Create Order Header Stored Procedure**
- Create `PS_DOC_HDR` record
- Generate document ID
- Map staging fields to PS_DOC_HDR
- Handle required fields

### **Step 4: Create Order Lines Stored Procedure**
- Parse `LINE_ITEMS_JSON` from staging
- Create `PS_DOC_LIN` records
- Map line item fields
- Calculate line totals

### **Step 5: Create Inventory Update Logic**
- Update `IM_INV` when orders created
- Reduce stock quantities
- Handle backorders

### **Step 6: Create Python Processing Script**
- Process staged orders
- Call stored procedures
- Handle errors
- Update staging status
- Log to `USER_SYNC_LOG`

### **Step 7: Create Order Status Sync**
- Sync order status from CounterPoint → WooCommerce
- Update WooCommerce order status
- Handle status mappings

### **Step 8: Create Scheduled Job**
- Task Scheduler job for order processing
- Run every X minutes
- Monitor and log

---

## 📊 **DATA FLOW**

```
WooCommerce Order
    ↓
woo_orders.py (pull)
    ↓
USER_ORDER_STAGING (staged)
    ↓
Phase 5 Processing
    ↓
PS_DOC_HDR (order header)
    ↓
PS_DOC_LIN (order lines)
    ↓
IM_INV (inventory updated)
    ↓
WooCommerce (status synced)
```

---

## ⚠️ **REQUIREMENTS**

### **Required Fields:**
- Customer (`CUST_NO`) - Must exist in `AR_CUST`
- Products (`ITEM_NO`) - Must exist in `IM_ITEM`
- Document ID - Must be generated correctly
- Order date/time
- Totals (subtotal, tax, shipping, total)

### **Validation Rules:**
- Customer must exist
- Products must exist
- Inventory must be available (or handle backorder)
- Totals must match
- No duplicate orders

---

## 🔍 **SYNTAX & LOGIC CHECKS**

**New Rule:** Every script (Python, SQL, PowerShell) must have syntax and logic check after creation.

**Check Process:**
1. Syntax validation (compile/parse)
2. Logic review (flow, edge cases)
3. Error handling review
4. Test with sample data

---

**Last Updated:** December 31, 2025

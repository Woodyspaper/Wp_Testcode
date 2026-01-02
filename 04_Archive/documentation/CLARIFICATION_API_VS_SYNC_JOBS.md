# Clarification: API Service vs Sync Jobs

**Date:** December 30, 2025  
**Purpose:** Clarify the difference between API service and sync jobs

---

## 🔍 **TWO DIFFERENT THINGS**

### **1. API Service (NSSM/Waitress)** ✅ **ALREADY SET UP**

**What it is:**
- **Contract Pricing API** - Web service that runs 24/7
- WordPress calls this API **in real-time** when customers view products
- Returns contract prices instantly

**Technology:**
- **NSSM** - Runs Python API as Windows service
- **Waitress** - Production WSGI server (better than Flask dev server)
- **Service Name:** `ContractPricingAPIWaitress`

**Status:** ✅ **Already deployed and running**

**Why it's needed:**
- WordPress needs to call API **immediately** when customer views product
- Can't wait for scheduled sync - needs real-time pricing
- Must run 24/7 as a service

---

### **2. Sync Jobs (Task Scheduler)** ✅ **ALREADY SET UP (Customer), NEED ORDER SYNC**

**What it is:**
- **Batch sync scripts** - Run periodically to sync data
- Customer sync: Daily at 11:49 PM
- Order sync: Need to set up (every 5 minutes)

**Technology:**
- **Task Scheduler** - Windows scheduled tasks
- **PowerShell scripts** - `Run-WooCustomerSync.ps1`, `Run-WooOrderSync.ps1`
- **Python scripts** - `woo_customers.py`, `woo_orders.py`

**Status:**
- ✅ Customer sync: Working
- ⚠️ Order sync: Need to set up

**Why it's needed:**
- Syncs data between WooCommerce and CounterPoint
- Runs on schedule (not real-time)
- Processes batches of data

---

## 📊 **COMPARISON**

| Aspect | API Service (NSSM/Waitress) | Sync Jobs (Task Scheduler) |
|--------|----------------------------|---------------------------|
| **Purpose** | Real-time contract pricing | Batch data sync |
| **When it runs** | 24/7 (always running) | Scheduled (daily/5 min) |
| **Who calls it** | WordPress (in real-time) | Scheduled task |
| **Response time** | Instant (< 1 second) | Batch processing (minutes) |
| **Technology** | NSSM + Waitress | Task Scheduler + PowerShell |
| **Status** | ✅ Deployed | ✅ Customer sync working<br>⚠️ Order sync needed |

---

## ✅ **WHAT'S ALREADY DONE**

### **API Service:**
- ✅ NSSM installed
- ✅ Waitress installed
- ✅ Service created: `ContractPricingAPIWaitress`
- ✅ Running on port 5000
- ✅ WordPress plugin configured to call it
- ✅ **Working and tested**

### **Sync Jobs:**
- ✅ Customer sync: Task Scheduler job (daily at 11:49 PM)
- ✅ `Run-WooCustomerSync.ps1` script
- ✅ `run_woo_customer_batch.sql` driver
- ✅ **Working and tested**
- ⚠️ Order sync: Need to create Task Scheduler job

---

## 🎯 **WHAT WE NEED TO FOCUS ON**

### **Phase 3: Inventory Sync** ⚠️ **NOT IMPLEMENTED**

**What it does:**
- Syncs inventory levels from CounterPoint → WooCommerce
- Updates stock quantities in WooCommerce
- Runs periodically (every 5 minutes suggested)

**Status:** ❌ Not implemented yet

**How it works:**
- Query CounterPoint inventory (`IM_INV.QTY_ON_HND`)
- Update WooCommerce product stock levels
- Can use Task Scheduler (similar to customer/order sync)

---

### **Phase 5: Order Creation** ⚠️ **NOT IMPLEMENTED**

**What it does:**
- Creates orders in CounterPoint from staging table
- Creates sales tickets (`PS_DOC_HDR`, `PS_DOC_LIN`)
- Updates inventory when orders created
- Syncs payment information

**Status:** ❌ Not implemented yet

**Current state:**
- ✅ Orders are pulled from WooCommerce
- ✅ Orders are staged in `USER_ORDER_STAGING`
- ❌ Orders are NOT created in CounterPoint yet
- ❌ Sales tickets NOT created
- ❌ Inventory NOT updated

**What's needed:**
- Create stored procedure to process staged orders
- Create orders in `PS_DOC_HDR` and `PS_DOC_LIN`
- Update inventory (`IM_INV`)
- Handle payment information
- Can use Task Scheduler to run periodically

---

## 💡 **SUMMARY**

**NSSM/Waitress:**
- ✅ **Already set up and working**
- Used for **real-time API** (contract pricing)
- **NOT replaced by Task Scheduler** - they serve different purposes

**Task Scheduler:**
- ✅ Customer sync working
- ⚠️ Order sync needs to be set up
- Used for **batch sync jobs**

**What to focus on:**
1. **Phase 3:** Inventory sync (CounterPoint → WooCommerce)
2. **Phase 5:** Order creation (staging → CounterPoint sales tickets)

---

**Last Updated:** December 30, 2025

# WooCommerce to CounterPoint Order Processing Pipeline
## Complete Explanation for Richard

**Date:** January 2, 2026  
**Status:** ✅ **FULLY OPERATIONAL**

---

## 🎯 **WHAT THIS PIPELINE DOES**

**In Simple Terms:** This system automatically takes orders from your WooCommerce website and creates them in CounterPoint, so you don't have to manually enter orders.

**The Problem It Solves:**
- Before: Orders come in on the website → Someone has to manually enter them into CounterPoint
- After: Orders come in on the website → System automatically creates them in CounterPoint

---

## 📋 **THE COMPLETE FLOW (Step-by-Step)**

### **Step 1: Order Comes In on Website**
- Customer places order on WooCommerce website
- Order is stored in WordPress database
- Order status is "pending" or "processing"

### **Step 2: Order Gets Staged (Prepared)**
- A Python script runs periodically (every few hours) to check for new orders
- When it finds new orders, it copies them to a staging table (`USER_ORDER_STAGING`) in CounterPoint
- This staging table is like a "waiting room" - orders sit here until they're ready to be processed

**What Gets Staged:**
- Customer information (name, address, email)
- Order details (items, quantities, prices)
- Shipping information
- Tax and totals

### **Step 3: Order Validation**
- Before creating the order in CounterPoint, the system validates it:
  - Does the customer exist in CounterPoint?
  - Do all the items (SKUs) exist in CounterPoint?
  - Are the prices and totals correct?
  - Is all required information present?

**If validation fails:** Order stays in staging with an error message, and you get an email alert

**If validation passes:** Order moves to Step 4

### **Step 4: Order Creation in CounterPoint**
- System creates a Sales Ticket in CounterPoint (this is what CounterPoint calls an order)
- Creates the order header (`PS_DOC_HDR`) with:
  - Customer number
  - Order date
  - Order number (like "101-000003")
  - Totals
- Creates line items (`PS_DOC_LIN`) for each product:
  - Item number (SKU)
  - Quantity
  - Price
  - Extended price
- Creates order totals (`PS_DOC_HDR_TOT`):
  - Subtotal
  - Tax
  - Shipping
  - Grand total

### **Step 5: Inventory Update**
- When order is created, system updates inventory:
  - Reduces available quantity (`QTY_ON_SO` - Quantity on Sales Order)
  - This prevents overselling (shows items as "allocated" to this order)

### **Step 6: Status Sync Back to Website**
- System updates the WooCommerce order status to "processing"
- Adds a note to the order showing:
  - CounterPoint Document ID (DOC_ID)
  - CounterPoint Ticket Number (TKT_NO)
- This lets you track which CounterPoint order matches which website order

### **Step 7: Order Marked as Complete**
- Staging record is marked as "applied" (IS_APPLIED = 1)
- Order won't be processed again
- System moves on to next order

---

## ⚙️ **HOW IT RUNS AUTOMATICALLY**

### **Smart Scheduling System**

The system uses "smart check" logic:

**Every 30 Minutes:**
- Task Scheduler runs a check
- System looks for pending orders in staging
- **If orders are pending:** Processes them immediately ✅
- **If no orders:** Skips processing (saves resources) ✅
- **If no orders for 2-3 hours:** Runs a periodic check anyway (safety net) ✅

**Why This is Smart:**
- Doesn't waste resources checking when there's nothing to do
- Processes orders quickly when they arrive
- Still checks periodically even if no orders (catches any missed orders)

---

## 🔧 **KEY COMPONENTS**

### **1. Database Tables**

**`USER_ORDER_STAGING`** - The "waiting room"
- Holds orders before they're processed
- Shows validation status
- Tracks errors if something goes wrong

**`PS_DOC_HDR`** - CounterPoint order header
- Created when order is processed
- Contains order number, customer, date, totals

**`PS_DOC_LIN`** - CounterPoint order line items
- Created for each product in the order
- Contains SKU, quantity, price

**`IM_INV`** - Inventory table
- Updated when orders are created
- Tracks available quantities

### **2. Stored Procedures (SQL Functions)**

**`sp_ValidateStagedOrder`**
- Validates order before processing
- Checks customer, items, prices
- Returns validation errors if found

**`sp_CreateOrderFromStaging`**
- Creates the order header in CounterPoint
- Generates order number
- Returns the Document ID

**`sp_CreateOrderLines`**
- Creates line items for the order
- Updates inventory quantities
- Handles pricing and calculations

### **3. Python Scripts**

**`woo_orders.py`** - Pulls orders from WooCommerce
- Connects to WordPress database
- Finds new orders
- Copies them to staging table

**`cp_order_processor.py`** - Processes staged orders
- Validates orders
- Creates orders in CounterPoint
- Syncs status back to WooCommerce
- Handles errors and retries

**`check_order_processing_needed.py`** - Smart check logic
- Decides if processing is needed
- Checks for pending orders
- Determines if periodic check is due

### **4. Task Scheduler Jobs**

**Windows Task Scheduler** runs these automatically:
- **Order Staging:** Pulls new orders from WooCommerce (runs periodically)
- **Order Processing:** Processes staged orders (runs every 30 minutes, smart check)

---

## 📧 **MONITORING & ALERTS**

### **Email Alerts**

You (michaelbryan@woodyspaper.com) receive emails when:

**Critical Issues:**
- Order processing fails completely
- Script crashes
- System detects critical problems

**Warnings:**
- Orders processed with some failures
- Orders pending for too long (> 2 hours)
- Health check detects issues

### **Health Check**

A script (`check_order_processing_health.py`) monitors:
- How many orders are pending
- How long orders have been waiting
- When orders were last processed successfully
- Recent errors

**Status Levels:**
- ✅ **Healthy** - Everything working
- ⚠️ **Warning** - Minor issues, but functional
- ❌ **Critical** - Major issues, needs attention

---

## 🛡️ **ERROR HANDLING & SAFETY**

### **What Happens When Something Goes Wrong?**

**1. Validation Errors:**
- Order stays in staging
- Error message is recorded
- Email alert is sent
- Order can be fixed and retried

**2. Processing Failures:**
- System retries up to 3 times
- Waits longer between each retry (exponential backoff)
- If all retries fail, order stays in staging
- Email alert is sent

**3. Database Errors:**
- Transaction is rolled back (nothing is saved)
- Order stays in staging
- Error is logged
- Email alert is sent

### **Dead Letter Queue**

Orders that permanently fail are isolated:
- Can be reviewed manually
- Can be fixed and retried
- Can be cancelled if needed
- SQL query available to find them: `FIND_FAILED_ORDERS.sql`

---

## 🔄 **ROLLBACK PROCEDURES**

If an order is created incorrectly, you can roll it back:

**Steps:**
1. Identify the order (DOC_ID, TKT_NO)
2. Check inventory impact
3. Reverse inventory updates
4. Delete order from CounterPoint
5. Reset staging record
6. Revert WooCommerce status (if needed)

**Full instructions:** `ROLLBACK_PROCEDURES.md`

**⚠️ Important:** Only rollback if order was just created and hasn't been shipped/invoiced

---

## 📊 **WHAT YOU'LL SEE**

### **In CounterPoint:**
- New Sales Tickets appear automatically
- Order numbers like "101-000003", "101-000004", etc.
- Customer information matches website
- Line items match website order
- Inventory quantities updated

### **In WooCommerce:**
- Order status changes to "processing"
- Order notes show CounterPoint order number
- You can track which CounterPoint order matches which website order

### **In Logs:**
- Processing logs in `logs/woo_order_processing_*.log`
- Shows what was processed
- Shows any errors
- Shows processing times

---

## ✅ **WHAT'S BEEN SET UP**

### **Core Functionality:**
✅ Order staging from WooCommerce  
✅ Order validation  
✅ Order creation in CounterPoint  
✅ Inventory updates  
✅ Status sync back to WooCommerce  
✅ Retry logic (3 attempts)  
✅ Automated processing (Task Scheduler)

### **Error Handling:**
✅ SQL error handling (TRY/CATCH)  
✅ Python exception handling  
✅ Retry logic for transient failures  
✅ Error messages stored in staging table

### **Monitoring:**
✅ Email alerts configured (michaelbryan@woodyspaper.com)  
✅ Health check script  
✅ Logging to files  
✅ SQL queries for monitoring

### **Operations:**
✅ Rollback procedures documented  
✅ Dead letter queue process  
✅ Operations runbook  
✅ Troubleshooting guides

---

## 🎯 **BOTTOM LINE**

**What It Does:**
- Automatically creates CounterPoint orders from WooCommerce orders
- Updates inventory when orders are created
- Syncs status back to website
- Sends alerts when something goes wrong

**How It Works:**
- Orders come in → Staged in CounterPoint → Validated → Created in CounterPoint → Status synced back
- Runs automatically every 30 minutes (smart check)
- Processes immediately when orders are pending
- Skips when no orders (efficient)

**What You Need to Do:**
- Monitor email alerts (michaelbryan@woodyspaper.com)
- Review failed orders occasionally (dead letter queue)
- Check health status periodically
- Rollback orders if needed (rare)

**What Happens Automatically:**
- Order staging
- Order processing
- Inventory updates
- Status syncing
- Error handling
- Retries
- Alerts

---

## 📞 **IF SOMETHING GOES WRONG**

**Check These First:**
1. Email alerts (michaelbryan@woodyspaper.com)
2. Health check: `python check_order_processing_health.py`
3. Failed orders: `python cp_order_processor.py list`
4. Logs: `logs/woo_order_processing_*.log`

**Common Issues:**
- **Orders not processing:** Check Task Scheduler is running
- **Validation errors:** Check customer/item exists in CounterPoint
- **Email not sending:** Check SMTP server settings
- **Orders stuck:** Check dead letter queue

**Full troubleshooting:** See `OPERATIONS_RUNBOOK.md`

---

## 📈 **PERFORMANCE**

**Processing Speed:**
- Orders process within 30 minutes of arrival (usually faster)
- Validation takes seconds
- Order creation takes seconds
- Status sync takes seconds

**System Load:**
- Minimal - only runs when needed
- Smart check skips when no orders
- Efficient database queries
- No impact on website performance

---

## 🔒 **SAFETY & RELIABILITY**

**Data Safety:**
- All operations use database transactions (rollback on error)
- No data loss if something fails
- Orders stay in staging until successfully processed
- Inventory only updated when order is successfully created

**Reliability:**
- Retry logic handles transient failures
- Error handling prevents crashes
- Logging tracks everything
- Alerts notify you of issues

**Recovery:**
- Failed orders can be retried
- Orders can be rolled back if needed
- System recovers automatically from most errors

---

## 📝 **SUMMARY FOR RICHARD**

**The System:**
- Automatically creates CounterPoint orders from WooCommerce orders
- Runs every 30 minutes (processes immediately when orders arrive)
- Updates inventory automatically
- Syncs status back to website
- Sends email alerts when something goes wrong

**What You Get:**
- No manual order entry needed
- Orders appear in CounterPoint automatically
- Inventory stays accurate
- Website orders tracked in CounterPoint
- Alerts when issues occur

**What to Monitor:**
- Email alerts (michaelbryan@woodyspaper.com)
- Occasional health check
- Review failed orders if any

**Status:**
✅ **FULLY OPERATIONAL AND PRODUCTION READY**

---

**Last Updated:** January 2, 2026  
**Prepared For:** Richard  
**Status:** ✅ **READY FOR PRODUCTION USE**

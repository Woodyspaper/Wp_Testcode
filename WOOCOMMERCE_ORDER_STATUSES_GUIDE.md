# WooCommerce Order Statuses Guide
**Complete Explanation: What Each Status Means & How Our System Handles Them**

**Date:** January 5, 2026

---

## 📋 **WOOCOMMERCE ORDER STATUSES EXPLAINED**

### **1. Pending Payment** ❌
**Meaning:** Order placed but payment not yet received

**When It Happens:**
- Customer places order but payment gateway hasn't processed payment yet
- Payment is pending authorization
- Order is waiting for payment confirmation

**What We Do:**
- ❌ **We DON'T pull these orders** (not paid yet)
- Order stays in WooCommerce until payment is processed

**What Happens Next:**
- Payment gateway processes payment → Status changes to "Processing"
- Payment fails → Status changes to "Failed"
- Customer cancels → Status changes to "Cancelled"

---

### **2. Processing** ✅
**Meaning:** Payment successful, order is being processed/fulfilled

**When It Happens:**
- Payment gateway successfully processes payment
- Order is paid and ready for fulfillment
- This is the **default status after successful payment**

**What We Do:**
- ✅ **We DO pull these orders** (they're paid)
- Order is staged and created in CounterPoint
- Status remains "Processing" after CounterPoint creation

**What Happens Next:**
- Order is fulfilled/shipped → Status can change to "Completed" (manual or automatic)
- Order stays "Processing" until fulfillment is complete

---

### **3. Completed** ✅
**Meaning:** Order is fully fulfilled and shipped

**When It Happens:**
- Order has been shipped/delivered
- All items have been fulfilled
- Customer has received the order

**What We Do:**
- ✅ **We DO pull these orders** (they're paid and fulfilled)
- Order is staged and created in CounterPoint
- Status remains "Completed" after CounterPoint creation

**Note:** "Completed" is about **fulfillment**, not just payment. An order can be "Processing" (paid but not shipped) or "Completed" (paid and shipped).

---

### **4. Failed** ❌
**Meaning:** Payment failed or was declined

**When It Happens:**
- Payment gateway declines the payment
- Credit card is declined
- Payment processing error occurs

**What We Do:**
- ❌ **We DON'T pull these orders** (payment failed)
- Order stays in WooCommerce with "Failed" status
- Customer needs to update payment method or order is cancelled

**What Happens Next:**
- Customer can retry payment → Status changes to "Processing" if successful
- Order can be cancelled → Status changes to "Cancelled"

---

### **5. Refunded** ❌
**Meaning:** Order was refunded to customer

**When It Happens:**
- Full or partial refund was issued
- Customer requested refund
- Order was cancelled after payment

**What We Do:**
- ❌ **We DON'T pull these orders** (refunded orders shouldn't be in CounterPoint)
- If order was already in CounterPoint, it should be handled separately (rollback)

**Important:** If an order was already created in CounterPoint and then refunded, you may need to rollback the CounterPoint order.

---

### **6. Cancelled** ❌
**Meaning:** Order was cancelled before or after payment

**When It Happens:**
- Customer cancels order
- Order is cancelled by admin
- Payment fails and order is cancelled

**What We Do:**
- ❌ **We DON'T pull these orders** (cancelled orders shouldn't be in CounterPoint)

---

## 🔄 **HOW STATUS CHANGES WORK**

### **Automatic Status Changes:**

**Payment Flow:**
1. **Pending Payment** → Customer places order
2. **Processing** → Payment gateway processes payment successfully
3. **Completed** → Order is fulfilled/shipped (can be automatic or manual)

**Failure Flow:**
1. **Pending Payment** → Customer places order
2. **Failed** → Payment gateway declines payment
3. **Cancelled** → Order is cancelled (optional)

### **Manual Status Changes:**

**In WordPress Admin:**
- Go to **Orders** → Select order
- Click **Order actions** dropdown
- Select new status (e.g., "Completed")
- Click **Update**

**When to Manually Change to "Completed":**
- Order has been shipped
- All items have been fulfilled
- Customer has received the order
- You want to mark order as fully complete

---

## ✅ **WHAT OUR SYSTEM PULLS**

### **Current Configuration:**

**We Only Pull:**
- ✅ **"Processing"** - Paid orders being processed
- ✅ **"Completed"** - Paid orders that are fulfilled

**We DON'T Pull:**
- ❌ **"Pending Payment"** - Not paid yet
- ❌ **"Failed"** - Payment failed
- ❌ **"Refunded"** - Order was refunded
- ❌ **"Cancelled"** - Order was cancelled

**Code Location:**
```python
# In woo_orders.py, line 460:
'status': 'processing,completed',  # Only paid orders
```

---

## 🎯 **HOW TO CHANGE STATUS TO "COMPLETED"**

### **Method 1: Manual Change in WordPress Admin**

1. Go to **WordPress Admin** → **WooCommerce** → **Orders**
2. Find the order you want to mark as completed
3. Click on the order to open it
4. In the **Order actions** panel (right side):
   - Select **"Change status to Completed"** from dropdown
   - Click **Update**
5. Order status changes to "Completed"

### **Method 2: Automatic (If Configured)**

**WooCommerce can automatically change status to "Completed" when:**
- All items are marked as "Shipped"
- Shipping plugin marks order as fulfilled
- Order fulfillment is complete

**Check Settings:**
- WooCommerce → Settings → Orders
- Look for "Order status" or "Fulfillment" settings

### **Method 3: Via API (Programmatic)**

**You can create a script to change status:**
```python
from woo_client import WooClient

client = WooClient()
client.update_order_status(
    order_id=15487,
    status='completed',
    note='Order fulfilled and shipped'
)
```

---

## ❓ **FREQUENTLY ASKED QUESTIONS**

### **Q: Does "Completed" only happen when it's paid?**

**A:** No. "Completed" means the order is **both paid AND fulfilled**.

**Status Flow:**
- **Pending Payment** → Not paid
- **Processing** → Paid, but not yet fulfilled
- **Completed** → Paid AND fulfilled/shipped

**So:**
- ✅ Payment is required for "Completed" (order must be paid first)
- ✅ But payment alone doesn't make it "Completed" (must also be fulfilled)

### **Q: What's the difference between "Processing" and "Completed"?**

**A:**
- **"Processing"** = Payment successful, order being prepared/shipped
- **"Completed"** = Payment successful, order has been shipped/delivered

**In Practice:**
- Order is "Processing" when payment is received and you're preparing the order
- Order becomes "Completed" when you've shipped it and customer receives it

### **Q: Should I change orders to "Completed" after creating them in CounterPoint?**

**A:** No, not immediately. Here's why:

**Recommended Flow:**
1. Order is paid → Status: "Processing"
2. Order is pulled into CounterPoint → Status stays "Processing"
3. Order is fulfilled/shipped → Status changes to "Completed"

**When to Change to "Completed":**
- ✅ After order has been shipped
- ✅ After customer has received the order
- ✅ When fulfillment is complete
- ❌ NOT just because it's in CounterPoint

### **Q: What happens to "Failed" or "Refunded" orders?**

**A:**
- **Failed orders:** Stay in WooCommerce, not pulled into CounterPoint
- **Refunded orders:** Stay in WooCommerce, not pulled into CounterPoint
- **If order was already in CounterPoint and then refunded:** You may need to rollback the CounterPoint order

### **Q: Can I pull "Failed" orders to see what went wrong?**

**A:** Currently no, but you could modify the code:

**Current code (woo_orders.py line 460):**
```python
'status': 'processing,completed',  # Only paid orders
```

**To also pull failed orders (for analysis):**
```python
'status': 'processing,completed,failed',  # Include failed orders
```

**Note:** Failed orders won't be processed into CounterPoint (they're not paid), but you could stage them for analysis.

---

## 📊 **STATUS SUMMARY TABLE**

| Status | Payment Status | Fulfillment Status | Pulled to CP? | When to Use |
|--------|---------------|-------------------|---------------|-------------|
| **Pending Payment** | ❌ Not paid | ❌ Not fulfilled | ❌ No | Waiting for payment |
| **Processing** | ✅ Paid | ⏳ Being fulfilled | ✅ Yes | Payment received, preparing order |
| **Completed** | ✅ Paid | ✅ Fulfilled | ✅ Yes | Order shipped/delivered |
| **Failed** | ❌ Payment failed | ❌ Not fulfilled | ❌ No | Payment declined |
| **Refunded** | ⚠️ Refunded | ❌ Not fulfilled | ❌ No | Order refunded |
| **Cancelled** | ❌ Cancelled | ❌ Not fulfilled | ❌ No | Order cancelled |

---

## 🎯 **BEST PRACTICES**

### **Order Status Workflow:**

1. **Customer Places Order**
   - Status: "Pending Payment"
   - Action: Wait for payment

2. **Payment Processed**
   - Status: "Processing" (automatic)
   - Action: Order is pulled into CounterPoint
   - Action: Prepare order for shipping

3. **Order Shipped**
   - Status: "Completed" (manual or automatic)
   - Action: Mark as completed in WooCommerce

### **What NOT to Do:**

❌ Don't change status to "Completed" just because order is in CounterPoint  
❌ Don't pull "Failed" or "Refunded" orders (they're not paid)  
❌ Don't manually change status to "Processing" (payment gateway does this)

### **What TO Do:**

✅ Let payment gateway set status to "Processing" automatically  
✅ Change to "Completed" only after order is shipped  
✅ Monitor "Failed" orders separately (they won't be in CounterPoint)  
✅ Handle refunds separately (may need CounterPoint rollback)

---

## 🔧 **CURRENT SYSTEM BEHAVIOR**

### **What Happens When Order is Created in CounterPoint:**

**Current Behavior:**
- Order status in WooCommerce stays "Processing"
- CounterPoint note is added: "Order created in CounterPoint. DOC_ID: X, TKT_NO: Y"
- Status does NOT automatically change to "Completed"

**Why:**
- "Processing" is correct - order is being processed
- "Completed" should only happen after fulfillment
- We don't automatically change status (you control when it's fulfilled)

### **If You Want to Auto-Complete After CounterPoint Creation:**

**You could modify `cp_order_processor.py`:**
```python
# In sync_order_status_to_woocommerce function:
# Change from:
status='processing',
# To:
status='completed',
```

**⚠️ Warning:** This would mark orders as "Completed" immediately after CounterPoint creation, even if they haven't been shipped yet. Not recommended unless you want all CounterPoint orders to be marked as fulfilled immediately.

---

## 📝 **SUMMARY**

### **Status Meanings:**
- **Pending Payment** = Waiting for payment
- **Processing** = Paid, being fulfilled ✅ (We pull these)
- **Completed** = Paid AND fulfilled ✅ (We pull these)
- **Failed** = Payment failed ❌ (We don't pull)
- **Refunded** = Order refunded ❌ (We don't pull)
- **Cancelled** = Order cancelled ❌ (We don't pull)

### **When Status Changes to "Completed":**
- ✅ After order is shipped/delivered
- ✅ After fulfillment is complete
- ✅ Manually in WordPress admin
- ❌ NOT automatically when order is created in CounterPoint

### **Our System:**
- ✅ Pulls "Processing" and "Completed" orders (both are paid)
- ✅ Keeps status as "Processing" after CounterPoint creation
- ✅ Lets you manually change to "Completed" when order is fulfilled

---

**Last Updated:** January 5, 2026

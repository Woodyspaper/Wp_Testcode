# Why tim@northshoreprinting.com Was Flagged as Spam

**Date:** January 2, 2026  
**Customer:** tim@northshoreprinting.com (ID 425)

---

## 🔍 **SPAM DETECTION CRITERIA**

Based on the spam detection logic in `cleanup_spam_registrations.py`, a customer is flagged as spam if they match **ANY** of these criteria:

### **1. Missing Company Name, Phone, AND Address**
- **Condition:** No company name AND no phone AND no address
- **Logic:** If all three are missing, it's likely a bot
- **Code:** Lines 79-88

### **2. Missing Phone AND Address**
- **Condition:** No phone AND no address (even if company exists)
- **Logic:** Legitimate B2B customers usually have at least phone or address
- **Code:** Lines 90-97

### **3. Missing Address AND No Orders**
- **Condition:** No address AND zero orders placed
- **Logic:** Customers who register but never order and have no address are suspicious
- **Code:** Lines 99-107

### **4. No Orders AND Missing Company/Phone**
- **Condition:** Zero orders AND no company AND no phone
- **Logic:** Legitimate customers usually have company or phone even if they haven't ordered yet
- **Code:** Lines 109-119

### **5. Recent Registration with No Orders**
- **Condition:** Registered within last 30 days AND zero orders
- **Logic:** Recent registrations with no activity are suspicious
- **Code:** Lines 141-153

### **6. Username Matches Email**
- **Condition:** Username is the same as email local part (e.g., username "tim" matches email "tim@...")
- **Logic:** Common bot pattern - bots often use email as username
- **Code:** Lines 133-137

---

## 📋 **MOST LIKELY REASONS FOR tim@northshoreprinting.com**

Based on the spam detection logic, `tim@northshoreprinting.com` was likely flagged because:

### **Most Likely: Missing Address AND No Orders**
- ✅ Has email (tim@northshoreprinting.com)
- ❌ **Missing address** (billing or shipping)
- ❌ **No orders placed**
- **Result:** Flagged as spam

### **Alternative: Missing Phone AND Address**
- ✅ Has email
- ❌ **Missing phone number**
- ❌ **Missing address**
- **Result:** Flagged as spam

### **Alternative: Recent Registration with No Orders**
- ✅ Has email
- ❌ **Registered recently (within 30 days)**
- ❌ **No orders placed**
- **Result:** Flagged as spam

### **Alternative: Username Matches Email**
- ✅ Has email
- ⚠️ **Username is "tim" (matches email local part)**
- **Result:** Flagged as spam (bot pattern)

---

## ✅ **WHAT'S MISSING?**

To **NOT** be flagged as spam, a customer needs:

1. **At least ONE of these:**
   - Company name (billing or shipping)
   - Phone number (billing or shipping)
   - Address (billing or shipping)

2. **OR:**
   - At least one order placed

3. **AND:**
   - Username should be different from email local part (if possible)

---

## 🔧 **HOW TO FIX**

If `tim@northshoreprinting.com` is a legitimate customer:

1. **Add missing information:**
   - Add company name (if B2B)
   - Add phone number
   - Add billing/shipping address

2. **Or place a test order:**
   - Having at least one order removes the "no orders" flag

3. **Update username:**
   - Change username to something other than "tim" (if username matches email)

---

## 📊 **CURRENT STATUS**

- ✅ **Excluded from spam detection** - Added to `EXCLUDE_FROM_SPAM` list
- ⚠️ **Verify before deleting** - May be legitimate customer
- **Action:** Check customer record in WordPress Admin to see what's missing

---

## 💡 **NOTE**

The spam detection is designed to catch bots that register with minimal information. Legitimate customers who register but haven't completed their profile or placed an order yet might be flagged. That's why we:

1. Exclude known legitimate customers
2. Require multiple missing fields (not just one)
3. Check for orders (customers with orders are less likely to be spam)

---

**Last Updated:** January 2, 2026  
**Status:** ✅ **Excluded from spam detection - Verify if legitimate**

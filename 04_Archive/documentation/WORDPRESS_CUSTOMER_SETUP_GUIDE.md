# WordPress Customer NCR BID NO Setup Guide

**Date:** December 30, 2025  
**Status:** CRITICAL - Required for contract pricing to work

---

## ⚠️ **IMPORTANT: CUSTOMER SETUP**

**Contract pricing only applies to customers with NCR BID #**

The WordPress plugin requires customers to have an `ncr_bid_no` user meta field to receive contract pricing. **Not all customers need this** - only:
1. Customers who already have a contract in CounterPoint (NCR is source of truth)
2. Customers that Richard manually assigns a BID number to

**Customers without `ncr_bid_no` will see regular WooCommerce prices** (this is correct behavior).

---

## 🔍 **HOW IT WORKS**

**WordPress Plugin Logic:**
```php
$user_id = get_current_user_id();
$ncr_bid = wp_get_customer_ncr_bid($user_id);

if (!$ncr_bid) {
    return $price;  // Falls back to regular price
}
```

**The plugin calls:**
```php
function wp_get_customer_ncr_bid($user_id) {
    return get_user_meta($user_id, 'ncr_bid_no', true);
}
```

**If customer doesn't have `ncr_bid_no` meta field:**
- Plugin returns `null`
- Falls back to regular WooCommerce price
- **This is correct behavior** - only contract customers get contract pricing

---

## ✅ **SOLUTION: ADD NCR BID NO TO CUSTOMERS**

### **Method 1: Manual (One Customer at a Time)**

**IMPORTANT:** Only add `ncr_bid_no` to customers who:
- Already have a contract in CounterPoint, OR
- Richard has manually approved for contract pricing

**In WordPress Admin:**

1. Go to **Users** → **All Users**
2. Find the customer account
3. Click **Edit**
4. Scroll to **Custom Fields** section (may need to enable in Screen Options)
5. Add new custom field:
   - **Name:** `ncr_bid_no`
   - **Value:** `144319` (or customer's actual NCR BID # from CounterPoint)
6. Click **Update User**

**Note:** If customer doesn't have a contract in CounterPoint, do NOT add `ncr_bid_no` - they should see regular prices.

**Or use WordPress functions (add to functions.php or plugin):**
```php
// Add NCR BID NO to a customer
$user_id = 123; // Customer user ID
$ncr_bid_no = '144319'; // From CounterPoint
update_user_meta($user_id, 'ncr_bid_no', $ncr_bid_no);
```

---

### **Method 2: Bulk Import (Multiple Customers)**

**Option A: Use WordPress Import/Export**
1. Export customers to CSV
2. Add `ncr_bid_no` column
3. Map CounterPoint NCR BID #s to WordPress customers
4. Import back to WordPress

**Option B: Use SQL (Direct Database)**
```sql
-- In WordPress database (wp_users table)
-- Update customer meta with NCR BID NO
INSERT INTO wp_usermeta (user_id, meta_key, meta_value)
VALUES (123, 'ncr_bid_no', '144319')
ON DUPLICATE KEY UPDATE meta_value = '144319';
```

**Option C: Use WooCommerce Customer Sync Script**
- Create script to sync from CounterPoint
- Map CounterPoint CUST_NO to WordPress user
- Add NCR BID NO automatically

---

### **Method 3: Automated Sync (Recommended for Production)**

**IMPORTANT:** Only sync customers who have contracts in CounterPoint (NCR is source of truth).

**Create a sync script that:**

1. **Gets customers from CounterPoint who have contracts:**
   ```sql
   -- In CounterPoint database
   -- Get customers with contract groups (GRP_COD)
   SELECT DISTINCT
       c.CUST_NO,
       r.GRP_COD AS NCR_BID_NO,  -- Use GRP_COD as NCR BID NO
       c.NAM,
       c.EMAIL_ADRS_1
   FROM dbo.AR_CUST c
   INNER JOIN dbo.IM_PRC_RUL r ON c.GRP_COD = r.GRP_COD
   WHERE r.GRP_TYP = 'C'  -- Contract type
     AND r.GRP_COD IS NOT NULL
     AND r.GRP_COD != '';
   ```

2. **Maps to WordPress customers:**
   - Match by email address
   - Or match by customer number (if stored in WordPress)
   - Or match by name

3. **Updates WordPress user meta:**
   ```php
   // For each customer with contract
   $user = get_user_by('email', $customer_email);
   if ($user) {
       update_user_meta($user->ID, 'ncr_bid_no', $ncr_bid_no);
   }
   ```

**Note:** Only customers with contracts in CounterPoint should get `ncr_bid_no` in WordPress.

---

## 🔍 **HOW TO GET NCR BID NO FROM COUNTERPOINT**

**Since AR_CUST doesn't have NCR_BID_NO column, use GRP_COD:**

```sql
-- Get customer's contract group (use as NCR BID NO)
SELECT 
    c.CUST_NO,
    c.NAM,
    r.GRP_COD AS NCR_BID_NO  -- Use GRP_COD as NCR BID NO
FROM dbo.AR_CUST c
INNER JOIN dbo.IM_PRC_RUL r ON c.GRP_COD = r.GRP_COD
WHERE r.GRP_TYP = 'C'  -- Contract type
GROUP BY c.CUST_NO, c.NAM, r.GRP_COD;
```

**Or if customers are in contract groups:**
```sql
-- Find which contract group customer belongs to
-- This depends on how CounterPoint links customers to contract groups
-- May need to check CounterPoint documentation or customer setup
```

---

## 🧪 **TESTING CUSTOMER SETUP**

**After adding NCR BID NO to a customer:**

1. **Log in as that customer in WordPress**
2. **View a product page**
3. **Check if contract price displays:**
   - Should see contract price (if product has contract pricing)
   - Should see regular price crossed out (if contract pricing applied)
   - Should see discount percentage

4. **Add product to cart**
5. **Check cart total**
6. **Verify contract pricing is applied**

---

## 📋 **CUSTOMER SETUP CHECKLIST**

- [ ] Identify contract customers in CounterPoint (customers with contracts)
- [ ] Get their NCR BID # (or GRP_COD from contract rules)
- [ ] Match to WordPress customer accounts
- [ ] Add `ncr_bid_no` meta field **ONLY** to contract customers
- [ ] **Do NOT add to customers without contracts** (they should see regular prices)
- [ ] Test with at least one contract customer
- [ ] Verify contract pricing displays correctly
- [ ] Test cart and checkout
- [ ] Verify non-contract customers see regular prices (correct behavior)

---

## 🔧 **TROUBLESHOOTING**

**Customer not seeing contract prices:**

1. **Check if customer has NCR BID NO:**
   ```php
   // In WordPress
   $user_id = get_current_user_id();
   $ncr_bid = get_user_meta($user_id, 'ncr_bid_no', true);
   var_dump($ncr_bid);  // Should show NCR BID #, not empty
   ```

2. **Check if product has contract pricing:**
   - Test API directly with customer's NCR BID NO
   - Verify product has matching contract rule

3. **Check WordPress error log:**
   - Look for API errors
   - Check if API is reachable

4. **Check API logs:**
   - Verify requests are coming from WordPress
   - Check for errors in API response

---

## 🎯 **PRIORITY ACTIONS**

**Before going live:**

1. **CRITICAL:** Identify contract customers in CounterPoint
2. **CRITICAL:** Set up at least 5-10 contract customers with NCR BID NO in WordPress
3. **CRITICAL:** Test contract pricing with these customers
4. **IMPORTANT:** Verify non-contract customers see regular prices (correct behavior)
5. **IMPORTANT:** Create process for adding NCR BID NO to new contract customers
6. **IMPORTANT:** Document customer setup procedure
7. **RECOMMENDED:** Create automated sync script (only syncs contract customers)

---

**Last Updated:** December 30, 2025

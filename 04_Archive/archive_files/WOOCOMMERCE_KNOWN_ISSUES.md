# WooCommerce Known Issues, Quirks & Gotchas

**Last Updated:** December 2024  
**Purpose:** Reference guide for Woody's Paper integration to prevent and handle known WooCommerce issues.

---

## 🔴 CRITICAL ISSUES (Will Break Your Integration)

### 1. Customer List API Doesn't Return All Customers
**Status:** ✅ FIXED IN OUR CODE  
**Impact:** HIGH  

**Problem:** The `/customers` endpoint may not return all customers. We discovered this with Customer 480 (Minuteman Press).

**Causes:**
- Customers created during checkout may not be indexed
- Customers with special plugins (tax exempt, B2BKing) may be excluded
- Customers with non-standard roles won't appear unless `role=all` is specified
- WordPress caching can cause stale data

**OUR FIX (implemented in woo_customers.py and export_woo_customers.py):**
```python
# 1. Use role=all to get ALL roles
params = {"per_page": 100, "role": "all"}

# 2. ALSO scan orders for missing customers
for order in orders:
    customer_id = order.get('customer_id', 0)
    if customer_id > 0 and customer_id not in customers:
        # Fetch directly by ID
        customer = fetch_customer_by_id(customer_id)
        
# 3. Capture guest checkouts as pseudo-customers
    if customer_id == 0:  # Guest
        create_pseudo_customer_from_billing(order)
```

**Result:** Our `get_existing_woo_customers_full()` function now captures:
- ✅ All registered customers (any role)
- ✅ Customers created during checkout (not indexed)
- ✅ Guest checkout customers (from order billing data)

---

### 2. Guest Checkout Creates Orders Without Customer Records
**Status:** ACTIVE  
**Impact:** HIGH  

**Problem:** When a customer places an order without creating an account, their data exists ONLY in the order - not in the customer list.

**Detection:**
```python
order = get_order(15479)
if order['customer_id'] == 0:
    # This is a guest checkout
    # Customer data is in order['billing'] and order['shipping']
```

**Our Solution:** The staging table and stored procedure handle this:
- `WOO_USER_ID = NULL` indicates guest checkout
- Customer still created in CounterPoint
- No WooCommerce mapping created (since no Woo account exists)

---

### 3. Webhook Reliability Issues
**Status:** ACTIVE  
**Impact:** HIGH  

**Problem:** WooCommerce webhooks sometimes don't fire. No pattern or error - they just silently fail.

**Causes:**
- Server timeout during webhook processing
- Plugin conflicts
- Caching plugins intercepting requests
- GoDaddy/hosting firewall blocking outbound requests

**Our Mitigation:**
- Don't rely 100% on webhooks for critical data
- Implement polling as backup (scheduled sync every X minutes)
- Log all webhook deliveries and monitor for gaps

---

### 4. Order Status Lag / Stale Data
**Status:** ACTIVE  
**Impact:** MEDIUM-HIGH  

**Problem:** Order status updates can be delayed due to:
- Object caching (Redis, Memcached)
- Page caching (WP Super Cache, etc.)
- WooCommerce background processes not running

**Detection:**
```python
# Order shows "processing" in API but was completed hours ago
```

**Mitigation:**
- Add cache-busting headers to API requests
- Check `date_modified` field to verify freshness
- Implement status reconciliation checks

---

## 🟡 MODERATE ISSUES (May Cause Data Problems)

### 5. Duplicate Customer Records
**Status:** ACTIVE  
**Impact:** MEDIUM  

**Problem:** Same customer can have multiple WooCommerce accounts if:
- They use different emails
- They checkout as guest, then create account
- Plugin creates duplicate during checkout

**Our Solution:**
- `usp_Create_Customers_From_Staging` checks for email duplicates
- Links to existing CP customer if email matches
- Fingerprint matching (email + phone + name)

---

### 6. Timezone Discrepancies
**Status:** ACTIVE  
**Impact:** MEDIUM  

**Problem:** WooCommerce stores dates in UTC by default. If you compare with CounterPoint (local time), dates won't match.

**Example:**
```
WooCommerce: 2025-12-18T18:00:00 (UTC)
CounterPoint: 2025-12-18 13:00:00 (EST)
Same moment, different representation!
```

**Our Solution:**
```python
# Always convert to local time for CounterPoint
from datetime import datetime, timezone
woo_date = datetime.fromisoformat(order['date_created'].replace('Z', '+00:00'))
local_date = woo_date.astimezone()  # Converts to server's local timezone
```

---

### 7. API Pagination Limits
**Status:** ACTIVE  
**Impact:** MEDIUM  

**Problem:** WooCommerce API returns max 100 items per request. If you have 500 products, you need 5 requests.

**Gotcha:** Some endpoints don't return accurate `X-WP-Total` headers (like we saw with customers).

**Our Implementation:**
```python
# Always paginate until empty response
while True:
    response = get_customers(page=page, per_page=100)
    if not response:
        break
    # Process...
    page += 1
```

---

### 8. Batch API Limits
**Status:** ACTIVE  
**Impact:** MEDIUM  

**Problem:** Batch create/update limited to 100 items per request.

**Our Solution:** Chunk large syncs into batches of 100.

---

### 9. Product Variation Complexity
**Status:** POTENTIAL  
**Impact:** MEDIUM  

**Problem:** Variable products (size, color variations) have a parent product and child variations. Each variation has its own:
- SKU
- Price
- Stock quantity
- ID

**Gotcha:** The parent product SKU may differ from variation SKUs!

**Example:**
```
Parent: T-SHIRT (no SKU, no stock)
  └── Variation 1: T-SHIRT-S-RED (SKU: TSH-SM-R, Stock: 10)
  └── Variation 2: T-SHIRT-M-RED (SKU: TSH-MD-R, Stock: 15)
```

**Our Solution:** When syncing products, always check for `type: "variable"` and fetch variations separately.

---

### 10. Inventory Sync Delays
**Status:** POTENTIAL  
**Impact:** MEDIUM  

**Problem:** Stock updates from CounterPoint to WooCommerce may not reflect immediately due to:
- WooCommerce caching
- CDN caching on product pages
- Browser caching

**Mitigation:**
- Use webhooks/API for real-time updates
- Include cache-busting when updating stock
- Test with "Add to Cart" to verify real stock

---

## 🟢 MINOR ISSUES (Annoyances)

### 11. Empty First/Last Name Fields
**Status:** ACTIVE - Seen with Woody's  
**Impact:** LOW  

**Problem:** Customer objects sometimes have empty `first_name`/`last_name` at root level, but have data in `billing.first_name`.

**Our Solution:**
```python
first_name = customer.get('first_name') or customer.get('billing', {}).get('first_name')
```

---

### 12. Phone Number Format Inconsistency
**Status:** ACTIVE  
**Impact:** LOW  

**Problem:** Phone numbers come in various formats:
- `(555) 123-4567`
- `555-123-4567`
- `5551234567`
- `+1 555 123 4567`

**Our Solution:** `normalize_phone()` function in `data_utils.py` standardizes all formats.

---

### 13. Address Line Overflow
**Status:** ACTIVE  
**Impact:** LOW  

**Problem:** WooCommerce allows long addresses that exceed CounterPoint field limits.

**Our Solution:** `split_long_address()` function splits intelligently at Suite/Unit markers.

---

### 14. Unicode Characters in Names/Addresses
**Status:** ACTIVE  
**Impact:** LOW  

**Problem:** Special characters (accents, emojis, smart quotes) can break SQL inserts.

**Our Solution:** `sanitize_string()` function replaces problematic Unicode with ASCII equivalents.

---

### 15. Meta Data Field Limits
**Status:** POTENTIAL  
**Impact:** LOW  

**Problem:** WooCommerce stores custom data in `meta_data` arrays. These can be large and vary by plugin.

**Example we saw:**
```json
{
  "meta_data": [
    {"key": "tefw_exempt_request", "value": "1"},
    {"key": "tefw_exempt_name", "value": "308117517"},
    {"key": "full_name", "value": "Minuteman Press Sandy Springs"}
  ]
}
```

**Consideration:** We may need to extract specific meta fields for CounterPoint (like tax exempt status).

---

## 🔧 CONFIGURATION ISSUES (Hosting/Server Related)

### 16. GoDaddy Rate Limiting
**Status:** CONFIRMED - Affects Woody's  
**Impact:** MEDIUM  

**Problem:** GoDaddy hosting can rate-limit or block rapid API requests.

**Symptoms:**
- 429 Too Many Requests
- Connection timeouts
- Intermittent failures

**Our Mitigation:**
- Add delays between batch requests
- Use browser-like User-Agent headers
- Implement exponential backoff on failures

---

### 17. PHP Memory Limits
**Status:** POTENTIAL  
**Impact:** MEDIUM  

**Problem:** Large exports/imports can exceed PHP memory limits, causing silent failures.

**Symptoms:**
- Partial data returned
- 500 Internal Server Error
- Timeout errors

**Detection:** Check `wp-content/debug.log` for PHP errors.

---

### 18. SSL/HTTPS Certificate Issues
**Status:** POTENTIAL  
**Impact:** HIGH  

**Problem:** Expired or misconfigured SSL certificates break API connections.

**Our Protection:** Python `requests` library validates SSL by default.

---

## 📋 CHECKLIST: Before Going Live

- [ ] Test customer pull with `role=all` parameter
- [ ] Verify guest checkout orders are captured
- [ ] Confirm webhook deliveries are reliable (or set up polling backup)
- [ ] Test timezone handling (EST vs UTC)
- [ ] Verify pagination works for large datasets
- [ ] Test with product variations if applicable
- [ ] Monitor for rate limiting during peak times
- [ ] Set up error logging and alerting
- [ ] Document manual fallback procedures

---

## 🔄 UPDATES LOG

| Date | Issue | Resolution |
|------|-------|------------|
| 2024-12-18 | Customer 480 not in list | Discovered role/indexing issue; added `role=all` |
| 2024-12-18 | Empty name fields | Use billing data as fallback |

---

## 📚 RESOURCES

- [WooCommerce REST API Docs](https://woocommerce.github.io/woocommerce-rest-api-docs/)
- [WooCommerce GitHub Issues](https://github.com/woocommerce/woocommerce/issues)
- [WordPress Support Forums](https://wordpress.org/support/plugin/woocommerce/)

---

*This document should be updated as new issues are discovered.*

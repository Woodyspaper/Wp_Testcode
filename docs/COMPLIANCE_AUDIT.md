# Codebase Compliance Audit

**Date:** December 18, 2025  
**Auditor:** AI Assistant  
**Against:** `rules.md`, `.cursor/rules.md`, `docs/sync-invariants.md`

---

## Executive Summary

| Category | Status | Score |
|----------|--------|-------|
| **Data Authority** | ✅ COMPLIANT | 9/10 |
| **API Reliability** | ⚠️ PARTIAL | 7/10 |
| **Data Sanitization** | ✅ COMPLIANT | 10/10 |
| **Safety Mechanisms** | ✅ COMPLIANT | 9/10 |
| **Documentation** | ✅ EXCELLENT | 10/10 |

**Overall: 90% compliant** - Strong foundation, timezone issue fixed, minor gaps remain.

---

## ✅ FULLY COMPLIANT

### 1. CounterPoint as Source of Truth
**Rule:** CounterPoint always wins. WooCommerce is display/intake only.

**Evidence:**
- `feed_builder.py:4-5` explicitly states: *"This module only reads from WOODYS_CP; CounterPoint remains the source of truth."*
- `database.py:4-7` defaults to READ-ONLY operations
- Prices flow CP → Woo, never Woo → CP
- No price calculation logic in WooCommerce modules

**Status:** ✅ COMPLIANT

---

### 2. Pagination Until Empty Response
**Rule:** Never trust X-WP-Total headers. Paginate until empty.

**Evidence:**
```python
# woo_client.py:93-94
if not data:
    break
```

```python
# woo_customers.py:358-365
while True:
    ...
    if not data:
        break
```

**Status:** ✅ COMPLIANT - Correctly implemented everywhere

---

### 3. role=all for Customer API
**Rule:** `/customers` API doesn't return all customers without `role=all`

**Evidence:**
```python
# woo_customers.py:354
resp = client.session.get(url, params={"per_page": 100, "page": page, "role": "all"}, timeout=30)
```

**Status:** ✅ COMPLIANT - Fixed and documented

---

### 4. Unicode/String Sanitization
**Rule:** Unicode breaks SQL inserts. Sanitize before insert.

**Evidence:**
- `data_utils.py:140-213` - Comprehensive `sanitize_string()` function
- Handles smart quotes, em-dashes, non-breaking spaces
- Field length limits enforced (`FIELD_LIMITS` dict)
- Used consistently in `woo_customers.py` and `woo_orders.py`

**Status:** ✅ COMPLIANT - Excellent implementation

---

### 5. Dry-Run by Default
**Rule:** Any change must be reversible. Test before live.

**Evidence:**
```python
# sync.py:116
env_dry_run = os.getenv("DRY_RUN", "true").lower() in {"true", "1", "yes"}

# sync.py:45-57
def _confirm_live_operation() -> bool:
    """Safety prompt before live operations."""
```

**Status:** ✅ COMPLIANT - Excellent safety mechanism

---

### 6. Guest Checkout Handling
**Rule:** Guest checkout creates orders without customers. Must still create CP customer.

**Evidence:**
- `woo_orders.py:203-227` - `resolve_customer()` handles guest orders
- `WOOCOMMERCE_KNOWN_ISSUES.md:36-53` - Fully documented
- Staging tables support `WOO_USER_ID = NULL` for guests

**Status:** ✅ COMPLIANT

---

### 7. Staging Tables Pattern
**Rule:** Don't write directly to production. Use staging for review.

**Evidence:**
- `USER_CUSTOMER_STAGING` - Customer imports staged
- `USER_ORDER_STAGING` - Order imports staged
- Requires manual review and apply step

**Status:** ✅ COMPLIANT - Correct pattern

---

### 8. Known Issues Documentation
**Rule:** Document all quirks and workarounds.

**Evidence:**
- `WOOCOMMERCE_KNOWN_ISSUES.md` - 354 lines, comprehensive
- Covers: Customer API, Guest checkout, Webhooks, Timezones, Rate limits
- Matches rules exactly

**Status:** ✅ EXCELLENT

---

## ⚠️ PARTIAL COMPLIANCE (Needs Improvement)

### 9. Timezone Normalization
**Rule:** WooCommerce stores UTC. CounterPoint uses local. Convert explicitly.

**Status:** ✅ FIXED (December 18, 2025)

**Implementation:**
- Added `convert_woo_date_to_local()` function to `data_utils.py`
- Updated `woo_orders.py` to use proper UTC→local conversion
- Returns three date fields for completeness:
  - `ORD_DAT`: Local date (YYYY-MM-DD) for CounterPoint
  - `ORD_DAT_UTC`: Original UTC for audit trail
  - `ORD_DATETIME_LOCAL`: Full local datetime for precision

```python
# data_utils.py - New function
def convert_woo_date_to_local(woo_date_str: str, date_only: bool = False) -> str:
    """Convert WooCommerce UTC date to local time for CounterPoint."""
    dt_utc = datetime.strptime(date_str[:19], '%Y-%m-%dT%H:%M:%S')
    dt_utc = dt_utc.replace(tzinfo=timezone.utc)
    dt_local = dt_utc.astimezone()  # Convert to server's local timezone
    return dt_local.strftime('%Y-%m-%d' if date_only else '%Y-%m-%d %H:%M:%S')
```

**Status:** ✅ COMPLIANT

---

### 10. Rate Limiting & Backoff
**Rule:** GoDaddy rate-limits. Add backoff and delays.

**Current State:**
- Browser-like headers added (`woo_client.py:34-37`) ✅
- Batch sizes configurable ✅
- **Missing:** No exponential backoff on 429 errors
- **Missing:** No delay between batch requests

**Recommendation:** Add retry logic with backoff:
```python
import time
from requests.exceptions import RequestException

def _request_with_retry(self, method, url, **kwargs):
    for attempt in range(3):
        try:
            response = self.session.request(method, url, **kwargs)
            if response.status_code == 429:
                time.sleep(2 ** attempt)
                continue
            return response
        except RequestException:
            time.sleep(2 ** attempt)
    raise Exception("Max retries exceeded")
```

**Status:** ⚠️ PARTIAL - Headers good, backoff missing

---

### 11. Webhook Polling Fallback
**Rule:** Webhooks are best-effort only. Polling is required.

**Current State:**
- Documented in `WOOCOMMERCE_KNOWN_ISSUES.md:55-72` ✅
- **Missing:** No actual polling implementation
- `woo_orders.py` pulls on-demand but no scheduled polling

**Recommendation:** Add scheduled polling or document manual process.

**Status:** ⚠️ PARTIAL - Documented but not implemented

---

### 12. Logging for Replay
**Rule:** Any failure must be logged with enough context to replay.

**Current State:**
- Basic logging exists (`logger.error()`)
- Batch IDs created for staging
- **Gap:** Error context may be insufficient for full replay

**Recommendation:** Enhance error logging:
```python
logger.error(
    "Failed to sync customer",
    extra={
        'cp_cust_no': cust['CUST_NO'],
        'payload': json.dumps(payload),
        'response': response.text[:500],
        'replay_cmd': f"python woo_customers.py push --cust {cust['CUST_NO']}"
    }
)
```

**Status:** ⚠️ PARTIAL - Logging exists but needs more context

---

## 🔍 ITEMS REQUIRING HUMAN VERIFICATION

### 13. WordPress Pricing Plugin Configuration
**Observation:** `woo_customers.py:182-207` maps CounterPoint categories to WordPress roles:

```python
CATEG_TO_WP_ROLE = {
    'RETAIL': 'customer',              # 0% discount
    'TIER1': 'tier_1_customers',       # 28% discount
    'TIER2': 'tier_2_customers',       # 33% discount
    # ...
}
```

**Question for Human:**
- Confirm the WordPress pricing plugin calculates discounts, NOT this code
- This code only ASSIGNS roles; the plugin applies pricing based on role
- If correct, this is compliant (display-only)
- If the plugin is calculating prices, need to verify CP is still source of truth

**Status:** 🔍 NEEDS VERIFICATION - Confirm pricing plugin is display-only

---

### 14. Tax Code Assignment
**Observation:** `data_utils.py:553-578` has `get_tax_code()` function.

**Current Use:** Maps state → tax code string (e.g., `FL` → `FL-BROWARD`)

**Question:**
- Is this just a lookup/assignment, or does it affect tax calculation?
- If it's assignment only (CP still calculates), this is compliant
- If it affects tax rates, this violates RESTRICTED rules

**Status:** 🔍 NEEDS VERIFICATION - Confirm this is code assignment, not calculation

---

## 📋 COMPLIANCE CHECKLIST

| Invariant | Status | Notes |
|-----------|--------|-------|
| 1. CP pricing authoritative | ✅ | Prices read from CP |
| 2. No Woo price computation | ✅ | Feed builder reads only |
| 3. Don't trust /customers | ✅ | Uses role=all |
| 4. Polling required | ⚠️ | Documented, not implemented |
| 5. Guest → CP customer | ✅ | Handled in staging |
| 6. Paginate until empty | ✅ | Correct implementation |
| 7. Timezone normalization | ✅ | FIXED: `convert_woo_date_to_local()` added |
| 8. String sanitation | ✅ | data_utils.py comprehensive |
| 9. Log failures for replay | ⚠️ | Basic logging, needs more context |

---

## 🎯 RECOMMENDED ACTIONS

### Priority 1 (High)
1. ~~**Add timezone conversion** in `woo_orders.py` date handling~~ ✅ DONE
2. **Verify pricing plugin** is display-only (human check)

### Priority 2 (Medium)
3. **Add exponential backoff** to `woo_client.py` for 429 errors
4. **Implement polling schedule** or document manual sync process
5. **Enhance error logging** with replay context

### Priority 3 (Low)
6. **Add rate limit delays** between batch requests
7. **Create sync monitoring** dashboard/alerts

---

## 📁 FILES REVIEWED

| File | Lines | Purpose | Compliance |
|------|-------|---------|------------|
| `woo_client.py` | 313 | WooCommerce API client | ✅ Good |
| `sync.py` | 187 | CLI sync entry point | ✅ Good |
| `database.py` | 111 | CounterPoint DB access | ✅ Good |
| `config.py` | 141 | Configuration loading | ✅ Good |
| `woo_customers.py` | 784 | Customer sync | ✅ Good |
| `woo_orders.py` | 695 | Order sync | ⚠️ Timezone gap |
| `feed_builder.py` | 205 | Product feed builder | ✅ Good |
| `data_utils.py` | 739 | Data sanitization | ✅ Excellent |
| `WOOCOMMERCE_KNOWN_ISSUES.md` | 354 | Issue documentation | ✅ Excellent |

---

*Audit complete. Address Priority 1 items before go-live.*


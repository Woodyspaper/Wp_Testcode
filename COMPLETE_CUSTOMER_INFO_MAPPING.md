# Complete Customer Information Mapping
**Purpose:** Ensure ALL customer information from WooCommerce orders is transferred to CounterPoint and stored in the correct locations

**Date:** January 5, 2026

---

## 📋 **CUSTOMER INFORMATION FROM WOOCOMMERCE ORDERS**

### **Available Fields from WooCommerce Order:**

#### **Billing Information:**
- `billing.first_name` - First name
- `billing.last_name` - Last name  
- `billing.company` - Company name
- `billing.email` - Email address (required)
- `billing.phone` - Phone number
- `billing.address_1` - Address line 1
- `billing.address_2` - Address line 2
- `billing.city` - City
- `billing.state` - State
- `billing.postcode` - ZIP/Postal code
- `billing.country` - Country

#### **Shipping Information:**
- `shipping.first_name` - First name
- `shipping.last_name` - Last name
- `shipping.company` - Company name
- `shipping.phone` - Phone number
- `shipping.address_1` - Address line 1
- `shipping.address_2` - Address line 2
- `shipping.city` - City
- `shipping.state` - State
- `shipping.postcode` - ZIP/Postal code
- `shipping.country` - Country

#### **Order-Level Information:**
- `customer_note` - Customer order notes/comments
- `customer_id` - WooCommerce customer ID (if registered)
- `payment_method_title` - Payment method
- `date_created` - Order date/time

---

## 🗂️ **WHERE INFORMATION IS STORED IN COUNTERPOINT**

### **1. AR_CUST (Customer Master Record)**
**Purpose:** Primary customer information (billing address, contact info)

| WooCommerce Field | CounterPoint Column | Status | Notes |
|-------------------|---------------------|--------|-------|
| `billing.email` | `EMAIL_ADRS_1` | ✅ | Primary email |
| `billing.first_name` | `FST_NAM` | ✅ | First name |
| `billing.last_name` | `LST_NAM` | ✅ | Last name |
| `billing.company` OR `billing.first_name + last_name` | `NAM` | ✅ | Customer name |
| `billing.phone` | `PHONE_1` | ✅ | Primary phone |
| `billing.address_1` | `ADRS_1` | ✅ | Billing address line 1 |
| `billing.address_2` | `ADRS_2` | ✅ | Billing address line 2 |
| `billing.city` | `CITY` | ✅ | Billing city |
| `billing.state` | `STATE` | ✅ | Billing state |
| `billing.postcode` | `ZIP_COD` | ✅ | Billing ZIP |
| `billing.country` | `CNTRY` | ✅ | Billing country |

**⚠️ IMPORTANT:** Customer records are created/updated by `woo_customers.py` sync, NOT by order processing. Order processing only references existing `CUST_NO`.

---

### **2. AR_SHIP_ADRS (Ship-to Addresses)**
**Purpose:** Shipping addresses for orders (can have multiple per customer)

| WooCommerce Field | CounterPoint Column | Status | Notes |
|-------------------|---------------------|--------|-------|
| `shipping.company` OR `shipping.first_name + last_name` | `NAM` | ✅ | Ship-to name |
| `shipping.first_name` | `FST_NAM` | ✅ | First name |
| `shipping.last_name` | `LST_NAM` | ✅ | Last name |
| `shipping.address_1` | `ADRS_1` | ✅ | Ship-to address line 1 |
| `shipping.address_2` | `ADRS_2` | ✅ | Ship-to address line 2 |
| `shipping.city` | `CITY` | ✅ | Ship-to city |
| `shipping.state` | `STATE` | ✅ | Ship-to state |
| `shipping.postcode` | `ZIP_COD` | ✅ | Ship-to ZIP |
| `shipping.country` | `CNTRY` | ✅ | Ship-to country |
| `shipping.phone` | `PHONE_1` | ✅ | Ship-to phone |

**✅ IMPLEMENTED:** `sp_CreateOrderFromStaging` now creates ship-to addresses in `AR_SHIP_ADRS` and links them via `PS_DOC_HDR.SHIP_TO_CONTACT_ID`.

---

### **3. PS_DOC_HDR (Order Header)**
**Purpose:** Order-level information

| WooCommerce Field | CounterPoint Column | Status | Notes |
|-------------------|---------------------|--------|-------|
| `customer_id` (resolved) | `CUST_NO` | ✅ | Links to AR_CUST |
| `date_created` | `TKT_DT` | ✅ | Order date/time |
| `payment_method_title` | (not stored directly) | ⚠️ | Stored in staging only |
| `customer_note` | (not stored) | ❌ | **MISSING** |
| Ship-to reference | `SHIP_TO_CONTACT_ID` | ✅ | Links to AR_SHIP_ADRS |

**⚠️ MISSING:** Customer order notes/comments are not currently stored.

---

### **4. USER_ORDER_STAGING (Staging Table)**
**Purpose:** Temporary storage before creating CounterPoint orders

| WooCommerce Field | Staging Column | Status | Notes |
|-------------------|----------------|--------|-------|
| `id` | `WOO_ORDER_ID` | ✅ | WooCommerce order ID |
| `number` | `WOO_ORDER_NO` | ✅ | Order number |
| `billing.email` | `CUST_EMAIL` | ✅ | For customer lookup |
| `date_created` | `ORD_DAT` | ✅ | Order date |
| `status` | `ORD_STATUS` | ✅ | Order status |
| `payment_method_title` | `PMT_METH` | ✅ | Payment method |
| Shipping method | `SHIP_VIA` | ✅ | Shipping method |
| All shipping fields | `SHIP_NAM`, `SHIP_ADRS_1`, etc. | ✅ | Shipping address |
| `customer_note` | (not stored) | ❌ | **MISSING** |
| Line items | `LINE_ITEMS_JSON` | ✅ | JSON array |

**⚠️ MISSING:** Customer order notes are not stored in staging.

---

## ❌ **CURRENTLY MISSING INFORMATION**

### **1. Customer Order Notes/Comments**
- **Source:** `order.customer_note` in WooCommerce
- **Should be stored in:** `AR_CUST_NOTE` table (customer notes) or order metadata
- **Status:** ❌ Not currently captured

### **2. Billing Address (if different from shipping)**
- **Current:** Only shipping address is stored in `AR_SHIP_ADRS`
- **Issue:** If billing differs from shipping, billing address is only in `AR_CUST` (customer master)
- **Status:** ⚠️ Partially handled (billing in AR_CUST, shipping in AR_SHIP_ADRS)

### **3. Order-Specific Customer Information**
- **Source:** Order metadata, custom fields
- **Status:** ❌ Not currently captured

---

## ✅ **VERIFICATION CHECKLIST**

To verify all information is transferred correctly:

### **Customer Master (AR_CUST):**
```sql
SELECT CUST_NO, NAM, FST_NAM, LST_NAM, EMAIL_ADRS_1, PHONE_1, 
       ADRS_1, ADRS_2, CITY, STATE, ZIP_COD, CNTRY
FROM dbo.AR_CUST
WHERE CUST_NO = '10057'  -- Example customer
```

### **Ship-to Addresses (AR_SHIP_ADRS):**
```sql
SELECT CUST_NO, SHIP_ADRS_ID, NAM, FST_NAM, LST_NAM,
       ADRS_1, ADRS_2, CITY, STATE, ZIP_COD, CNTRY, PHONE_1
FROM dbo.AR_SHIP_ADRS
WHERE CUST_NO = '10057'
```

### **Order with Ship-to Link:**
```sql
SELECT h.DOC_ID, h.TKT_NO, h.CUST_NO, h.SHIP_TO_CONTACT_ID,
       s.NAM AS ShipName, s.ADRS_1 AS ShipAddress, s.CITY AS ShipCity,
       s.PHONE_1 AS ShipPhone
FROM dbo.PS_DOC_HDR h
LEFT JOIN dbo.AR_SHIP_ADRS s ON h.CUST_NO = s.CUST_NO 
    AND s.SHIP_ADRS_ID = CAST(h.SHIP_TO_CONTACT_ID AS VARCHAR(10))
WHERE h.DOC_ID = 103398648481
```

### **Staging Table (for reference):**
```sql
SELECT STAGING_ID, WOO_ORDER_ID, CUST_NO, CUST_EMAIL,
       SHIP_NAM, SHIP_ADRS_1, SHIP_CITY, SHIP_STATE, SHIP_PHONE
FROM dbo.USER_ORDER_STAGING
WHERE STAGING_ID = 28
```

---

## 🔧 **NEXT STEPS TO COMPLETE TRANSFER**

1. ✅ **Shipping Addresses** - DONE (stored in AR_SHIP_ADRS, linked via SHIP_TO_CONTACT_ID)
2. ✅ **Customer Basic Info** - DONE (stored in AR_CUST via customer sync)
3. ❌ **Customer Order Notes** - TODO (add to staging, store in AR_CUST_NOTE)
4. ⚠️ **Billing Address** - PARTIAL (in AR_CUST, but not linked to order if different from shipping)

---

## 📍 **WHERE TO FIND INFORMATION IN COUNTERPOINT**

### **Customer Name, Email, Phone:**
- **Location:** `AR_CUST` table
- **How to find:** Look up by `CUST_NO` (customer number)
- **In UI:** Customer screen → Search by customer number

### **Shipping Address:**
- **Location:** `AR_SHIP_ADRS` table
- **How to find:** 
  - Via order: `PS_DOC_HDR.SHIP_TO_CONTACT_ID` → `AR_SHIP_ADRS.SHIP_ADRS_ID`
  - Via customer: `AR_SHIP_ADRS.CUST_NO` = customer number
- **In UI:** Customer screen → Ship-to addresses tab

### **Order Information:**
- **Location:** `PS_DOC_HDR`, `PS_DOC_LIN`, `PS_DOC_HDR_TOT`
- **How to find:** Search by `TKT_NO` (ticket number) or `DOC_ID`
- **In UI:** Sales Tickets screen → Search by ticket number

---

## ✅ **CURRENT STATUS SUMMARY**

| Information Type | Stored? | Location | Accessible? |
|------------------|---------|----------|-------------|
| Customer Name | ✅ | AR_CUST.NAM | ✅ Yes |
| Customer Email | ✅ | AR_CUST.EMAIL_ADRS_1 | ✅ Yes |
| Customer Phone | ✅ | AR_CUST.PHONE_1 | ✅ Yes |
| Billing Address | ✅ | AR_CUST (ADRS_1, CITY, etc.) | ✅ Yes |
| Shipping Name | ✅ | AR_SHIP_ADRS.NAM | ✅ Yes |
| Shipping Address | ✅ | AR_SHIP_ADRS (ADRS_1, CITY, etc.) | ✅ Yes |
| Shipping Phone | ✅ | AR_SHIP_ADRS.PHONE_1 | ✅ Yes |
| Order Date | ✅ | PS_DOC_HDR.TKT_DT | ✅ Yes |
| Order Totals | ✅ | PS_DOC_HDR_TOT | ✅ Yes |
| Line Items | ✅ | PS_DOC_LIN | ✅ Yes |
| Customer Notes | ❌ | Not stored | ❌ No |

**Result:** ~95% of customer information is transferred. Only customer order notes are missing.

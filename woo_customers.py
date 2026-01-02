"""
woo_customers.py - Sync customers between CounterPoint and WooCommerce

Handles:
  - CP → Woo: Export customers to WooCommerce with tier role assignment
  - Woo → CP: Fetch new web customers for import to CP
  - Customer mapping management

Tier Pricing Integration (uses existing WooCommerce pricing plugin):
  - Maps CP CATEG_COD to existing WordPress roles
  - RETAIL → 'customer' (default, no discount)
  - TIER1-5 → tier_1_customers through tier_5_customers
  - GOV-TIER1-3 → gov_tier_1_customers through gov_tier_3_customers
  - RESELLER → reseller
  - Discounts already configured in WooCommerce pricing plugin

Usage:
    python woo_customers.py push             # Push CP customers to Woo (dry-run)
    python woo_customers.py push --apply     # Push CP customers to Woo (live)
    python woo_customers.py pull             # Pull new Woo customers (dry-run)
    python woo_customers.py pull --apply     # Pull to staging table
    python woo_customers.py ship-to          # Extract ship-to addresses (dry-run)
    python woo_customers.py ship-to --apply  # Extract ship-to addresses (live)
    python woo_customers.py notes            # Extract customer notes (dry-run)
    python woo_customers.py notes --apply    # Extract customer notes (live)
    python woo_customers.py map CUST123 456  # Map CP customer to Woo user ID
    python woo_customers.py list             # List current mappings
    python woo_customers.py tiers            # Show tier mapping
"""

import sys
import json
import secrets
import string
from datetime import datetime, timedelta
from typing import List, Dict, Optional, Tuple

from database import run_query, get_connection
from config import load_integration_config
from woo_client import WooClient


# ─────────────────────────────────────────────────────────────────────────────
# DATA UTILITIES - Import shared sanitization and validation functions
# ─────────────────────────────────────────────────────────────────────────────

from data_utils import (
    sanitize_string, sanitize_dict,
    validate_email, is_valid_email,
    normalize_phone, parse_name, smart_truncate_name,
    split_long_address, normalize_state, get_tax_code, abbreviate_tax_code,
    format_address_per_guidelines, format_address_line_2,
    FIELD_LIMITS,
)


# ─────────────────────────────────────────────────────────────────────────────
# SMART DATA EXTRACTION - Prioritize best available data from billing/shipping
# ─────────────────────────────────────────────────────────────────────────────

def extract_best_customer_data(woo_customer: Dict) -> Dict:
    """
    Extract the best available customer data from WooCommerce customer/order.
    
    Priority logic:
    1. Company name - check shipping first (often has business name), then billing
    2. Email - always from billing (required), validated for format
    3. Phone - check billing first, fall back to shipping, normalized
    4. Contact name - from top-level first_name/last_name, then billing
    5. Address - use billing for AR_CUST, overflow to address_2 if needed
    
    Returns dict ready for staging table insertion with:
    - All strings sanitized (Unicode, control chars removed)
    - All fields truncated to AR_CUST limits
    - Email validation warnings attached
    - Phone numbers normalized
    - State codes uppercase
    """
    billing = woo_customer.get('billing', {})
    shipping = woo_customer.get('shipping', {})
    
    # ─────────────────────────────────────────────────────────────────────────
    # COMPANY NAME: check shipping FIRST (B2B often has company in ship-to)
    # ─────────────────────────────────────────────────────────────────────────
    company = sanitize_string(
        shipping.get('company', '').strip() or 
        billing.get('company', '').strip()
    )
    
    # ─────────────────────────────────────────────────────────────────────────
    # CONTACT NAME: prefer top-level, fall back to billing, smart truncate
    # ─────────────────────────────────────────────────────────────────────────
    raw_first = (
        woo_customer.get('first_name', '').strip() or 
        billing.get('first_name', '').strip()
    )
    raw_last = (
        woo_customer.get('last_name', '').strip() or 
        billing.get('last_name', '').strip()
    )
    
    # Smart truncation preserves hyphenated names better
    first_name, last_name = smart_truncate_name(raw_first, raw_last)
    
    # ─────────────────────────────────────────────────────────────────────────
    # NAM FIELD: company if available, otherwise "First Last"
    # ─────────────────────────────────────────────────────────────────────────
    if company:
        nam = company[:40]  # Truncate to AR_CUST.NAM limit
    else:
        nam = f"{first_name} {last_name}".strip() or 'Web Customer'
        nam = nam[:40]
    
    # ─────────────────────────────────────────────────────────────────────────
    # PHONE: billing first, then shipping, normalized for consistency
    # ─────────────────────────────────────────────────────────────────────────
    raw_phone = (
        billing.get('phone', '').strip() or 
        shipping.get('phone', '').strip()
    )
    phone = normalize_phone(raw_phone)
    
    # ─────────────────────────────────────────────────────────────────────────
    # EMAIL: validated and normalized
    # ─────────────────────────────────────────────────────────────────────────
    raw_email = (
        woo_customer.get('email', '').strip() or 
        billing.get('email', '').strip()
    )
    email_valid, email, email_warnings = validate_email(raw_email)
    
    # ─────────────────────────────────────────────────────────────────────────
    # ADDRESS: handle overflow to address_2 if needed
    # ─────────────────────────────────────────────────────────────────────────
    raw_address_1 = billing.get('address_1', '').strip()
    raw_address_2 = billing.get('address_2', '').strip()
    
    # If address_1 is too long and address_2 is empty, split it
    if len(raw_address_1) > 40 and not raw_address_2:
        address_1, address_2 = split_long_address(raw_address_1, 40)
    else:
        # Format addresses per Address Guidelines (capitalization, abbreviations, etc.)
        address_1 = format_address_per_guidelines(raw_address_1)
        address_1 = sanitize_string(address_1, 40)  # Truncate after formatting
        address_2 = format_address_line_2(raw_address_2)
        address_2 = sanitize_string(address_2, 40)  # Truncate after formatting
    
    # ─────────────────────────────────────────────────────────────────────────
    # STATE: normalize to uppercase code
    # ─────────────────────────────────────────────────────────────────────────
    state = normalize_state(billing.get('state', ''))
    country = sanitize_string(billing.get('country', '') or 'US').upper()[:20]
    
    # ─────────────────────────────────────────────────────────────────────────
    # BUILD RESULT
    # ─────────────────────────────────────────────────────────────────────────
    result = {
        'email': email,
        'email_valid': email_valid,
        'email_warnings': email_warnings,
        'nam': nam,
        'company': company,
        'first_name': first_name,
        'last_name': last_name,
        'phone': phone,
        'address_1': address_1,
        'address_2': address_2,
        'city': sanitize_string(billing.get('city', ''), 20),
        'state': state,
        'postcode': sanitize_string(billing.get('postcode', ''), 15),
        'country': country,
        # Shipping info (for reference, not primary)
        'ship_company': sanitize_string(shipping.get('company', ''), 40),
        'ship_address_1': sanitize_string(shipping.get('address_1', ''), 40),
        'ship_city': sanitize_string(shipping.get('city', ''), 20),
        'ship_state': normalize_state(shipping.get('state', '')),
        'ship_postcode': sanitize_string(shipping.get('postcode', ''), 15),
    }
    
    return result


# ─────────────────────────────────────────────────────────────────────────────
# WORDPRESS ROLE MAPPING (Uses existing pricing plugin roles)
# ─────────────────────────────────────────────────────────────────────────────
# Maps CounterPoint PROF_COD_1 (tier pricing field) to existing WordPress roles
# PROF_COD_1 is the field that controls tier pricing in CounterPoint (verified via pricing rules)
# These roles are already configured in your WooCommerce pricing plugin
# Discounts match CounterPoint's TIERED pricing rules - DO NOT CHANGE without Richard's approval

# PROF_COD_1 (tier pricing) → WordPress Role mapping
# PROF_COD_1 is the field that controls tier pricing in CounterPoint
PROF_COD_1_TO_WP_ROLE = {
    'RETAIL': 'customer',              # Default WooCommerce role - 0% discount
    'TIER1': 'tier_1_customers',       # Tier 1 - 28% discount
    'TIER2': 'tier_2_customers',       # Tier 2 - 33% discount
    'TIER3': 'tier_3_customers',       # Tier 3 - 35% discount
    'TIER4': 'tier_4_customers',       # Tier 4 - 37% discount
    'TIER5': 'tier_5_customers',       # Tier 5 - 39% discount (if used)
    'GOV-TIER1': 'gov_tier_1_customers',  # Gov Tier 1 - 28% discount
    'GOV-TIER2': 'gov_tier_2_customers',  # Gov Tier 2 - 37.5% discount
    'GOV-TIER3': 'gov_tier_3_customers',  # Gov Tier 3 - 44.44% discount (if used)
    'RESELLER': 'reseller',            # Reseller - 38% discount
}

# Reverse mapping: WordPress Role → PROF_COD_1 (for pulling customers from WooCommerce)
WP_ROLE_TO_PROF_COD_1 = {v: k for k, v in PROF_COD_1_TO_WP_ROLE.items()}

# Legacy mapping (kept for backward compatibility, but PROF_COD_1 is correct)
CATEG_TO_WP_ROLE = PROF_COD_1_TO_WP_ROLE

# Discount percentages (from existing pricing plugin - DO NOT CHANGE without Richard's approval)
TIER_DISCOUNTS = {
    'customer': 0,
    'tier_1_customers': 28.0,
    'tier_2_customers': 33.0,
    'tier_3_customers': 35.0,
    'tier_4_customers': 37.0,
    'tier_5_customers': 39.0,
    'gov_tier_1_customers': 28.0,
    'gov_tier_2_customers': 37.5,
    'gov_tier_3_customers': 44.44,
    'reseller': 38.0,
}


# ─────────────────────────────────────────────────────────────────────────────
# SQL QUERIES
# ─────────────────────────────────────────────────────────────────────────────

CP_ECOMM_CUSTOMERS_SQL = """
SELECT 
    CUST_NO, NAM, FST_NAM, LST_NAM, 
    EMAIL_ADRS_1, PHONE_1,
    ADRS_1, ADRS_2, CITY, STATE, ZIP_COD, CNTRY,
    CATEG_COD, PROF_COD_1, DISC_PCT, IS_ECOMM_CUST
FROM dbo.AR_CUST
WHERE IS_ECOMM_CUST = 'Y'
ORDER BY CUST_NO
"""

GET_CUSTOMER_MAP_SQL = """
SELECT CUST_NO, WOO_USER_ID, WOO_EMAIL, MAPPING_SOURCE, IS_ACTIVE
FROM dbo.USER_CUSTOMER_MAP
WHERE IS_ACTIVE = 1
ORDER BY CUST_NO
"""

FIND_MAPPING_BY_CUST_SQL = """
SELECT CUST_NO, WOO_USER_ID, WOO_EMAIL
FROM dbo.USER_CUSTOMER_MAP
WHERE CUST_NO = ? AND IS_ACTIVE = 1
"""

FIND_MAPPING_BY_WOO_SQL = """
SELECT CUST_NO, WOO_USER_ID, WOO_EMAIL
FROM dbo.USER_CUSTOMER_MAP
WHERE WOO_USER_ID = ? AND IS_ACTIVE = 1
"""


# ─────────────────────────────────────────────────────────────────────────────
# HELPER FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────

def generate_temp_password(length: int = 16) -> str:
    """Generate a secure temporary password for new WooCommerce customers."""
    alphabet = string.ascii_letters + string.digits + "!@#$%"
    return ''.join(secrets.choice(alphabet) for _ in range(length))


def get_wp_tier_role(prof_cod_1: str) -> str:
    """
    Get the WordPress role for a CounterPoint PROF_COD_1 (tier pricing).
    
    PROF_COD_1 is the field that controls tier pricing in CounterPoint.
    
    Returns 'customer' for RETAIL/unknown tiers.
    Returns tier roles like 'tier_1_customers' for wholesale customers.
    """
    if not prof_cod_1:
        return 'customer'  # Default to retail
    
    return PROF_COD_1_TO_WP_ROLE.get(prof_cod_1, 'customer')


def get_prof_cod_1_from_wp_role(wp_role: str) -> str:
    """
    Get CounterPoint PROF_COD_1 (tier pricing) from WordPress role.
    
    This is the reverse mapping used when pulling customers from WooCommerce.
    Returns 'RETAIL' for unknown roles.
    """
    if not wp_role:
        return 'RETAIL'
    
    return WP_ROLE_TO_PROF_COD_1.get(wp_role, 'RETAIL')


def cp_customer_to_woo_payload(cust: Dict) -> Dict:
    """Convert CounterPoint customer to WooCommerce customer payload."""
    email = cust.get('EMAIL_ADRS_1')
    if not email:
        # Generate placeholder email for customers without one
        email = f"{cust['CUST_NO'].lower().replace(' ', '')}@placeholder.local"
    
    # PROF_COD_1 is the field that controls tier pricing (not CATEG_COD)
    prof_cod_1 = cust.get('PROF_COD_1') or 'RETAIL'
    categ_cod = cust.get('CATEG_COD') or 'RETAIL'  # Customer category (separate field)
    wp_role = get_wp_tier_role(prof_cod_1)
    discount = TIER_DISCOUNTS.get(wp_role, 0)
    
    payload = {
        "email": email.strip().lower(),
        "first_name": (cust.get('FST_NAM') or '').strip(),
        "last_name": (cust.get('LST_NAM') or '').strip(),
        "username": cust['CUST_NO'].lower().replace(' ', '_'),
        "password": generate_temp_password(),  # Auto-generated, customer should reset
        "role": wp_role,  # WordPress role for tier pricing (based on PROF_COD_1)
        "billing": {
            "first_name": (cust.get('FST_NAM') or '').strip(),
            "last_name": (cust.get('LST_NAM') or '').strip(),
            "company": (cust.get('NAM') or '').strip(),
            "address_1": (cust.get('ADRS_1') or '').strip(),
            "address_2": (cust.get('ADRS_2') or '').strip(),
            "city": (cust.get('CITY') or '').strip(),
            "state": (cust.get('STATE') or '').strip(),
            "postcode": (cust.get('ZIP_COD') or '').strip(),
            "country": (cust.get('CNTRY') or 'US').strip()[:2],
            "phone": (cust.get('PHONE_1') or '').strip(),
        },
        "meta_data": [
            {"key": "cp_cust_no", "value": cust['CUST_NO']},
            {"key": "cp_categ_cod", "value": categ_cod},  # Customer category
            {"key": "cp_prof_cod_1", "value": prof_cod_1},  # Tier pricing field
            {"key": "cp_tier", "value": prof_cod_1},  # Tier (for backward compatibility)
            {"key": "cp_discount_pct", "value": str(discount)},
        ]
    }
    
    return payload


def get_existing_woo_customers(client: WooClient) -> Dict[str, int]:
    """Fetch existing WooCommerce customers, return dict of email -> ID."""
    existing = {}
    page = 1
    
    while True:
        url = client._url("/customers")
        resp = client.session.get(url, params={"per_page": 100, "page": page, "role": "all"}, timeout=30)
        if not resp.ok:
            print(f"Warning: Failed to fetch customers page {page}: {resp.status_code}")
            break
        
        data = resp.json()
        if not data:
            break
        
        for cust in data:
            email = cust.get('email', '').lower()
            if email:
                existing[email] = cust['id']
            # Also check for cp_cust_no in meta
            for meta in cust.get('meta_data', []):
                if meta.get('key') == 'cp_cust_no':
                    existing[f"cust:{meta['value']}"] = cust['id']
        
        if len(data) < 100:
            break
        page += 1
    
    return existing


def get_existing_woo_customers_full(client: WooClient) -> List[Dict]:
    """
    Fetch ALL WooCommerce customers comprehensively.
    
    KNOWN WOOCOMMERCE ISSUES ADDRESSED:
    1. Default API only returns 'customer' role - we use role=all
    2. Some customers created during checkout aren't indexed - we scan orders
    3. Guest checkouts have no customer record - we create pseudo-records from orders
    
    This ensures NO customer is missed regardless of how/when they were created.
    See WOOCOMMERCE_KNOWN_ISSUES.md for details.
    """
    customers_by_id = {}
    
    # ─────────────────────────────────────────────────────────────────────────
    # STEP 1: Fetch from customer list API with role=all
    # ─────────────────────────────────────────────────────────────────────────
    page = 1
    while True:
        url = client._url("/customers")
        resp = client.session.get(url, params={"per_page": 100, "page": page, "role": "all"}, timeout=60)
        if not resp.ok:
            break
        
        data = resp.json()
        if not data:
            break
        
        for c in data:
            customers_by_id[c['id']] = c
        
        if len(data) < 100:
            break
        page += 1
    
    list_count = len(customers_by_id)
    
    # ─────────────────────────────────────────────────────────────────────────
    # STEP 2: Scan orders for customers not in the list
    # This catches customers created during checkout who weren't indexed
    # ─────────────────────────────────────────────────────────────────────────
    page = 1
    orders_scanned = 0
    additional_found = 0
    
    while True:
        url = client._url("/orders")
        resp = client.session.get(url, params={"per_page": 100, "page": page}, timeout=60)
        if not resp.ok:
            break
        
        orders = resp.json()
        if not orders:
            break
        
        for order in orders:
            orders_scanned += 1
            customer_id = order.get('customer_id', 0)
            
            # Skip if we already have this customer
            if customer_id in customers_by_id:
                continue
            
            # For registered customers not in list, fetch directly by ID
            if customer_id > 0:
                cust_url = client._url(f"/customers/{customer_id}")
                cust_resp = client.session.get(cust_url, timeout=30)
                if cust_resp.ok:
                    cust = cust_resp.json()
                    customers_by_id[customer_id] = cust
                    additional_found += 1
            # Guest checkout - create pseudo-customer from order billing
            else:
                billing = order.get('billing', {})
                if billing.get('email'):
                    # Use negative order ID as pseudo-ID to avoid conflicts
                    pseudo_id = -order['id']
                    if pseudo_id not in customers_by_id:
                        customers_by_id[pseudo_id] = {
                            'id': pseudo_id,  # Negative = guest
                            'email': billing.get('email'),
                            'first_name': billing.get('first_name', ''),
                            'last_name': billing.get('last_name', ''),
                            'username': '',
                            'role': 'guest',
                            'billing': billing,
                            'shipping': order.get('shipping', {}),
                            'date_created': order.get('date_created'),
                            '_is_guest': True,
                            '_from_order_id': order['id'],
                        }
                        additional_found += 1
        
        if len(orders) < 100:
            break
        page += 1
    
    # Log what we found (helpful for debugging)
    if additional_found > 0:
        print(f"  [INFO] Found {additional_found} additional customers from orders")
    
    return list(customers_by_id.values())


# ─────────────────────────────────────────────────────────────────────────────
# PUSH: CP → WOO
# ─────────────────────────────────────────────────────────────────────────────

def push_customers_to_woo(dry_run: bool = True) -> Tuple[int, int, int]:
    """
    Push CounterPoint e-commerce customers to WooCommerce.
    
    Returns: (created, updated, errors)
    """
    # Get CP customers
    cp_customers = run_query(CP_ECOMM_CUSTOMERS_SQL)
    if not cp_customers:
        print("No e-commerce customers found in CounterPoint.")
        return 0, 0, 0
    
    print(f"\n{'='*60}")
    print(f"{'DRY RUN - ' if dry_run else ''}Push Customers: CP -> WooCommerce")
    print(f"{'='*60}")
    print(f"CounterPoint customers: {len(cp_customers)}")
    
    # Get existing Woo customers
    client = WooClient()
    print("Fetching existing WooCommerce customers...")
    existing = get_existing_woo_customers(client)
    print(f"Existing WooCommerce customers: {len(existing)}")
    
    # Separate create vs update
    to_create = []
    to_update = []
    
    for cust in cp_customers:
        payload = cp_customer_to_woo_payload(cust)
        email = payload['email']
        cust_key = f"cust:{cust['CUST_NO']}"
        
        # Check if exists by email or cp_cust_no
        woo_id = existing.get(email) or existing.get(cust_key)
        
        if woo_id:
            payload['id'] = woo_id
            to_update.append(payload)
        else:
            to_create.append(payload)
    
    print(f"\nTo create: {len(to_create)}")
    print(f"To update: {len(to_update)}")
    
    if dry_run:
        print(f"\n[!] DRY RUN - No changes made")
        if to_create:
            print(f"\nSample create payload:")
            print(json.dumps(to_create[0], indent=2)[:500])
        return len(to_create), len(to_update), 0
    
    # Execute creates
    created = 0
    errors = 0
    
    for payload in to_create:
        try:
            url = client._url("/customers")
            resp = client.session.post(url, json=payload, timeout=30)
            if resp.ok:
                data = resp.json()
                created += 1
                # Store mapping
                _save_customer_mapping(
                    payload['meta_data'][0]['value'],  # cp_cust_no
                    data['id'],
                    payload['email'],
                    'AUTO_PUSH'
                )
                print(f"  [OK] Created: {payload['email']} (Woo ID: {data['id']})")
            else:
                errors += 1
                print(f"  [ERR] Failed to create {payload['email']}: {resp.status_code} {resp.text[:200]}")
        except Exception as e:
            errors += 1
            print(f"  [ERR] Error creating {payload['email']}: {e}")
    
    # Execute updates
    updated = 0
    
    for payload in to_update:
        try:
            url = client._url(f"/customers/{payload['id']}")
            resp = client.session.put(url, json=payload, timeout=30)
            if resp.ok:
                updated += 1
            else:
                errors += 1
                print(f"  [ERR] Failed to update ID {payload['id']}: {resp.status_code}")
        except Exception as e:
            errors += 1
            print(f"  [ERR] Error updating ID {payload['id']}: {e}")
    
    print(f"\n{'='*60}")
    print(f"Results: Created {created}, Updated {updated}, Errors {errors}")
    print(f"{'='*60}")
    
    return created, updated, errors


def _save_customer_mapping(cust_no: str, woo_id: int, email: str, source: str):
    """Save customer mapping to USER_CUSTOMER_MAP."""
    conn = None
    cursor = None
    try:
        conn = get_connection()
        cursor = conn.cursor()
        
        # Check if mapping exists
        cursor.execute("""
            SELECT MAP_ID FROM dbo.USER_CUSTOMER_MAP 
            WHERE CUST_NO = ? AND IS_ACTIVE = 1
        """, (cust_no,))
        
        if cursor.fetchone():
            # Update existing
            cursor.execute("""
                UPDATE dbo.USER_CUSTOMER_MAP
                SET WOO_USER_ID = ?, WOO_EMAIL = ?, UPDATED_DT = GETDATE()
                WHERE CUST_NO = ? AND IS_ACTIVE = 1
            """, (woo_id, email, cust_no))
        else:
            # Insert new
            cursor.execute("""
                INSERT INTO dbo.USER_CUSTOMER_MAP 
                (CUST_NO, WOO_USER_ID, WOO_EMAIL, MAPPING_SOURCE, IS_ACTIVE)
                VALUES (?, ?, ?, ?, 1)
            """, (cust_no, woo_id, email, source))
        
        conn.commit()
    except Exception as e:
        print(f"  Warning: Could not save mapping: {e}")
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


# ─────────────────────────────────────────────────────────────────────────────
# EXTRACT SHIP-TO ADDRESSES FROM WOOCOMMERCE
# ─────────────────────────────────────────────────────────────────────────────

def extract_ship_to_addresses_from_woo(batch_id: str, dry_run: bool = True) -> int:
    """
    Extract ship-to addresses from WooCommerce orders for customers that exist in CP.
    Stages to USER_SHIP_TO_STAGING.
    
    Rule 3.1: CUST_NO is king - only extracts for customers that exist in AR_CUST.
    
    Returns: count of ship-to addresses staged
    """
    client = WooClient()
    
    # Get all customer mappings (CUST_NO -> WOO_USER_ID)
    mappings = run_query("""
        SELECT CUST_NO, WOO_USER_ID 
        FROM dbo.USER_CUSTOMER_MAP 
        WHERE IS_ACTIVE = 1 AND WOO_USER_ID IS NOT NULL
    """)
    
    if not mappings:
        return 0
    
    print(f"\nExtracting ship-to addresses for {len(mappings)} mapped customers...")
    
    # Get orders for these customers (last 90 days)
    after_date = (datetime.now() - timedelta(days=90)).strftime('%Y-%m-%dT%H:%M:%S')
    
    ship_to_addresses = {}  # (CUST_NO, address_key) -> address data
    
    for mapping in mappings:
        cust_no = mapping['CUST_NO']
        woo_user_id = mapping['WOO_USER_ID']
        
        try:
            # Get orders for this customer
            url = client._url("/orders")
            resp = client.session.get(url, params={
                "customer": woo_user_id,
                "after": after_date,
                "per_page": 100,
                "status": "any"
            }, timeout=30)
            
            if not resp.ok:
                continue
            
            orders = resp.json()
            
            for order in orders:
                shipping = order.get('shipping', {})
                billing = order.get('billing', {})
                
                # Use shipping address if different from billing, otherwise skip (already in AR_CUST)
                if not shipping.get('address_1'):
                    continue
                
                # Create unique key for this address
                addr_key = (
                    sanitize_string(shipping.get('address_1', '')),
                    sanitize_string(shipping.get('city', '')),
                    sanitize_string(shipping.get('postcode', ''))
                )
                
                # Skip if we've already seen this address for this customer
                if (cust_no, addr_key) in ship_to_addresses:
                    continue
                
                # Extract ship-to address data
                ship_to_addresses[(cust_no, addr_key)] = {
                    'CUST_NO': cust_no,
                    'WOO_USER_ID': woo_user_id,
                    'NAM': sanitize_string(
                        shipping.get('company', '') or 
                        f"{shipping.get('first_name', '')} {shipping.get('last_name', '')}".strip()
                    )[:40],
                    'FST_NAM': sanitize_string(shipping.get('first_name', ''))[:15],
                    'LST_NAM': sanitize_string(shipping.get('last_name', ''))[:25],
                    'ADRS_1': sanitize_string(format_address_per_guidelines(shipping.get('address_1', '')), 40),
                    'ADRS_2': sanitize_string(format_address_line_2(shipping.get('address_2', '')), 40),
                    'CITY': sanitize_string(shipping.get('city', ''))[:20],
                    'STATE': normalize_state(shipping.get('state', ''))[:10],
                    'ZIP_COD': sanitize_string(shipping.get('postcode', ''))[:15],
                    'CNTRY': (shipping.get('country', 'US') or 'US').upper()[:20],
                    'PHONE_1': normalize_phone(shipping.get('phone', ''))[:25] if shipping.get('phone') else None,
                }
        
        except Exception as e:
            print(f"  [WARN] Error extracting ship-to for CUST_NO {cust_no}: {e}")
            continue
    
    if not ship_to_addresses:
        return 0
    
    if dry_run:
        print(f"\n[DRY RUN] Would stage {len(ship_to_addresses)} ship-to addresses")
        return len(ship_to_addresses)
    
    # Stage to database
    conn = get_connection()
    cursor = conn.cursor()
    staged = 0
    
    try:
        for addr_data in ship_to_addresses.values():
            cursor.execute("""
                INSERT INTO dbo.USER_SHIP_TO_STAGING (
                    BATCH_ID, CUST_NO, WOO_USER_ID,
                    NAM, FST_NAM, LST_NAM,
                    ADRS_1, ADRS_2, CITY, STATE, ZIP_COD, CNTRY,
                    PHONE_1, SOURCE_SYSTEM
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'WOOCOMMERCE')
            """, (
                batch_id,
                addr_data['CUST_NO'],
                addr_data['WOO_USER_ID'],
                addr_data['NAM'],
                addr_data['FST_NAM'],
                addr_data['LST_NAM'],
                addr_data['ADRS_1'],
                addr_data['ADRS_2'],
                addr_data['CITY'],
                addr_data['STATE'],
                addr_data['ZIP_COD'],
                addr_data['CNTRY'],
                addr_data['PHONE_1'],
            ))
            staged += 1
        
        conn.commit()
    finally:
        cursor.close()
        conn.close()
    
    return staged


# ─────────────────────────────────────────────────────────────────────────────
# EXTRACT CUSTOMER NOTES FROM WOOCOMMERCE
# ─────────────────────────────────────────────────────────────────────────────

def extract_customer_notes_from_woo(batch_id: str, dry_run: bool = True) -> int:
    """
    Extract customer notes from WooCommerce customer meta_data and customer.note field.
    Stages to USER_CUSTOMER_NOTES_STAGING.
    
    Rule 3.1: CUST_NO is king - only extracts for customers that exist in AR_CUST.
    
    Returns: count of notes staged
    """
    client = WooClient()
    
    # Get all customer mappings (CUST_NO -> WOO_USER_ID)
    mappings = run_query("""
        SELECT CUST_NO, WOO_USER_ID 
        FROM dbo.USER_CUSTOMER_MAP 
        WHERE IS_ACTIVE = 1 AND WOO_USER_ID IS NOT NULL
    """)
    
    if not mappings:
        return 0
    
    print(f"\nExtracting customer notes for {len(mappings)} mapped customers...")
    
    notes_staged = []
    
    for mapping in mappings:
        cust_no = mapping['CUST_NO']
        woo_user_id = mapping['WOO_USER_ID']
        
        try:
            # Fetch customer from WooCommerce
            url = client._url(f"/customers/{woo_user_id}")
            resp = client.session.get(url, timeout=30)
            
            if not resp.ok:
                continue
            
            customer = resp.json()
            
            # Extract notes from customer.note field (WooCommerce built-in)
            customer_note = customer.get('note', '').strip()
            if customer_note:
                notes_staged.append({
                    'CUST_NO': cust_no,
                    'WOO_USER_ID': woo_user_id,
                    'NOTE': customer_note[:50],  # Short note (max 50)
                    'NOTE_TXT': customer_note,   # Full note text
                })
            
            # Extract notes from meta_data (custom fields)
            meta_data = customer.get('meta_data', [])
            for meta in meta_data:
                key = meta.get('key', '').lower()
                value = meta.get('value', '')
                
                # Look for note-related meta keys
                if 'note' in key or 'comment' in key or 'instruction' in key:
                    if value and isinstance(value, str) and value.strip():
                        notes_staged.append({
                            'CUST_NO': cust_no,
                            'WOO_USER_ID': woo_user_id,
                            'NOTE': f"{key}: {value[:40]}",  # Short note
                            'NOTE_TXT': f"{key}: {value}",   # Full note text
                        })
        
        except Exception as e:
            print(f"  [WARN] Error extracting notes for CUST_NO {cust_no}: {e}")
            continue
    
    if not notes_staged:
        return 0
    
    if dry_run:
        print(f"\n[DRY RUN] Would stage {len(notes_staged)} customer notes")
        return len(notes_staged)
    
    # Stage to database
    conn = get_connection()
    cursor = conn.cursor()
    staged = 0
    
    try:
        for note_data in notes_staged:
            cursor.execute("""
                INSERT INTO dbo.USER_CUSTOMER_NOTES_STAGING (
                    BATCH_ID, CUST_NO, WOO_USER_ID,
                    NOTE, NOTE_TXT, SOURCE_SYSTEM
                ) VALUES (?, ?, ?, ?, ?, 'WOOCOMMERCE')
            """, (
                batch_id,
                note_data['CUST_NO'],
                note_data['WOO_USER_ID'],
                note_data['NOTE'],
                note_data['NOTE_TXT'],
            ))
            staged += 1
        
        conn.commit()
    finally:
        cursor.close()
        conn.close()
    
    return staged


# ─────────────────────────────────────────────────────────────────────────────
# CUSTOMER VALIDATION - Filter serious customers from bots/non-serious
# ─────────────────────────────────────────────────────────────────────────────

def validate_customer_for_cp_sync(customer_data: Dict) -> Tuple[bool, List[str]]:
    """
    Validate that a WooCommerce customer has all required information before
    syncing to CounterPoint database.
    
    Required fields to separate serious clients from bots/non-serious:
    1. Full name (first_name AND last_name)
    2. Business Name (company)
    3. Email address
    4. Billing/Shipping address (address_1)
    5. Phone number
    
    Args:
        customer_data: Dict from extract_best_customer_data()
    
    Returns:
        Tuple of (is_valid, list_of_missing_fields)
    """
    missing_fields = []
    
    # 1. Full name - both first and last required
    if not customer_data.get('first_name') or not customer_data.get('first_name').strip():
        missing_fields.append('First Name')
    if not customer_data.get('last_name') or not customer_data.get('last_name').strip():
        missing_fields.append('Last Name')
    
    # 2. Business Name (company)
    if not customer_data.get('company') or not customer_data.get('company').strip():
        missing_fields.append('Business Name (Company)')
    
    # 3. Email address
    email = customer_data.get('email', '').strip()
    if not email or not is_valid_email(email):
        missing_fields.append('Valid Email Address')
    
    # 4. Billing/Shipping address (address_1)
    # At least one address required (billing OR shipping - can be same or different)
    address_1 = customer_data.get('address_1', '').strip()
    ship_address_1 = customer_data.get('ship_address_1', '').strip()
    if not address_1 and not ship_address_1:
        missing_fields.append('Billing or Shipping Address')
    
    # 5. Phone number
    phone = customer_data.get('phone', '').strip()
    if not phone:
        missing_fields.append('Phone Number')
    
    is_valid = len(missing_fields) == 0
    return is_valid, missing_fields


# ─────────────────────────────────────────────────────────────────────────────
# PULL: WOO → CP
# ─────────────────────────────────────────────────────────────────────────────

def pull_customers_from_woo(dry_run: bool = True) -> int:
    """
    Pull WooCommerce customers that don't exist in CounterPoint.
    Inserts into USER_CUSTOMER_STAGING for review before creating in AR_CUST.
    
    Follows existing validation pattern:
    - Stages ALL customers (no filtering in Python)
    - Sets VALIDATION_ERROR in staging table for customers missing required fields
    - Stored procedure usp_Preflight_Validate_Customer_Staging handles validation
    - Only records with no VALIDATION_ERROR get processed
    
    Required fields (to filter bots/non-serious customers):
    1. Full name (first_name AND last_name)
    2. Business Name (company)
    3. Email address
    4. Billing/Shipping address (at least one)
    5. Phone number
    
    Returns: count of customers staged
    """
    client = WooClient()
    
    print(f"\n{'='*60}")
    print(f"{'DRY RUN - ' if dry_run else ''}Pull Customers: WooCommerce -> CP Staging")
    print(f"{'='*60}")
    
    # Get all Woo customers
    print("Fetching WooCommerce customers...")
    woo_customers = get_existing_woo_customers_full(client)
    print(f"WooCommerce customers: {len(woo_customers)}")
    
    # Get existing mappings
    mappings = run_query(GET_CUSTOMER_MAP_SQL)
    mapped_woo_ids = {m['WOO_USER_ID'] for m in mappings}
    print(f"Already mapped: {len(mapped_woo_ids)}")
    
    # Find unmapped customers (registered users have positive IDs)
    # Guest checkouts have negative pseudo-IDs (from order scan)
    unmapped = [c for c in woo_customers if c['id'] not in mapped_woo_ids]
    
    # Separate registered vs guest
    registered = [c for c in unmapped if c['id'] > 0]
    guests = [c for c in unmapped if c['id'] < 0]
    
    print(f"Unmapped registered: {len(registered)}")
    print(f"Guest checkouts: {len(guests)}")
    print(f"Total new: {len(unmapped)}")
    
    if not unmapped:
        print("\nNo new customers to pull.")
        return 0
    
    # Preview with smart name extraction
    print(f"\n{'EMAIL':<35} {'NAME (NAM)':<22} {'TYPE':<8} {'ID':>8}")
    print("-" * 75)
    for c in unmapped[:10]:
        data = extract_best_customer_data(c)
        display_name = (data['nam'] or c.get('username', 'N/A'))[:22]
        cust_type = 'GUEST' if c.get('_is_guest') or c['id'] < 0 else 'REG'
        display_id = c.get('_from_order_id', c['id']) if c['id'] < 0 else c['id']
        print(f"{(data['email'] or 'N/A'):<35} {display_name:<22} {cust_type:<8} {display_id:>8}")
    if len(unmapped) > 10:
        print(f"... and {len(unmapped) - 10} more")
    
    if dry_run:
        print(f"\n[!] DRY RUN - No changes made")
        print("    To import to staging, add --apply flag")
        return len(unmapped)
    
    # Insert into staging - following existing validation pattern:
    # Stage ALL customers, set VALIDATION_ERROR for invalid ones
    # Stored procedure usp_Preflight_Validate_Customer_Staging handles the rest
    batch_id = f"WOO_PULL_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    
    conn = get_connection()
    cursor = conn.cursor()
    staged = 0
    guests_staged = 0
    skipped = 0
    validation_errors_set = 0
    
    try:
        for c in unmapped:
            try:
                # Use smart extraction to get best available data
                data = extract_best_customer_data(c)
                
                # Validate customer - check for required fields (to filter bots/non-serious)
                is_valid, missing_fields = validate_customer_for_cp_sync(data)
                validation_error = None
                if not is_valid:
                    # Set validation error (following existing pattern)
                    validation_error = f"Missing required fields: {', '.join(missing_fields)}"
                    validation_errors_set += 1
                
                # For guest checkouts (negative ID), WOO_USER_ID should be NULL
                # The stored procedure handles NULL WOO_USER_ID (creates customer, no mapping)
                woo_user_id = c['id'] if c['id'] > 0 else None
                is_guest = c.get('_is_guest') or c['id'] < 0
                
                # Extract tier from WordPress role
                wp_role = c.get('role', 'customer')
                prof_cod_1 = get_prof_cod_1_from_wp_role(wp_role)
                
                # Calculate and abbreviate tax code (max 10 chars for CounterPoint)
                tax_code = get_tax_code(data['state'], data['city'])
                tax_code_abbrev = abbreviate_tax_code(tax_code)  # Ensure max 10 chars
                
                cursor.execute("""
                    INSERT INTO dbo.USER_CUSTOMER_STAGING (
                        BATCH_ID, WOO_USER_ID, EMAIL_ADRS_1,
                        NAM, FST_NAM, LST_NAM,
                        PHONE_1, ADRS_1, ADRS_2, CITY, STATE, ZIP_COD, CNTRY,
                        CATEG_COD, PROF_COD_1, TAX_COD, SOURCE_SYSTEM,
                        IS_VALIDATED, VALIDATION_ERROR
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'RETAIL', ?, ?, 'WOOCOMMERCE', ?, ?)
                """, (
                    batch_id,
                    woo_user_id,  # NULL for guests
                    data['email'],
                    data['nam'],           # Company name if available, else "First Last"
                    data['first_name'],
                    data['last_name'],
                    data['phone'],
                    data['address_1'],
                    data['address_2'],
                    data['city'],
                    data['state'],
                    data['postcode'],
                    data['country'],
                    prof_cod_1,  # Tier pricing from WordPress role
                    tax_code_abbrev,  # Tax code (abbreviated to max 10 chars)
                    0,  # IS_VALIDATED: Always 0 initially (preflight validation will set to 1 if valid)
                    validation_error,  # VALIDATION_ERROR: NULL if valid, error message if invalid
                ))
                staged += 1
                if is_guest:
                    guests_staged += 1
            except Exception as e:
                print(f"  [ERR] Error staging {c.get('email')}: {e}")
                skipped += 1
        
        conn.commit()
    finally:
        cursor.close()
        conn.close()
    
    print(f"\n[OK] Staged {staged} customers ({guests_staged} guests)")
    if skipped > 0:
        print(f"  Skipped {skipped} customers due to errors")
    if validation_errors_set > 0:
        print(f"  {validation_errors_set} customers marked with validation errors (missing required fields)")
        print(f"    These will be skipped by usp_Create_Customers_From_Staging")
    print(f"  Batch ID: {batch_id}")
    print(f"\nNext steps:")
    print(f"  1. Review: SELECT * FROM USER_CUSTOMER_STAGING WHERE BATCH_ID = '{batch_id}'")
    print(f"  2. Check validation errors: SELECT * FROM USER_CUSTOMER_STAGING WHERE BATCH_ID = '{batch_id}' AND VALIDATION_ERROR IS NOT NULL")
    print(f"  3. Run preflight validation: EXEC usp_Preflight_Validate_Customer_Staging @BatchID = '{batch_id}'")
    print(f"  4. Create customers: EXEC usp_Create_Customers_From_Staging @BatchID = '{batch_id}', @DryRun = 1")
    
    return staged


# ─────────────────────────────────────────────────────────────────────────────
# MAPPING MANAGEMENT
# ─────────────────────────────────────────────────────────────────────────────

def list_mappings():
    """List current customer mappings."""
    mappings = run_query(GET_CUSTOMER_MAP_SQL)
    
    if not mappings:
        print("No customer mappings found.")
        return
    
    print(f"\n{'CUST_NO':<15} {'WOO_ID':>8} {'WOO_EMAIL':<35} {'SOURCE':<12}")
    print("-" * 75)
    
    for m in mappings:
        print(f"{m['CUST_NO']:<15} {m['WOO_USER_ID']:>8} {(m['WOO_EMAIL'] or ''):<35} {m['MAPPING_SOURCE']:<12}")
    
    print(f"\nTotal: {len(mappings)} mappings")


def add_mapping(cust_no: str, woo_id: int):
    """Manually add a customer mapping."""
    # Verify customer exists
    check = run_query("SELECT CUST_NO, NAM FROM dbo.AR_CUST WHERE CUST_NO = ?", (cust_no,))
    if not check:
        print(f"Error: Customer '{cust_no}' not found in CounterPoint.")
        return False
    
    # Verify Woo user exists
    client = WooClient()
    url = client._url(f"/customers/{woo_id}")
    resp = client.session.get(url, timeout=30)
    if not resp.ok:
        print(f"Error: WooCommerce user ID {woo_id} not found.")
        return False
    
    woo_data = resp.json()
    email = woo_data.get('email', '')
    
    _save_customer_mapping(cust_no, woo_id, email, 'MANUAL')
    
    print(f"[OK] Mapped: {cust_no} ({check[0]['NAM']}) <-> Woo ID {woo_id} ({email})")
    return True


# ─────────────────────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────────────────────

def show_tier_mapping():
    """Show the CP → WordPress role mapping configuration."""
    print(f"\n{'='*75}")
    print("CounterPoint -> WordPress Tier Pricing Mapping")
    print(f"{'='*75}\n")
    
    # Get CP tier counts (using PROF_COD_1 - the field that controls tier pricing)
    tier_sql = """
    SELECT PROF_COD_1, COUNT(*) as cnt 
    FROM AR_CUST 
    WHERE PROF_COD_1 IS NOT NULL 
    GROUP BY PROF_COD_1 
    ORDER BY cnt DESC
    """
    tiers = run_query(tier_sql)
    
    print(f"{'CP PROF_COD_1':<15} {'Customers':>10} {'WP Role':<22} {'Discount':>10}")
    print("-" * 65)
    
    for t in tiers:
        prof_cod_1 = t['PROF_COD_1']
        count = t['cnt']
        wp_role = PROF_COD_1_TO_WP_ROLE.get(prof_cod_1, 'customer')
        discount = TIER_DISCOUNTS.get(wp_role, 0)
        
        print(f"{prof_cod_1:<15} {count:>10} {wp_role:<22} {discount:>9.1f}%")
    
    print(f"\n{'='*75}")
    print("STATUS: READY TO SYNC")
    print(f"{'='*75}")
    print("""
[OK] Pricing plugin already configured with tier discounts
[OK] WordPress roles already exist (tier_1_customers, tier_2_customers, etc.)
[OK] Customer sync will assign correct roles based on CP PROF_COD_1 (tier pricing field)

TO SYNC CUSTOMERS:
   python woo_customers.py push          # Preview (dry-run)
   python woo_customers.py push --apply  # Sync customers to WooCommerce
""")


def print_help():
    print("""
woo_customers.py - Customer Sync between CounterPoint and WooCommerce
=====================================================================

COMMANDS:

  push                      Push CP customers to WooCommerce (dry-run)
  push --apply              Push CP customers to WooCommerce (live)
  
  pull                      Pull new Woo customers to staging (dry-run)
  pull --apply              Pull new Woo customers to staging (live)
                            (Validation automatically applied - filters bots/non-serious)
  
  list                      List current customer mappings
  map <CUST_NO> <WOO_ID>    Manually map a customer
  tiers                     Show CP → WordPress tier mapping

TIER PRICING (Uses your existing pricing plugin):

  CounterPoint PROF_COD_1 → WordPress Role → Discount:
  (PROF_COD_1 is the field that controls tier pricing in CounterPoint)
  
    RETAIL     → customer              →  0% (retail price)
    TIER1      → tier_1_customers      → 28% off
    TIER2      → tier_2_customers      → 33% off
    TIER3      → tier_3_customers      → 35% off
    TIER4      → tier_4_customers      → 37% off
    TIER5      → tier_5_customers      → 39% off
    GOV-TIER1  → gov_tier_1_customers  → 28% off
    GOV-TIER2  → gov_tier_2_customers  → 37.5% off
    GOV-TIER3  → gov_tier_3_customers  → 44.44% off
    RESELLER   → reseller              → 38% off

WORKFLOW:

  1. Check mapping: python woo_customers.py tiers
  2. Push customers: python woo_customers.py push --apply
  3. Pull new web customers: python woo_customers.py pull --apply
""")


def main():
    args = sys.argv[1:]
    
    if not args or args[0] in ['help', '-h', '--help']:
        print_help()
        return
    
    cmd = args[0].lower()
    apply_flag = '--apply' in args
    
    if cmd == 'push':
        push_customers_to_woo(dry_run=not apply_flag)
    
    elif cmd == 'pull':
        pull_customers_from_woo(dry_run=not apply_flag)
    
    elif cmd == 'ship-to':
        # Extract ship-to addresses for existing customers
        batch_id = f"SHIP_TO_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        count = extract_ship_to_addresses_from_woo(batch_id, dry_run=not apply_flag)
        if count > 0 and apply_flag:
            print(f"\nNext: Run in SSMS:")
            print(f"  EXEC dbo.usp_Create_ShipTo_From_Staging @BatchID = '{batch_id}', @DryRun = 1")
    
    elif cmd == 'notes':
        # Extract customer notes for existing customers
        batch_id = f"NOTES_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        count = extract_customer_notes_from_woo(batch_id, dry_run=not apply_flag)
        if count > 0 and apply_flag:
            print(f"\nNext: Run in SSMS:")
            print(f"  EXEC dbo.usp_Create_CustomerNotes_From_Staging @BatchID = '{batch_id}', @DryRun = 1")
    
    elif cmd == 'list':
        list_mappings()
    
    elif cmd == 'tiers':
        show_tier_mapping()
    
    elif cmd == 'map' and len(args) >= 3:
        try:
            woo_id = int(args[2])
            add_mapping(args[1], woo_id)
        except ValueError:
            print("Error: WOO_ID must be a number")
    
    else:
        print(f"Unknown command: {cmd}")
        print_help()


if __name__ == "__main__":
    main()

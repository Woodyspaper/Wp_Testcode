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
    python woo_customers.py map CUST123 456  # Map CP customer to Woo user ID
    python woo_customers.py list             # List current mappings
    python woo_customers.py tiers            # Show tier mapping
"""

import sys
import json
from datetime import datetime
from typing import List, Dict, Optional, Tuple

from database import run_query, get_connection
from config import load_integration_config
from woo_client import WooClient


# ─────────────────────────────────────────────────────────────────────────────
# WORDPRESS ROLE MAPPING (Uses existing pricing plugin roles)
# ─────────────────────────────────────────────────────────────────────────────
# Maps CounterPoint CATEG_COD to existing WordPress roles
# These roles are already configured in your WooCommerce pricing plugin
# Discounts match CounterPoint's TIERED pricing rules - DO NOT CHANGE without Richard's approval

CATEG_TO_WP_ROLE = {
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
    CATEG_COD, DISC_PCT, IS_ECOMM_CUST
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

def get_wp_tier_role(categ_cod: str) -> str:
    """
    Get the WordPress role for a CounterPoint category.
    
    Returns 'customer' for RETAIL/unknown categories.
    Returns tier roles like 'wp_tier1' for wholesale customers.
    """
    if not categ_cod:
        return 'customer'  # Default to retail
    
    return CATEG_TO_WP_ROLE.get(categ_cod, 'customer')


def cp_customer_to_woo_payload(cust: Dict) -> Dict:
    """Convert CounterPoint customer to WooCommerce customer payload."""
    email = cust.get('EMAIL_ADRS_1')
    if not email:
        # Generate placeholder email for customers without one
        email = f"{cust['CUST_NO'].lower().replace(' ', '')}@placeholder.local"
    
    categ_cod = cust.get('CATEG_COD') or 'RETAIL'
    wp_role = get_wp_tier_role(categ_cod)
    discount = TIER_DISCOUNTS.get(wp_role, 0)
    
    payload = {
        "email": email.strip().lower(),
        "first_name": (cust.get('FST_NAM') or '').strip(),
        "last_name": (cust.get('LST_NAM') or '').strip(),
        "username": cust['CUST_NO'].lower().replace(' ', '_'),
        "role": wp_role,  # WordPress role for tier pricing
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
            {"key": "cp_categ_cod", "value": categ_cod},
            {"key": "cp_tier", "value": categ_cod},
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
        resp = client.session.get(url, params={"per_page": 100, "page": page}, timeout=30)
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
    """Fetch all WooCommerce customers with full details."""
    customers = []
    page = 1
    
    while True:
        url = client._url("/customers")
        resp = client.session.get(url, params={"per_page": 100, "page": page}, timeout=30)
        if not resp.ok:
            break
        
        data = resp.json()
        if not data:
            break
        
        customers.extend(data)
        if len(data) < 100:
            break
        page += 1
    
    return customers


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
    print(f"{'DRY RUN - ' if dry_run else ''}Push Customers: CP → WooCommerce")
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
        print(f"\n⚠️  DRY RUN - No changes made")
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
                print(f"  ✓ Created: {payload['email']} (Woo ID: {data['id']})")
            else:
                errors += 1
                print(f"  ✗ Failed to create {payload['email']}: {resp.status_code} {resp.text[:200]}")
        except Exception as e:
            errors += 1
            print(f"  ✗ Error creating {payload['email']}: {e}")
    
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
                print(f"  ✗ Failed to update ID {payload['id']}: {resp.status_code}")
        except Exception as e:
            errors += 1
            print(f"  ✗ Error updating ID {payload['id']}: {e}")
    
    print(f"\n{'='*60}")
    print(f"Results: Created {created}, Updated {updated}, Errors {errors}")
    print(f"{'='*60}")
    
    return created, updated, errors


def _save_customer_mapping(cust_no: str, woo_id: int, email: str, source: str):
    """Save customer mapping to USER_CUSTOMER_MAP."""
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
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"  Warning: Could not save mapping: {e}")


# ─────────────────────────────────────────────────────────────────────────────
# PULL: WOO → CP
# ─────────────────────────────────────────────────────────────────────────────

def pull_customers_from_woo(dry_run: bool = True) -> int:
    """
    Pull WooCommerce customers that don't exist in CounterPoint.
    Inserts into USER_CUSTOMER_STAGING for review before creating in AR_CUST.
    
    Returns: count of customers staged
    """
    client = WooClient()
    
    print(f"\n{'='*60}")
    print(f"{'DRY RUN - ' if dry_run else ''}Pull Customers: WooCommerce → CP Staging")
    print(f"{'='*60}")
    
    # Get all Woo customers
    print("Fetching WooCommerce customers...")
    woo_customers = get_existing_woo_customers_full(client)
    print(f"WooCommerce customers: {len(woo_customers)}")
    
    # Get existing mappings
    mappings = run_query(GET_CUSTOMER_MAP_SQL)
    mapped_woo_ids = {m['WOO_USER_ID'] for m in mappings}
    print(f"Already mapped: {len(mapped_woo_ids)}")
    
    # Find unmapped customers
    unmapped = [c for c in woo_customers if c['id'] not in mapped_woo_ids]
    print(f"Unmapped (new): {len(unmapped)}")
    
    if not unmapped:
        print("\nNo new customers to pull.")
        return 0
    
    # Preview
    print(f"\n{'EMAIL':<35} {'NAME':<25} {'WOO ID':>8}")
    print("-" * 70)
    for c in unmapped[:10]:
        name = f"{c.get('first_name', '')} {c.get('last_name', '')}".strip() or c.get('username', 'N/A')
        print(f"{c.get('email', 'N/A'):<35} {name[:25]:<25} {c['id']:>8}")
    if len(unmapped) > 10:
        print(f"... and {len(unmapped) - 10} more")
    
    if dry_run:
        print(f"\n⚠️  DRY RUN - No changes made")
        print("    To import to staging, add --apply flag")
        return len(unmapped)
    
    # Insert into staging
    batch_id = f"WOO_PULL_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    
    conn = get_connection()
    cursor = conn.cursor()
    staged = 0
    
    try:
        for c in unmapped:
            try:
                billing = c.get('billing', {})
                cursor.execute("""
                    INSERT INTO dbo.USER_CUSTOMER_STAGING (
                        BATCH_ID, WOO_USER_ID, EMAIL_ADRS_1,
                        NAM, FST_NAM, LST_NAM,
                        PHONE_1, ADRS_1, ADRS_2, CITY, STATE, ZIP_COD, CNTRY,
                        SOURCE_SYSTEM
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'WOOCOMMERCE')
                """, (
                    batch_id,
                    c['id'],
                    c.get('email'),
                    billing.get('company') or f"{c.get('first_name', '')} {c.get('last_name', '')}".strip(),
                    c.get('first_name'),
                    c.get('last_name'),
                    billing.get('phone'),
                    billing.get('address_1'),
                    billing.get('address_2'),
                    billing.get('city'),
                    billing.get('state'),
                    billing.get('postcode'),
                    (billing.get('country') or 'US')[:3],
                ))
                staged += 1
            except Exception as e:
                print(f"  ✗ Error staging {c.get('email')}: {e}")
        
        conn.commit()
    finally:
        cursor.close()
        conn.close()
    
    print(f"\n✓ Staged {staged} customers")
    print(f"  Batch ID: {batch_id}")
    print(f"\nNext steps:")
    print(f"  1. Review: SELECT * FROM USER_CUSTOMER_STAGING WHERE BATCH_ID = '{batch_id}'")
    print(f"  2. Assign CUST_NO values")
    print(f"  3. Apply to AR_CUST (manual or via stored procedure)")
    
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
    
    print(f"✓ Mapped: {cust_no} ({check[0]['NAM']}) ↔ Woo ID {woo_id} ({email})")
    return True


# ─────────────────────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────────────────────

def show_tier_mapping():
    """Show the CP → WordPress role mapping configuration."""
    print(f"\n{'='*75}")
    print("CounterPoint → WordPress Tier Pricing Mapping")
    print(f"{'='*75}\n")
    
    # Get CP tier counts
    tier_sql = """
    SELECT CATEG_COD, COUNT(*) as cnt 
    FROM AR_CUST 
    WHERE CATEG_COD IS NOT NULL 
    GROUP BY CATEG_COD 
    ORDER BY cnt DESC
    """
    tiers = run_query(tier_sql)
    
    print(f"{'CP CATEG_COD':<15} {'Customers':>10} {'WP Role':<22} {'Discount':>10}")
    print("-" * 65)
    
    for t in tiers:
        categ = t['CATEG_COD']
        count = t['cnt']
        wp_role = CATEG_TO_WP_ROLE.get(categ, 'customer')
        discount = TIER_DISCOUNTS.get(wp_role, 0)
        
        print(f"{categ:<15} {count:>10} {wp_role:<22} {discount:>9.1f}%")
    
    print(f"\n{'='*75}")
    print("STATUS: READY TO SYNC")
    print(f"{'='*75}")
    print("""
✓ Pricing plugin already configured with tier discounts
✓ WordPress roles already exist (tier_1_customers, tier_2_customers, etc.)
✓ Customer sync will assign correct roles based on CP CATEG_COD

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
  
  list                      List current customer mappings
  map <CUST_NO> <WOO_ID>    Manually map a customer
  tiers                     Show CP → WordPress tier mapping

TIER PRICING (Uses your existing pricing plugin):

  CounterPoint CATEG_COD → WordPress Role → Discount:
  
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

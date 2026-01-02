"""
woo_orders.py - Pull WooCommerce orders into CounterPoint staging

This pulls orders from WooCommerce and stages them for import into CounterPoint.
Orders go into USER_ORDER_STAGING for review before creating in PS_DOC_HDR.

Usage:
    python woo_orders.py list                  # List recent Woo orders
    python woo_orders.py pull                  # Pull new orders to staging (dry-run)
    python woo_orders.py pull --apply          # Pull new orders to staging (live)
    python woo_orders.py pull --days 7         # Pull orders from last 7 days
    python woo_orders.py status 12345          # Check status of a specific order
"""

import sys
import json
from datetime import datetime, timedelta
from typing import List, Dict, Optional, Tuple

from database import run_query, get_connection
from woo_client import WooClient
from data_utils import (
    sanitize_string, sanitize_amount, normalize_phone,
    normalize_state, split_long_address, normalize_sku,
    validate_email, convert_woo_date_to_local, FIELD_LIMITS,
)


# ─────────────────────────────────────────────────────────────────────────────
# SQL QUERIES
# ─────────────────────────────────────────────────────────────────────────────

FIND_STAGED_ORDER_SQL = """
SELECT STAGING_ID, WOO_ORDER_ID, CUST_NO, TOT_AMT, IS_APPLIED, CP_DOC_ID
FROM dbo.USER_ORDER_STAGING
WHERE WOO_ORDER_ID = ?
"""

CHECK_DUPLICATE_ORDER_SQL = """
SELECT 
    s.STAGING_ID,
    s.WOO_ORDER_ID,
    s.WOO_ORDER_NO,
    s.IS_APPLIED,
    s.CP_DOC_ID,
    s.CREATED_DT,
    CASE 
        WHEN s.IS_APPLIED = 1 AND s.CP_DOC_ID IS NOT NULL THEN 'COMPLETED'
        WHEN s.IS_APPLIED = 1 THEN 'APPLIED'
        WHEN s.IS_VALIDATED = 1 THEN 'VALIDATED'
        ELSE 'PENDING'
    END AS STATUS
FROM dbo.USER_ORDER_STAGING s
WHERE s.WOO_ORDER_ID = ? OR s.WOO_ORDER_NO = ?
"""

FIND_CUSTOMER_BY_EMAIL_SQL = """
SELECT CUST_NO, NAM FROM dbo.AR_CUST WHERE EMAIL_ADRS_1 = ?
"""

FIND_ITEM_BY_SKU_SQL = """
SELECT ITEM_NO, DESCR, STAT FROM dbo.IM_ITEM WHERE ITEM_NO = ?
"""

FIND_ITEMS_BY_SKUS_SQL = """
SELECT ITEM_NO, DESCR, STAT FROM dbo.IM_ITEM WHERE ITEM_NO IN ({placeholders})
"""

FIND_CUSTOMER_BY_WOO_ID_SQL = """
SELECT m.CUST_NO, c.NAM 
FROM dbo.USER_CUSTOMER_MAP m
JOIN dbo.AR_CUST c ON c.CUST_NO = m.CUST_NO
WHERE m.WOO_USER_ID = ? AND m.IS_ACTIVE = 1
"""

GET_RECENT_STAGED_ORDERS_SQL = """
SELECT TOP 50
    WOO_ORDER_ID, CUST_NO, CUST_EMAIL, ORD_DAT, ORD_STATUS,
    TOT_AMT, IS_VALIDATED, IS_APPLIED, CP_DOC_ID, VALIDATION_ERROR
FROM dbo.USER_ORDER_STAGING
ORDER BY CREATED_DT DESC
"""


# ─────────────────────────────────────────────────────────────────────────────
# HELPER FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────

def check_duplicate_order(woo_order_id: int, woo_order_no: str = None) -> Optional[Dict]:
    """
    Check if an order has already been staged or processed.
    
    Returns:
        Dict with duplicate info if found, None otherwise
        
    Duplicate info includes:
    - staging_id: Existing staging record ID
    - status: 'PENDING', 'VALIDATED', 'APPLIED', 'COMPLETED'
    - cp_doc_id: CounterPoint document ID (if applied)
    - created_dt: When the staging record was created
    """
    result = run_query(
        CHECK_DUPLICATE_ORDER_SQL, 
        (woo_order_id, woo_order_no or str(woo_order_id)),
        suppress_errors=True
    )
    
    if result and len(result) > 0:
        r = result[0]
        return {
            'staging_id': r['STAGING_ID'],
            'woo_order_id': r['WOO_ORDER_ID'],
            'status': r['STATUS'],
            'cp_doc_id': r['CP_DOC_ID'],
            'created_dt': r['CREATED_DT'],
            'is_duplicate': True
        }
    
    return None


def validate_order_skus(line_items: List[Dict]) -> Tuple[List[Dict], List[str]]:
    """
    Validate SKUs in order line items against CounterPoint IM_ITEM.
    
    Returns:
        Tuple of (validated_items, warnings)
        
    Each validated item includes:
    - cp_item_no: matched CounterPoint ITEM_NO (or None)
    - cp_item_descr: CounterPoint item description
    - cp_item_stat: Item status (A=Active, D=Discontinued, etc.)
    - sku_match_status: 'MATCHED', 'NOT_FOUND', 'DISCONTINUED', 'NO_SKU'
    """
    if not line_items:
        return [], []
    
    # Collect all SKUs that need validation
    skus_to_check = [item['sku'] for item in line_items if item.get('sku')]
    
    if not skus_to_check:
        # All items missing SKUs
        return [
            {**item, 'cp_item_no': None, 'cp_item_descr': None, 
             'cp_item_stat': None, 'sku_match_status': 'NO_SKU'}
            for item in line_items
        ], ['All line items are missing SKUs']
    
    # Query CounterPoint for all SKUs at once
    placeholders = ','.join(['?' for _ in skus_to_check])
    query = FIND_ITEMS_BY_SKUS_SQL.format(placeholders=placeholders)
    
    try:
        results = run_query(query, tuple(skus_to_check), suppress_errors=True)
        cp_items = {r['ITEM_NO']: r for r in results} if results else {}
    except Exception:
        cp_items = {}
    
    warnings = []
    validated = []
    
    for item in line_items:
        sku = item.get('sku', '')
        
        if not sku:
            validated.append({
                **item,
                'cp_item_no': None,
                'cp_item_descr': None,
                'cp_item_stat': None,
                'sku_match_status': 'NO_SKU'
            })
            warnings.append(f"Item '{item.get('name', 'Unknown')}' has no SKU")
            continue
        
        if sku in cp_items:
            cp_item = cp_items[sku]
            status = 'MATCHED' if cp_item['STAT'] == 'A' else 'DISCONTINUED'
            
            if status == 'DISCONTINUED':
                warnings.append(f"SKU '{sku}' is discontinued in CounterPoint")
            
            validated.append({
                **item,
                'cp_item_no': cp_item['ITEM_NO'],
                'cp_item_descr': cp_item['DESCR'],
                'cp_item_stat': cp_item['STAT'],
                'sku_match_status': status
            })
        else:
            validated.append({
                **item,
                'cp_item_no': None,
                'cp_item_descr': None,
                'cp_item_stat': None,
                'sku_match_status': 'NOT_FOUND'
            })
            warnings.append(f"SKU '{sku}' not found in CounterPoint (item: {item.get('name', 'Unknown')})")
    
    return validated, warnings


def resolve_customer(woo_order: Dict) -> Optional[str]:
    """
    Try to resolve WooCommerce order to CounterPoint customer.
    
    Resolution order:
    1. Check USER_CUSTOMER_MAP by Woo customer ID
    2. Check AR_CUST by billing email
    3. Return None if not found
    """
    # Try by Woo customer ID
    woo_cust_id = woo_order.get('customer_id')
    if woo_cust_id and woo_cust_id > 0:
        result = run_query(FIND_CUSTOMER_BY_WOO_ID_SQL, (woo_cust_id,), suppress_errors=True)
        if result:
            return result[0]['CUST_NO']
    
    # Try by email
    billing = woo_order.get('billing', {})
    email = billing.get('email')
    if email:
        result = run_query(FIND_CUSTOMER_BY_EMAIL_SQL, (email,), suppress_errors=True)
        if result:
            return result[0]['CUST_NO']
    
    return None


def woo_order_to_staging(order: Dict) -> Dict:
    """
    Convert WooCommerce order to staging table format.
    
    Applies:
    - String sanitization for all text fields
    - Amount sanitization for monetary values
    - Address overflow handling
    - Phone normalization
    - SKU normalization for line items
    - Timezone conversion: WooCommerce UTC → local time (per sync-invariants.md #7)
    
    Date Fields:
    - ORD_DAT: Local date only (YYYY-MM-DD) for CounterPoint
    - ORD_DAT_UTC: Original UTC datetime for audit trail
    - ORD_DATETIME_LOCAL: Full local datetime for precision matching
    """
    billing = order.get('billing', {})
    shipping = order.get('shipping', {})
    
    # Use shipping address if different from billing
    ship = shipping if shipping.get('address_1') else billing
    
    # ─────────────────────────────────────────────────────────────────────────
    # LINE ITEMS: Normalize SKUs for CounterPoint matching
    # ─────────────────────────────────────────────────────────────────────────
    line_items = []
    sku_warnings = []
    
    for item in order.get('line_items', []):
        raw_sku = item.get('sku', '')
        normalized_sku = normalize_sku(raw_sku)
        
        # Track SKU issues
        if not normalized_sku:
            sku_warnings.append(f"Line item '{item.get('name', 'Unknown')}' has no SKU")
        
        line_items.append({
            'sku': normalized_sku,
            'sku_original': raw_sku,  # Keep original for troubleshooting
            'name': sanitize_string(item.get('name', ''), 100),
            'quantity': int(item.get('quantity', 0)),
            'price': sanitize_amount(item.get('price')),
            'total': sanitize_amount(item.get('total')),
            'product_id': item.get('product_id'),
        })
    
    # ─────────────────────────────────────────────────────────────────────────
    # SHIP_NAM: Prioritize company name for B2B
    # ─────────────────────────────────────────────────────────────────────────
    ship_company = sanitize_string(ship.get('company', ''))
    ship_first = sanitize_string(ship.get('first_name', ''))
    ship_last = sanitize_string(ship.get('last_name', ''))
    ship_contact = f"{ship_first} {ship_last}".strip()
    
    if ship_company:
        ship_nam = ship_company[:40]
    else:
        ship_nam = ship_contact[:40]
    
    # ─────────────────────────────────────────────────────────────────────────
    # PHONE: normalize, check both billing and shipping
    # ─────────────────────────────────────────────────────────────────────────
    raw_phone = billing.get('phone', '').strip() or shipping.get('phone', '').strip()
    phone = normalize_phone(raw_phone)
    
    # ─────────────────────────────────────────────────────────────────────────
    # ADDRESS: handle overflow to address_2
    # ─────────────────────────────────────────────────────────────────────────
    raw_addr_1 = ship.get('address_1', '').strip()
    raw_addr_2 = ship.get('address_2', '').strip()
    
    if len(raw_addr_1) > 40 and not raw_addr_2:
        ship_addr_1, ship_addr_2 = split_long_address(raw_addr_1, 40)
    else:
        ship_addr_1 = sanitize_string(raw_addr_1, 40)
        ship_addr_2 = sanitize_string(raw_addr_2, 40)
    
    # ─────────────────────────────────────────────────────────────────────────
    # EMAIL: validate
    # ─────────────────────────────────────────────────────────────────────────
    raw_email = billing.get('email', '').strip()
    email_valid, cust_email, email_warnings = validate_email(raw_email)
    
    # ─────────────────────────────────────────────────────────────────────────
    # AMOUNTS: sanitize all monetary values
    # ─────────────────────────────────────────────────────────────────────────
    total = sanitize_amount(order.get('total'))
    shipping_total = sanitize_amount(order.get('shipping_total'))
    tax_total = sanitize_amount(order.get('total_tax'))
    discount_total = sanitize_amount(order.get('discount_total'))
    subtotal = total - shipping_total - tax_total
    
    # ─────────────────────────────────────────────────────────────────────────
    # DATE: Convert WooCommerce UTC to local time (per sync-invariants.md #7)
    # ─────────────────────────────────────────────────────────────────────────
    woo_date_utc = order.get('date_created', '')
    local_date = convert_woo_date_to_local(woo_date_utc, date_only=True)
    local_datetime = convert_woo_date_to_local(woo_date_utc, date_only=False)
    
    return {
        'WOO_ORDER_ID': order['id'],
        'WOO_ORDER_NO': sanitize_string(str(order.get('number', '')), 15),
        'CUST_EMAIL': cust_email,
        'CUST_EMAIL_VALID': email_valid,
        'ORD_DAT': local_date,  # Local date (converted from UTC)
        'ORD_DAT_UTC': woo_date_utc[:19] if woo_date_utc else '',  # Original UTC for audit
        'ORD_DATETIME_LOCAL': local_datetime,  # Full local datetime for precision
        'ORD_STATUS': sanitize_string(order.get('status', ''), 20),
        'PMT_METH': sanitize_string(order.get('payment_method_title', ''), 50),
        'SHIP_VIA': sanitize_string(
            order.get('shipping_lines', [{}])[0].get('method_title', '') 
            if order.get('shipping_lines') else '', 
            30
        ),
        'SUBTOT': subtotal,
        'SHIP_AMT': shipping_total,
        'TAX_AMT': tax_total,
        'DISC_AMT': discount_total,
        'TOT_AMT': total,
        'SHIP_NAM': ship_nam,
        'SHIP_ADRS_1': ship_addr_1,
        'SHIP_ADRS_2': ship_addr_2,
        'SHIP_CITY': sanitize_string(ship.get('city', ''), 20),
        'SHIP_STATE': normalize_state(ship.get('state', '')),
        'SHIP_ZIP_COD': sanitize_string(ship.get('postcode', ''), 15),
        'SHIP_CNTRY': sanitize_string(ship.get('country', 'US'), 20).upper(),
        'SHIP_PHONE': phone,
        'LINE_ITEMS_JSON': json.dumps(line_items),
        # Validation metadata (not stored, used for warnings)
        '_email_warnings': email_warnings,
        '_sku_warnings': sku_warnings,
    }


# ─────────────────────────────────────────────────────────────────────────────
# LIST ORDERS
# ─────────────────────────────────────────────────────────────────────────────

def list_woo_orders(days: int = 30, status: str = 'any') -> List[Dict]:
    """List recent WooCommerce orders."""
    client = WooClient()
    
    params = {
        'per_page': 50,
        'orderby': 'date',
        'order': 'desc',
    }
    
    if status != 'any':
        params['status'] = status
    
    if days:
        after_date = (datetime.now() - timedelta(days=days)).strftime('%Y-%m-%dT00:00:00')
        params['after'] = after_date
    
    url = client._url("/orders")
    resp = client.session.get(url, params=params, timeout=30)
    
    if not resp.ok:
        print(f"Error fetching orders: {resp.status_code} {resp.text[:200]}")
        return []
    
    orders = resp.json()
    
    print(f"\n{'='*80}")
    print(f"WooCommerce Orders (last {days} days)")
    print(f"{'='*80}")
    print(f"\n{'ORDER':<10} {'DATE':<12} {'STATUS':<12} {'CUSTOMER':<25} {'TOTAL':>10}")
    print("-" * 80)
    
    for o in orders:
        billing = o.get('billing', {})
        name = f"{billing.get('first_name', '')} {billing.get('last_name', '')}".strip()
        if not name:
            name = billing.get('email', 'Guest')[:25]
        # Convert UTC to local for display
        local_date = convert_woo_date_to_local(o.get('date_created', ''), date_only=True)
        print(f"#{o['id']:<9} {local_date:<12} {o.get('status', ''):<12} "
              f"{name[:25]:<25} ${float(o.get('total', 0)):>9.2f}")
    
    print(f"\nTotal: {len(orders)} orders")
    return orders


def list_staged_orders():
    """List orders in staging table."""
    orders = run_query(GET_RECENT_STAGED_ORDERS_SQL)
    
    if not orders:
        print("No orders in staging table.")
        return
    
    print(f"\n{'='*90}")
    print("Staged Orders (USER_ORDER_STAGING)")
    print(f"{'='*90}")
    print(f"\n{'WOO_ID':<10} {'CUST_NO':<12} {'DATE':<12} {'STATUS':<12} {'TOTAL':>10} {'APPLIED':<8} {'CP_DOC':<12}")
    print("-" * 90)
    
    for o in orders:
        applied = 'Yes' if o['IS_APPLIED'] else 'No'
        cp_doc = o['CP_DOC_ID'] or '-'
        date_str = str(o.get('ORD_DAT', ''))[:10]
        print(f"{o['WOO_ORDER_ID']:<10} {(o['CUST_NO'] or 'UNMAPPED'):<12} {date_str:<12} "
              f"{(o['ORD_STATUS'] or ''):<12} ${o['TOT_AMT']:>9.2f} {applied:<8} {cp_doc:<12}")
    
    print(f"\nTotal: {len(orders)} staged orders")


# ─────────────────────────────────────────────────────────────────────────────
# PULL ORDERS
# ─────────────────────────────────────────────────────────────────────────────

def pull_orders(days: int = 30, dry_run: bool = True) -> Tuple[int, int, int]:
    """
    Pull WooCommerce orders into USER_ORDER_STAGING.
    
    Returns: (new_orders, skipped, errors)
    """
    client = WooClient()
    
    print(f"\n{'='*60}")
    print(f"{'DRY RUN - ' if dry_run else ''}Pull Orders: WooCommerce -> CP Staging")
    print(f"{'='*60}")
    
    # Fetch orders from Woo
    params = {
        'per_page': 100,
        'orderby': 'date',
        'order': 'desc',
        'status': 'processing,completed',  # Only paid orders
    }
    
    if days:
        after_date = (datetime.now() - timedelta(days=days)).strftime('%Y-%m-%dT00:00:00')
        params['after'] = after_date
        print(f"Fetching orders since: {after_date[:10]}")
    
    url = client._url("/orders")
    resp = client.session.get(url, params=params, timeout=60)
    
    if not resp.ok:
        print(f"Error: {resp.status_code} {resp.text[:200]}")
        return 0, 0, 1
    
    woo_orders = resp.json()
    print(f"WooCommerce orders found: {len(woo_orders)}")
    
    # Check which are already staged
    new_orders = []
    skipped = 0
    
    for order in woo_orders:
        existing = run_query(FIND_STAGED_ORDER_SQL, (order['id'],), suppress_errors=True)
        if existing:
            skipped += 1
        else:
            new_orders.append(order)
    
    print(f"Already staged: {skipped}")
    print(f"New to stage: {len(new_orders)}")
    
    if not new_orders:
        print("\nNo new orders to pull.")
        return 0, skipped, 0
    
    # Preview
    print(f"\n{'ORDER':<10} {'CUSTOMER':<30} {'TOTAL':>10} {'CP_CUST':<12}")
    print("-" * 70)
    
    for o in new_orders[:10]:
        billing = o.get('billing', {})
        name = f"{billing.get('first_name', '')} {billing.get('last_name', '')}".strip()[:30]
        cp_cust = resolve_customer(o) or 'NOT MAPPED'
        print(f"#{o['id']:<9} {name:<30} ${float(o.get('total', 0)):>9.2f} {cp_cust:<12}")
    
    if len(new_orders) > 10:
        print(f"... and {len(new_orders) - 10} more")
    
    if dry_run:
        print(f"\n[!] DRY RUN - No changes made")
        print("    To import to staging, add --apply flag")
        return len(new_orders), skipped, 0
    
    # Insert into staging
    batch_id = f"WOO_ORDERS_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    
    conn = get_connection()
    cursor = conn.cursor()
    staged = 0
    errors = 0
    
    try:
        for order in new_orders:
            try:
                data = woo_order_to_staging(order)
                cp_cust = resolve_customer(order)
                
                cursor.execute("""
                    INSERT INTO dbo.USER_ORDER_STAGING (
                        BATCH_ID, WOO_ORDER_ID, WOO_ORDER_NO,
                        CUST_NO, CUST_EMAIL,
                        ORD_DAT, ORD_STATUS, PMT_METH, SHIP_VIA,
                        SUBTOT, SHIP_AMT, TAX_AMT, DISC_AMT, TOT_AMT,
                        SHIP_NAM, SHIP_ADRS_1, SHIP_ADRS_2, 
                        SHIP_CITY, SHIP_STATE, SHIP_ZIP_COD, SHIP_CNTRY, SHIP_PHONE,
                        LINE_ITEMS_JSON
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    batch_id,
                    data['WOO_ORDER_ID'],
                    data['WOO_ORDER_NO'],
                    cp_cust,
                    data['CUST_EMAIL'],
                    data['ORD_DAT'],
                    data['ORD_STATUS'],
                    data['PMT_METH'],
                    data['SHIP_VIA'],
                    data['SUBTOT'],
                    data['SHIP_AMT'],
                    data['TAX_AMT'],
                    data['DISC_AMT'],
                    data['TOT_AMT'],
                    data['SHIP_NAM'],
                    data['SHIP_ADRS_1'],
                    data['SHIP_ADRS_2'],
                    data['SHIP_CITY'],
                    data['SHIP_STATE'],
                    data['SHIP_ZIP_COD'],
                    data['SHIP_CNTRY'],
                    data['SHIP_PHONE'],
                    data['LINE_ITEMS_JSON'],
                ))
                staged += 1
                
            except Exception as e:
                errors += 1
                print(f"  [ERR] Error staging order #{order['id']}: {e}")
        
        conn.commit()
    finally:
        cursor.close()
        conn.close()
    
    print(f"\n{'='*60}")
    print(f"[OK] Staged {staged} orders (Batch: {batch_id})")
    print(f"  Errors: {errors}")
    print(f"{'='*60}")
    
    print(f"\nNext steps:")
    print(f"  1. Review: SELECT * FROM USER_ORDER_STAGING WHERE BATCH_ID = '{batch_id}'")
    print(f"  2. Map unmapped customers")
    print(f"  3. Validate: Check line items have matching ITEM_NO in IM_ITEM")
    print(f"  4. Apply to PS_DOC_HDR (requires CounterPoint-specific procedure)")
    
    return staged, skipped, errors


def get_order_status(woo_order_id: int):
    """Check status of a specific order in both Woo and CP staging."""
    # Check staging
    staged = run_query(FIND_STAGED_ORDER_SQL, (woo_order_id,))
    
    # Check Woo
    client = WooClient()
    url = client._url(f"/orders/{woo_order_id}")
    resp = client.session.get(url, timeout=30)
    
    print(f"\n{'='*60}")
    print(f"Order Status: #{woo_order_id}")
    print(f"{'='*60}")
    
    if resp.ok:
        woo = resp.json()
        billing = woo.get('billing', {})
        # Convert UTC to local for display
        woo_date_utc = woo.get('date_created', '')
        local_date = convert_woo_date_to_local(woo_date_utc, date_only=True)
        local_datetime = convert_woo_date_to_local(woo_date_utc, date_only=False)
        print(f"\nWooCommerce:")
        print(f"  Status: {woo.get('status')}")
        print(f"  Date (local): {local_date}")
        print(f"  DateTime (local): {local_datetime}")
        print(f"  DateTime (UTC): {woo_date_utc[:19] if woo_date_utc else 'N/A'}")
        print(f"  Customer: {billing.get('first_name')} {billing.get('last_name')}")
        print(f"  Email: {billing.get('email')}")
        print(f"  Total: ${float(woo.get('total', 0)):.2f}")
        print(f"  Items: {len(woo.get('line_items', []))}")
    else:
        print(f"\nWooCommerce: Not found ({resp.status_code})")
    
    if staged:
        s = staged[0]
        print(f"\nCP Staging:")
        print(f"  CUST_NO: {s['CUST_NO'] or 'NOT MAPPED'}")
        print(f"  Total: ${s['TOT_AMT']:.2f}")
        print(f"  Applied: {'Yes' if s['IS_APPLIED'] else 'No'}")
        print(f"  CP_DOC_ID: {s['CP_DOC_ID'] or 'N/A'}")
    else:
        print(f"\nCP Staging: Not staged")
    
    print(f"{'='*60}")


# ─────────────────────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────────────────────

def print_help():
    print("""
woo_orders.py - Pull WooCommerce Orders to CounterPoint
========================================================

COMMANDS:

  list                          List recent WooCommerce orders
  list --days 7                 List orders from last 7 days
  staged                        List orders in CP staging table
  
  pull                          Pull new orders to staging (dry-run)
  pull --apply                  Pull new orders to staging (live)
  pull --days 7 --apply         Pull last 7 days of orders
  
  status <WOO_ORDER_ID>         Check status of specific order

WORKFLOW:

  1. View recent orders:
     python woo_orders.py list

  2. Pull to staging (dry-run first):
     python woo_orders.py pull --days 7
     python woo_orders.py pull --days 7 --apply

  3. Review staged orders:
     python woo_orders.py staged

  4. Check specific order:
     python woo_orders.py status 12345

NOTE: Creating orders in PS_DOC_HDR requires CounterPoint-specific
stored procedures. The staging table prepares the data for that step.
""")


def main():
    args = sys.argv[1:]
    
    if not args or args[0] in ['help', '-h', '--help']:
        print_help()
        return
    
    cmd = args[0].lower()
    apply_flag = '--apply' in args
    
    # Parse --days N
    days = 30
    if '--days' in args:
        idx = args.index('--days')
        if idx + 1 < len(args):
            try:
                days = int(args[idx + 1])
            except ValueError:
                pass
    
    if cmd == 'list':
        list_woo_orders(days=days)
    
    elif cmd == 'staged':
        list_staged_orders()
    
    elif cmd == 'pull':
        pull_orders(days=days, dry_run=not apply_flag)
    
    elif cmd == 'status' and len(args) > 1:
        try:
            order_id = int(args[1])
            get_order_status(order_id)
        except ValueError:
            print("Error: Order ID must be a number")
    
    else:
        print(f"Unknown command: {cmd}")
        print_help()


if __name__ == "__main__":
    main()

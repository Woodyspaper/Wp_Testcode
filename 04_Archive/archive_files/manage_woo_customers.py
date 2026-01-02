"""
Manage WooCommerce Customers:
1. Stage KEEPERS to CounterPoint
2. Delete SPAM accounts from WooCommerce

Based on manual review by Richard/staff.
"""
import sys
import os

# Add project root to Python path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

from datetime import datetime
from woo_client import WooClient
from database import get_connection, run_query
from woo_customers import extract_best_customer_data

# ============================================
# KEEPER IDs - Map to CounterPoint
# ============================================
KEEPER_IDS = {
    # Real customers
    489,  # smejia@breakthrubev.com - Breakthru Beverage
    490,  # graphicadprinting@gmail.com - Graphic Advertising
    418,  # agapegraph@aol.com - Agape Graph
    382,  # Buyit@durcheap.com - Dick Kersey
    453,  # print@hopc.biz - Courtney Hamilton
    480,  # jwittenberg@minutemanpress.com - Minuteman Press
    290,  # art@printfirst.net - First Impression
    441,  # PRINT@THELIONPRESSPRINTING.COM - The Lion Press
    425,  # tim@northshoreprinting.com - North Shore Printing
    
    # Test tier accounts
    2,    # customer1@testing.com - tier_1
    3,    # customer2@testing.com - tier_2
    4,    # customer3@testing.com - tier_3
    5,    # customer4@testing.com - tier_4
    6,    # customer5@testing.com - tier_5
    7,    # customer6@testing.com - gov_tier_1
    8,    # customer7@testing.com - gov_tier_2
    9,    # customer8@testing.com - gov_tier_3
    10,   # customer9@testing.com - reseller
}

# ============================================
# PROTECTED IDs - Never delete (admin accounts)
# ============================================
PROTECTED_IDS = {
    1,    # clients@namamiinc.com - Woody's Paper admin
    268,  # info@woodyspaper.com - Richard Kersey admin
    383,  # admin@woodyspaper.com - Sales Woodyspaper
}


def fetch_all_woo_customers():
    """Fetch all customers from WooCommerce."""
    client = WooClient()
    customers = []
    page = 1
    
    print("Fetching all WooCommerce customers...")
    while True:
        url = client._url("/customers")
        resp = client.session.get(url, params={"per_page": 100, "page": page, "role": "all"}, timeout=60)
        if not resp.ok:
            break
        data = resp.json()
        if not data:
            break
        customers.extend(data)
        if len(data) < 100:
            break
        page += 1
    
    print(f"  Found {len(customers)} customers")
    return customers


def map_existing_cp_customers(dry_run=True):
    """Map WooCommerce keepers that already exist in CounterPoint."""
    client = WooClient()
    
    print("\n" + "=" * 60)
    print("MAP EXISTING COUNTERPOINT CUSTOMERS")
    print("=" * 60)
    
    # Find keepers that exist in CP but aren't mapped
    to_map = []
    
    for cust_id in KEEPER_IDS:
        # Fetch WooCommerce customer
        url = client._url(f"/customers/{cust_id}")
        resp = client.session.get(url, timeout=30)
        if not resp.ok:
            continue
        
        woo_customer = resp.json()
        data = extract_best_customer_data(woo_customer)
        email = data.get('email')
        
        if not email:
            continue
        
        # Check if already mapped
        existing_map = run_query(
            "SELECT CP_CUST_NO FROM dbo.USER_CUSTOMER_MAP WHERE WOO_USER_ID = ? AND IS_ACTIVE = 1",
            (cust_id,),
            suppress_errors=True
        )
        if existing_map:
            continue  # Already mapped
        
        # Check if exists in CP
        cp_result = run_query(
            "SELECT CUST_NO, NAM FROM dbo.AR_CUST WHERE EMAIL_ADRS_1 = ?",
            (email,),
            suppress_errors=True
        )
        
        if cp_result:
            to_map.append({
                'woo_id': cust_id,
                'woo_email': email,
                'cp_cust_no': cp_result[0]['CUST_NO'],
                'cp_name': cp_result[0]['NAM']
            })
    
    if not to_map:
        print("\n[OK] No existing CP customers need mapping!")
        return 0
    
    print(f"\n  Found {len(to_map)} keepers that exist in CP but aren't mapped:")
    print(f"\n{'WOO_ID':<8} {'EMAIL':<40} {'CP_CUST_NO':<12} {'CP_NAME':<30}")
    print("-" * 95)
    for m in to_map:
        print(f"{m['woo_id']:<8} {m['woo_email']:<40} {m['cp_cust_no']:<12} {m['cp_name'][:30]:<30}")
    
    if dry_run:
        print(f"\n[DRY RUN] Would create {len(to_map)} mappings")
        return len(to_map)
    
    # Create mappings
    conn = get_connection()
    cursor = conn.cursor()
    mapped = 0
    
    try:
        for m in to_map:
            cursor.execute("""
                INSERT INTO dbo.USER_CUSTOMER_MAP (
                    WOO_USER_ID, CP_CUST_NO, IS_ACTIVE, CREATED_DAT
                ) VALUES (?, ?, 1, GETDATE())
            """, (m['woo_id'], m['cp_cust_no']))
            mapped += 1
        
        conn.commit()
    except Exception as e:
        conn.rollback()
        print(f"\n[ERROR] Failed to create mappings: {str(e)}")
        raise
    finally:
        cursor.close()
        conn.close()
    
    print(f"\n[OK] Created {mapped} customer mappings")
    return mapped


def stage_keepers_to_cp(dry_run=True):
    """Stage only the KEEPER customers to CounterPoint."""
    client = WooClient()
    
    print("\n" + "=" * 60)
    print("STAGE KEEPERS TO COUNTERPOINT")
    print("=" * 60)
    
    # Fetch keeper customers directly
    keepers = []
    print(f"\nFetching {len(KEEPER_IDS)} keeper customers...")
    
    for cust_id in KEEPER_IDS:
        url = client._url(f"/customers/{cust_id}")
        resp = client.session.get(url, timeout=30)
        if resp.ok:
            keepers.append(resp.json())
        else:
            print(f"  [WARN] Could not fetch customer {cust_id}: {resp.status_code}")
    
    print(f"  Retrieved {len(keepers)} customers")
    
    # Check which are already mapped
    mappings = run_query("SELECT WOO_USER_ID FROM dbo.USER_CUSTOMER_MAP WHERE IS_ACTIVE = 1")
    mapped_ids = {m['WOO_USER_ID'] for m in mappings}
    
    to_stage = [c for c in keepers if c['id'] not in mapped_ids]
    already_mapped = [c for c in keepers if c['id'] in mapped_ids]
    
    print(f"\n  Already mapped: {len(already_mapped)}")
    print(f"  To stage: {len(to_stage)}")
    
    if not to_stage:
        print("\n[OK] All keepers already mapped!")
        return 0
    
    # Preview
    print(f"\n{'ID':<6} {'EMAIL':<40} {'NAME':<25}")
    print("-" * 75)
    for c in to_stage:
        data = extract_best_customer_data(c)
        print(f"{c['id']:<6} {(data['email'] or 'N/A'):<40} {(data['nam'] or 'N/A')[:25]:<25}")
    
    if dry_run:
        print(f"\n[DRY RUN] Would stage {len(to_stage)} customers")
        return len(to_stage)
    
    # Stage to database
    batch_id = f"KEEPERS_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    conn = get_connection()
    cursor = conn.cursor()
    staged = 0
    
    try:
        for c in to_stage:
            data = extract_best_customer_data(c)
            
            # Extract tier from WordPress role
            wp_role = c.get('role', 'customer')
            from woo_customers import get_prof_cod_1_from_wp_role
            prof_cod_1 = get_prof_cod_1_from_wp_role(wp_role)
            
            cursor.execute("""
                INSERT INTO dbo.USER_CUSTOMER_STAGING (
                    BATCH_ID, WOO_USER_ID, EMAIL_ADRS_1,
                    NAM, FST_NAM, LST_NAM,
                    PHONE_1, ADRS_1, ADRS_2, CITY, STATE, ZIP_COD, CNTRY,
                    CATEG_COD, PROF_COD_1, SOURCE_SYSTEM
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'RETAIL', ?, 'WOOCOMMERCE')
            """, (
                batch_id,
                c['id'],
                data['email'],
                data['nam'],
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
            ))
            staged += 1
        
        conn.commit()
    finally:
        cursor.close()
        conn.close()
    
    if staged > 0:
        print(f"  Batch ID: {batch_id}")
        print(f"\nNext: Run in SSMS:")
        print(f"  EXEC usp_Create_Customers_From_Staging @BatchID = '{batch_id}', @DryRun = 1")
    
    return staged


def delete_spam_from_woo(dry_run=True):
    """Delete non-keeper, non-protected customers from WooCommerce."""
    client = WooClient()
    
    print("\n" + "=" * 60)
    print("DELETE SPAM FROM WOOCOMMERCE")
    print("=" * 60)
    
    customers = fetch_all_woo_customers()
    
    # Determine who to delete (check for orders first)
    to_delete = []
    customers_with_orders = []
    
    for c in customers:
        cust_id = c['id']
        if cust_id in KEEPER_IDS:
            continue  # Keep
        if cust_id in PROTECTED_IDS:
            continue  # Never delete
        
        # Check if customer has orders
        try:
            url = client._url("/orders")
            resp = client.session.get(url, params={"customer": cust_id, "per_page": 1}, timeout=10)
            if resp.ok:
                total = resp.headers.get('X-WP-Total', '0')
                try:
                    order_count = int(total)
                    if order_count > 0:
                        customers_with_orders.append((cust_id, c.get('email', 'N/A'), order_count))
                        continue  # Skip deletion if has orders
                except Exception:
                    pass  # Skip if order check fails
        except Exception:
            pass  # If check fails, proceed with deletion (better safe than sorry)
        
        to_delete.append(c)
    
    print(f"\n  Keepers: {len(KEEPER_IDS)}")
    print(f"  Protected (admins): {len(PROTECTED_IDS)}")
    print(f"  Customers with orders (skipped): {len(customers_with_orders)}")
    print(f"  To delete: {len(to_delete)}")
    
    if customers_with_orders:
        print(f"\n  [INFO] Skipping {len(customers_with_orders)} customers with orders:")
        for cid, email, count in customers_with_orders[:5]:
            print(f"    ID {cid} ({email}): {count} orders")
        if len(customers_with_orders) > 5:
            print(f"    ... and {len(customers_with_orders) - 5} more")
    
    if not to_delete:
        print("\n[OK] No spam to delete!")
        return 0
    
    # Preview deletions
    print(f"\n{'ID':<6} {'EMAIL':<45} {'ROLE':<20}")
    print("-" * 75)
    for c in to_delete[:20]:
        print(f"{c['id']:<6} {(c.get('email') or 'N/A'):<45} {c.get('role', 'N/A'):<20}")
    if len(to_delete) > 20:
        print(f"... and {len(to_delete) - 20} more")
    
    if dry_run:
        print(f"\n[DRY RUN] Would delete {len(to_delete)} spam accounts")
        return len(to_delete)
    
    # Confirm before deletion
    print(f"\n[!] WARNING: About to permanently delete {len(to_delete)} accounts!")
    confirm = input("Type 'DELETE' to confirm: ")
    if confirm != 'DELETE':
        print("Cancelled.")
        return 0
    
    # Delete from WooCommerce
    deleted = 0
    errors = 0
    
    for c in to_delete:
        try:
            url = client._url(f"/customers/{c['id']}")
            # force=True permanently deletes (doesn't just move to trash)
            resp = client.session.delete(url, params={"force": True}, timeout=30)
            if resp.ok:
                deleted += 1
                print(f"  Deleted: {c['id']} ({c.get('email')})")
            else:
                errors += 1
                print(f"  [ERR] Failed to delete {c['id']}: {resp.status_code}")
        except Exception as e:
            errors += 1
            print(f"  [ERR] Error deleting {c['id']}: {e}")
    
    print(f"\n[OK] Deleted {deleted} spam accounts ({errors} errors)")
    return deleted


def main():
    print("=" * 60)
    print("WOOCOMMERCE CUSTOMER MANAGEMENT")
    print("=" * 60)
    print(f"\nKeepers: {len(KEEPER_IDS)} customers to map to CounterPoint")
    print(f"Protected: {len(PROTECTED_IDS)} admin accounts (never deleted)")
    
    # Check for --apply flag
    apply_mode = '--apply' in sys.argv
    
    if apply_mode:
        print("\n[LIVE MODE] Changes will be made!")
    else:
        print("\n[DRY RUN MODE] No changes will be made")
    
    # Map existing CP customers first (avoids duplicates)
    map_existing_cp_customers(dry_run=not apply_mode)
    
    # Stage new keepers
    stage_keepers_to_cp(dry_run=not apply_mode)
    
    # Delete spam
    delete_spam_from_woo(dry_run=not apply_mode)
    
    if not apply_mode:
        print("\n" + "=" * 60)
        print("To apply changes, run: python manage_woo_customers.py --apply")
        print("=" * 60)


if __name__ == "__main__":
    main()


"""
cp_discounts.py - Simple customer discount management via AR_CUST.DISC_PCT

╔══════════════════════════════════════════════════════════════════════════════╗
║  ⚠️  WARNING: THIS TOOL CAN MODIFY COUNTERPOINT DATA                         ║
║                                                                              ║
║  DO NOT use --apply flag without Richard's explicit approval!                ║
║  All discount values must come from existing CP data or Richard's direction. ║
║                                                                              ║
║  READ-ONLY commands (safe):  list, get, export                               ║
║  WRITE commands (need approval): set --apply, bulk --apply                   ║
╚══════════════════════════════════════════════════════════════════════════════╝

This is the SIMPLE approach for customer pricing:
  - Updates AR_CUST.DISC_PCT directly
  - Best for: "Customer X gets Y% off everything"
  - No complex pricing rules needed

For complex rules (item-specific, quantity breaks), use the 
IM_PRC_RUL approach in staging_tables_v2.sql

Usage:
    python cp_discounts.py list                    # List customers with discounts (READ-ONLY)
    python cp_discounts.py get CUST123             # Get discount for specific customer (READ-ONLY)
    python cp_discounts.py export                  # Export discounts to CSV (READ-ONLY)
    python cp_discounts.py set CUST123 15         # Set 15% discount (dry-run preview)
    python cp_discounts.py set CUST123 15 --apply # Set 15% discount (WRITES DATA - NEEDS APPROVAL)
    python cp_discounts.py bulk discounts.csv     # Bulk update from CSV (dry-run preview)
    python cp_discounts.py bulk discounts.csv --apply  # Bulk update (WRITES DATA - NEEDS APPROVAL)
"""

import csv
import sys
from decimal import Decimal
from database import run_query, get_connection


# ─────────────────────────────────────────────────────────────────────────────
# QUERIES
# ─────────────────────────────────────────────────────────────────────────────

LIST_DISCOUNTS_SQL = """
SELECT 
    CUST_NO, NAM, EMAIL_ADRS_1, CATEG_COD, 
    DISC_PCT, IS_ECOMM_CUST, LST_SAL_DAT
FROM dbo.AR_CUST
WHERE DISC_PCT IS NOT NULL AND DISC_PCT > 0
ORDER BY DISC_PCT DESC, CUST_NO
"""

GET_CUSTOMER_SQL = """
SELECT 
    CUST_NO, NAM, EMAIL_ADRS_1, CATEG_COD, 
    DISC_PCT, IS_ECOMM_CUST, LST_MAINT_DT
FROM dbo.AR_CUST
WHERE CUST_NO = ?
"""

UPDATE_DISCOUNT_SQL = """
UPDATE dbo.AR_CUST
SET DISC_PCT = ?,
    LST_MAINT_DT = GETDATE(),
    LST_MAINT_USR_ID = 'PYINTEG'
WHERE CUST_NO = ?
"""


# ─────────────────────────────────────────────────────────────────────────────
# FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────

def list_discounts():
    """List all customers with discounts."""
    rows = run_query(LIST_DISCOUNTS_SQL)
    
    if not rows:
        print("No customers with discounts found.")
        return []
    
    print(f"\n{'CUST_NO':<15} {'NAME':<25} {'DISC %':>8} {'ECOMM':>6} {'CATEGORY':<10}")
    print("-" * 70)
    
    for r in rows:
        disc = f"{r['DISC_PCT']:.1f}%" if r['DISC_PCT'] else "0%"
        ecomm = "Yes" if r['IS_ECOMM_CUST'] == 'Y' else "No"
        categ = r.get('CATEG_COD') or ''
        print(f"{r['CUST_NO']:<15} {(r['NAM'] or '')[:25]:<25} {disc:>8} {ecomm:>6} {categ:<10}")
    
    print(f"\nTotal: {len(rows)} customers with discounts")
    return rows


def get_customer_discount(cust_no):
    """Get discount info for a specific customer."""
    rows = run_query(GET_CUSTOMER_SQL, (cust_no,))
    
    if not rows:
        print(f"Customer '{cust_no}' not found.")
        return None
    
    c = rows[0]
    disc = c['DISC_PCT'] or 0
    
    print(f"\n{'='*50}")
    print(f"Customer: {c['CUST_NO']}")
    print(f"{'='*50}")
    print(f"  Name:      {c['NAM']}")
    print(f"  Email:     {c['EMAIL_ADRS_1'] or 'N/A'}")
    print(f"  Category:  {c['CATEG_COD'] or 'N/A'}")
    print(f"  E-Commerce: {'Yes' if c['IS_ECOMM_CUST'] == 'Y' else 'No'}")
    print(f"  Discount:  {disc:.2f}%")
    print(f"  Last Modified: {c['LST_MAINT_DT'] or 'N/A'}")
    print(f"{'='*50}")
    
    return c


def set_customer_discount(cust_no, discount_pct, dry_run=True):
    """Set discount percentage for a customer."""
    
    # Validate discount
    try:
        discount = Decimal(str(discount_pct))
        if discount < 0 or discount > 100:
            print(f"Error: Discount must be between 0 and 100 (got {discount})")
            return False
    except:
        print(f"Error: Invalid discount value '{discount_pct}'")
        return False
    
    # Get current customer info
    rows = run_query(GET_CUSTOMER_SQL, (cust_no,))
    if not rows:
        print(f"Error: Customer '{cust_no}' not found.")
        return False
    
    current = rows[0]
    current_disc = current['DISC_PCT'] or 0
    
    print(f"\n{'='*50}")
    print(f"{'DRY RUN - ' if dry_run else ''}Update Customer Discount")
    print(f"{'='*50}")
    print(f"  Customer:  {cust_no} - {current['NAM']}")
    print(f"  Current:   {current_disc:.2f}%")
    print(f"  New:       {discount:.2f}%")
    print(f"  Change:    {discount - Decimal(str(current_disc)):+.2f}%")
    print(f"{'='*50}")
    
    if dry_run:
        print("\n⚠️  DRY RUN - No changes made")
        print("    To apply, add --apply flag")
        return True
    
    # Apply the update
    conn = get_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute(UPDATE_DISCOUNT_SQL, (float(discount), cust_no))
        conn.commit()
        print(f"\n✓ Discount updated successfully!")
        return True
    except Exception as e:
        conn.rollback()
        print(f"\n✗ Error: {e}")
        return False
    finally:
        cursor.close()
        conn.close()


def bulk_update_discounts(csv_path, dry_run=True):
    """
    Bulk update discounts from CSV file.
    
    Expected CSV columns:
        CUST_NO, DISC_PCT
    
    Optional columns:
        DESCR (for logging)
    """
    import os
    
    if not os.path.exists(csv_path):
        print(f"Error: File not found: {csv_path}")
        return False
    
    # Read CSV
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        rows = list(reader)
    
    if not rows:
        print("Error: CSV file is empty")
        return False
    
    print(f"\n{'='*60}")
    print(f"{'DRY RUN - ' if dry_run else ''}Bulk Discount Update")
    print(f"{'='*60}")
    print(f"File: {csv_path}")
    print(f"Records: {len(rows)}")
    print(f"{'='*60}\n")
    
    # Validate all customers exist
    updates = []
    errors = []
    
    for i, row in enumerate(rows, 1):
        cust_no = row.get('CUST_NO', '').strip()
        disc_str = row.get('DISC_PCT', '').strip()
        
        if not cust_no:
            errors.append(f"Row {i}: Missing CUST_NO")
            continue
        
        try:
            disc_pct = Decimal(disc_str)
            if disc_pct < 0 or disc_pct > 100:
                errors.append(f"Row {i}: Discount {disc_pct} out of range (0-100)")
                continue
        except:
            errors.append(f"Row {i}: Invalid discount value '{disc_str}'")
            continue
        
        # Check customer exists
        check = run_query(GET_CUSTOMER_SQL, (cust_no,), suppress_errors=True)
        if not check:
            errors.append(f"Row {i}: Customer '{cust_no}' not found")
            continue
        
        current = check[0]
        updates.append({
            'cust_no': cust_no,
            'name': current['NAM'],
            'current_disc': current['DISC_PCT'] or 0,
            'new_disc': disc_pct,
        })
    
    # Show preview
    print(f"{'CUST_NO':<15} {'NAME':<20} {'CURRENT':>10} {'NEW':>10} {'CHANGE':>10}")
    print("-" * 70)
    
    for u in updates[:20]:
        change = u['new_disc'] - Decimal(str(u['current_disc']))
        print(f"{u['cust_no']:<15} {u['name'][:20]:<20} "
              f"{u['current_disc']:>9.1f}% {u['new_disc']:>9.1f}% {change:>+9.1f}%")
    
    if len(updates) > 20:
        print(f"... and {len(updates) - 20} more")
    
    print(f"\nValid updates: {len(updates)}")
    print(f"Errors: {len(errors)}")
    
    if errors:
        print("\nErrors:")
        for e in errors[:10]:
            print(f"  ✗ {e}")
        if len(errors) > 10:
            print(f"  ... and {len(errors) - 10} more")
    
    if dry_run:
        print(f"\n⚠️  DRY RUN - No changes made")
        print("    To apply, add --apply flag")
        return True
    
    if not updates:
        print("\nNo valid updates to apply.")
        return False
    
    # Apply updates
    conn = get_connection()
    cursor = conn.cursor()
    applied = 0
    
    try:
        for u in updates:
            cursor.execute(UPDATE_DISCOUNT_SQL, (float(u['new_disc']), u['cust_no']))
            applied += 1
        
        conn.commit()
        print(f"\n✓ Applied {applied} discount updates successfully!")
        return True
        
    except Exception as e:
        conn.rollback()
        print(f"\n✗ Error after {applied} updates: {e}")
        return False
    finally:
        cursor.close()
        conn.close()


def export_discounts(output_path=None):
    """Export current customer discounts to CSV."""
    from datetime import datetime
    
    if not output_path:
        output_path = f"customer_discounts_{datetime.now().strftime('%Y%m%d')}.csv"
    
    rows = run_query(LIST_DISCOUNTS_SQL)
    
    if not rows:
        print("No discounts to export.")
        return None
    
    with open(output_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=['CUST_NO', 'NAM', 'EMAIL_ADRS_1', 
                                               'CATEG_COD', 'DISC_PCT', 'IS_ECOMM_CUST'])
        writer.writeheader()
        writer.writerows(rows)
    
    print(f"✓ Exported {len(rows)} discounts to: {output_path}")
    return output_path


# ─────────────────────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────────────────────

def print_help():
    print("""
cp_discounts.py - Simple Customer Discount Management
======================================================

This tool manages customer discounts via AR_CUST.DISC_PCT
(the simple approach - customer gets X% off everything)

COMMANDS:

  list                          List all customers with discounts
  get <CUST_NO>                 Show discount for specific customer
  set <CUST_NO> <PCT>           Set discount (dry-run by default)
  set <CUST_NO> <PCT> --apply   Set discount (live)
  bulk <file.csv>               Bulk update from CSV (dry-run)
  bulk <file.csv> --apply       Bulk update from CSV (live)
  export [filename.csv]         Export current discounts to CSV

EXAMPLES:

  python cp_discounts.py list
  python cp_discounts.py get SMITH
  python cp_discounts.py set SMITH 15
  python cp_discounts.py set SMITH 15 --apply
  python cp_discounts.py bulk new_discounts.csv --apply

CSV FORMAT (for bulk updates):

  CUST_NO,DISC_PCT
  SMITH,15.0
  JONES,10.0
  ACME,20.0

NOTE: This is for SIMPLE customer-level discounts only.
For complex rules (item-specific, quantity breaks), use the 
IM_PRC_RUL approach via staging_tables_v2.sql
""")


def main():
    args = sys.argv[1:]
    
    if not args or args[0] in ['help', '-h', '--help']:
        print_help()
        return
    
    cmd = args[0].lower()
    apply_flag = '--apply' in args
    
    if cmd == 'list':
        list_discounts()
    
    elif cmd == 'get' and len(args) > 1:
        get_customer_discount(args[1])
    
    elif cmd == 'set' and len(args) > 2:
        set_customer_discount(args[1], args[2], dry_run=not apply_flag)
    
    elif cmd == 'bulk' and len(args) > 1:
        bulk_update_discounts(args[1], dry_run=not apply_flag)
    
    elif cmd == 'export':
        output = args[1] if len(args) > 1 and not args[1].startswith('-') else None
        export_discounts(output)
    
    else:
        print(f"Unknown command: {cmd}")
        print_help()


if __name__ == "__main__":
    main()

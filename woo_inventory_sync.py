"""
woo_inventory_sync.py - Phase 3: Inventory Sync from CounterPoint to WooCommerce

Purpose:
  - Sync ONLY inventory levels (stock quantities) from CounterPoint to WooCommerce
  - Fast, frequent sync (every 5 minutes)
  - Does NOT create new products or update product details
  - Only updates stock_quantity and stock_status for existing products

Usage:
    python woo_inventory_sync.py sync             # Sync inventory (dry-run)
    python woo_inventory_sync.py sync --apply     # Sync inventory (live)
    python woo_inventory_sync.py sync --sku SKU123 # Sync specific SKU
"""

import sys
import os
from typing import List, Dict, Optional
from datetime import datetime

# Add project root to path
project_root = os.path.dirname(os.path.abspath(__file__))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

from database import get_connection, connection_ctx
from woo_client import WooClient
from data_utils import sanitize_string


# ─────────────────────────────────────────────────────────────────────────────
# SQL QUERIES
# ─────────────────────────────────────────────────────────────────────────────

GET_INVENTORY_SQL = """
SELECT 
    SKU,
    WOO_PRODUCT_ID,
    STOCK_QTY,
    CP_STATUS,
    IS_ECOMM_ITEM
FROM dbo.VI_INVENTORY_SYNC
ORDER BY SKU;
"""

GET_INVENTORY_BY_SKU_SQL = """
SELECT 
    SKU,
    WOO_PRODUCT_ID,
    STOCK_QTY,
    CP_STATUS,
    IS_ECOMM_ITEM
FROM dbo.VI_INVENTORY_SYNC
WHERE SKU = ?;
"""


# ─────────────────────────────────────────────────────────────────────────────
# HELPER FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────

def calculate_stock_status(stock_qty: float) -> tuple[str, float]:
    """
    Calculate WooCommerce stock_status and stock_quantity from CounterPoint quantity.
    
    Returns:
        (stock_status, stock_quantity)
        - stock_status: 'instock', 'outofstock', or 'onbackorder'
        - stock_quantity: Actual quantity (0 for negative/backorder)
    """
    if stock_qty > 0:
        return ('instock', stock_qty)
    elif stock_qty == 0:
        return ('outofstock', 0)
    else:  # stock_qty < 0 (backorder)
        return ('onbackorder', 0)  # Display as 0, but status shows "On Order"


def prepare_inventory_payload(woo_product_id: int, stock_qty: float, stock_status: str) -> Dict:
    """
    Prepare WooCommerce API payload for inventory update.
    
    Args:
        woo_product_id: WooCommerce product ID
        stock_qty: Stock quantity (0 for backorder/out of stock)
        stock_status: 'instock', 'outofstock', or 'onbackorder'
    
    Returns:
        Dict ready for WooCommerce API update
    """
    return {
        'id': woo_product_id,
        'stock_quantity': int(stock_qty),  # WooCommerce expects integer
        'stock_status': stock_status,
        'manage_stock': True  # Ensure stock management is enabled
    }


# ─────────────────────────────────────────────────────────────────────────────
# SYNC FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────

def fetch_inventory(conn, sku_filter: Optional[str] = None) -> List[Dict]:
    """
    Fetch inventory data from CounterPoint.
    
    Args:
        conn: Database connection
        sku_filter: Optional SKU to filter by
    
    Returns:
        List of inventory records with SKU, stock quantity, and WooCommerce product ID
    """
    cursor = conn.cursor()
    
    try:
        if sku_filter:
            cursor.execute(GET_INVENTORY_BY_SKU_SQL, (sku_filter,))
        else:
            cursor.execute(GET_INVENTORY_SQL)
        
        rows = cursor.fetchall()
        
        # Convert to list of dicts
        inventory = []
        for row in rows:
            inventory.append({
                'SKU': row.SKU,
                'STOCK_QTY': float(row.STOCK_QTY) if row.STOCK_QTY is not None else 0.0,
                'CP_STATUS': row.CP_STATUS,
                'IS_ECOMM_ITEM': row.IS_ECOMM_ITEM,
                'WOO_PRODUCT_ID': row.WOO_PRODUCT_ID
            })
        
        return inventory
    
    finally:
        cursor.close()


def sync_inventory(dry_run: bool = True, sku_filter: Optional[str] = None) -> tuple[int, int, int]:
    """
    Sync inventory levels from CounterPoint to WooCommerce.
    
    Args:
        dry_run: If True, don't actually update WooCommerce
        sku_filter: Optional SKU to sync (for testing)
    
    Returns:
        (updated, skipped, errors)
    """
    print(f"\n{'='*60}")
    print(f"{'DRY RUN - ' if dry_run else ''}Inventory Sync: CounterPoint -> WooCommerce")
    print(f"{'='*60}")
    
    # Get inventory from CounterPoint
    with connection_ctx() as conn:
        inventory = fetch_inventory(conn, sku_filter)
    
    if not inventory:
        print("No inventory records found to sync.")
        return 0, 0, 0
    
    print(f"Found {len(inventory)} products with inventory data")
    
    # Get WooCommerce client
    client = WooClient()
    
    updated = 0
    skipped = 0
    errors = 0
    
    print(f"\n{'SKU':<20} {'Woo ID':<10} {'CP Stock':<12} {'Woo Status':<15} {'Action':<10}")
    print("-" * 80)
    
    for item in inventory:
        sku = item['SKU']
        woo_id = item['WOO_PRODUCT_ID']
        stock_qty = item['STOCK_QTY']
        
        # Calculate stock status
        stock_status, display_qty = calculate_stock_status(stock_qty)
        
        # Prepare payload
        payload = prepare_inventory_payload(woo_id, display_qty, stock_status)
        
        # Update WooCommerce
        try:
            if not dry_run:
                # First, verify product exists and get current stock
                url = client._url(f"/products/{woo_id}")
                get_resp = client.session.get(url, timeout=30)
                
                if not get_resp.ok:
                    errors += 1
                    action = f"ERROR: Product {woo_id} not found ({get_resp.status_code})"
                    print(f"{sku:<20} {woo_id:<10} {stock_qty:>10.2f}    {'ERROR':<15} {action:<10}")
                    continue
                
                # Check if stock actually changed
                product_data = get_resp.json()
                current_woo_stock = float(product_data.get('stock_quantity', 0) or 0)
                current_woo_status = product_data.get('stock_status', 'outofstock')
                
                # Compare stock quantity and status
                stock_changed = abs(current_woo_stock - display_qty) > 0.01  # Allow small floating point differences
                status_changed = current_woo_status != stock_status
                
                if not stock_changed and not status_changed:
                    # Stock hasn't changed, skip update
                    skipped += 1
                    action = "SKIPPED (no change)"
                    print(f"{sku:<20} {woo_id:<10} {stock_qty:>10.2f}    {stock_status:<15} {action:<10}")
                    continue
                
                # Stock changed, update product inventory using PUT
                resp = client.session.put(url, json=payload, timeout=30)
                
                if resp.ok:
                    updated += 1
                    action = "UPDATED"
                else:
                    errors += 1
                    action = f"ERROR: {resp.status_code}"
                    error_text = resp.text[:300] if resp.text else "No error message"
                    print(f"  Error response: {error_text}")
                    # Try to get more details
                    try:
                        error_json = resp.json()
                        if 'message' in error_json:
                            print(f"  Error message: {error_json['message']}")
                    except:
                        pass
            else:
                updated += 1  # Count as would-be update in dry-run
                action = "WOULD UPDATE"
            
            print(f"{sku:<20} {woo_id:<10} {stock_qty:>10.2f}    {stock_status:<15} {action:<10}")
        
        except Exception as e:
            errors += 1
            action = f"ERROR: {str(e)[:30]}"
            print(f"{sku:<20} {woo_id:<10} {stock_qty:>10.2f}    {'ERROR':<15} {action:<10}")
            if not dry_run:
                print(f"  Exception: {e}")
                import traceback
                traceback.print_exc()
    
    print(f"\n{'='*60}")
    print(f"Summary:")
    print(f"  Updated: {updated}")
    print(f"  Skipped: {skipped}")
    print(f"  Errors: {errors}")
    print(f"{'='*60}")
    
    return updated, skipped, errors


# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='Sync inventory from CounterPoint to WooCommerce')
    parser.add_argument('action', choices=['sync'], help='Action to perform')
    parser.add_argument('--apply', action='store_true', help='Actually update WooCommerce (default: dry-run)')
    parser.add_argument('--sku', type=str, help='Sync specific SKU only (for testing)')
    
    args = parser.parse_args()
    
    if args.action == 'sync':
        dry_run = not args.apply
        updated, skipped, errors = sync_inventory(dry_run=dry_run, sku_filter=args.sku)
        
        if dry_run:
            print("\n[!] DRY RUN - No changes made to WooCommerce")
            print("    Run with --apply to actually update inventory")
        else:
            print(f"\n[OK] Inventory sync complete: {updated} updated, {skipped} skipped, {errors} errors")
        
        return 0 if errors == 0 else 1
    
    return 0


if __name__ == '__main__':
    sys.exit(main())

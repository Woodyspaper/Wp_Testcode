"""
check_inventory_sync_needed.py
Checks if inventory sync is needed based on events:
- New orders placed (website or CP POS)
- New products added
- Products phased out/removed
- Otherwise, sync every 12 hours
"""

import sys
import os
from datetime import datetime, timedelta
from typing import Tuple, Optional

# Add project root to path
project_root = os.path.dirname(os.path.abspath(__file__))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

from database import get_connection, connection_ctx


def get_last_inventory_sync_time(conn) -> Optional[datetime]:
    """Get the timestamp of the last successful inventory sync."""
    try:
        cursor = conn.cursor()
        # USER_SYNC_LOG uses START_TIME column
        cursor.execute("""
            SELECT TOP 1 START_TIME
            FROM dbo.USER_SYNC_LOG
            WHERE OPERATION_TYPE = 'inventory_sync'
            ORDER BY START_TIME DESC;
        """)
        row = cursor.fetchone()
        cursor.close()
        return row[0] if row and row[0] else None
    except Exception as e:
        # If table doesn't exist or query fails, return None (will trigger sync)
        return None


def check_new_orders(conn, since: datetime) -> int:
    """Check for new orders in staging table (from website or CP)."""
    try:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT COUNT(*)
            FROM dbo.USER_ORDER_STAGING
            WHERE CREATED_DT >= ?;
        """, (since,))
        count = cursor.fetchone()[0]
        cursor.close()
        return count
    except Exception as e:
        print(f"  Warning: Could not check orders: {e}")
        return 0


def check_new_products(conn, since: datetime) -> int:
    """Check for new products added (recent LST_MAINT_DT)."""
    try:
        cursor = conn.cursor()
        # Check if LST_MAINT_DT column exists
        cursor.execute("""
            SELECT COUNT(*)
            FROM dbo.VI_EXPORT_PRODUCTS
            WHERE LST_MAINT_DT >= ?;
        """, (since,))
        count = cursor.fetchone()[0]
        cursor.close()
        return count
    except Exception as e:
        # Column might not exist, try without it
        print(f"  Warning: Could not check new products: {e}")
        return 0


def check_product_status_changes(conn, since: datetime) -> int:
    """Check for products that changed status (active/inactive)."""
    try:
        cursor = conn.cursor()
        # Check for products that changed ACTIVE status
        # This is a simplified check - in reality, we'd need to track status history
        # For now, check if any products were modified recently
        cursor.execute("""
            SELECT COUNT(*)
            FROM dbo.VI_EXPORT_PRODUCTS
            WHERE LST_MAINT_DT >= ?;
        """, (since,))
        count = cursor.fetchone()[0]
        cursor.close()
        return count
    except Exception as e:
        print(f"  Warning: Could not check status changes: {e}")
        return 0


def check_inventory_changes(conn, since: datetime) -> int:
    """Check for inventory quantity changes."""
    try:
        cursor = conn.cursor()
        # Check if INVENTORY_LAST_MODIFIED exists in view
        cursor.execute("""
            SELECT COUNT(*)
            FROM dbo.VI_INVENTORY_SYNC
            WHERE INVENTORY_LAST_MODIFIED >= ?;
        """, (since,))
        count = cursor.fetchone()[0]
        cursor.close()
        return count
    except Exception as e:
        # Column might not exist, return 0
        return 0


def should_sync_inventory(conn, hours_threshold: int = 12) -> Tuple[bool, str]:
    """
    Determine if inventory sync is needed.
    
    Returns:
        (should_sync: bool, reason: str)
    """
    now = datetime.now()
    last_sync = get_last_inventory_sync_time(conn)
    
    # If never synced, always sync
    if not last_sync:
        return True, "Never synced before"
    
    # Check if 12 hours have passed
    hours_since_sync = (now - last_sync).total_seconds() / 3600
    if hours_since_sync >= hours_threshold:
        return True, f"12+ hours since last sync ({hours_since_sync:.1f} hours)"
    
    # Check for events in the last hour (since last sync)
    check_since = max(last_sync, now - timedelta(hours=1))
    
    # Check for new orders
    new_orders = check_new_orders(conn, check_since)
    if new_orders > 0:
        return True, f"New orders detected ({new_orders} orders)"
    
    # Check for new products
    new_products = check_new_products(conn, check_since)
    if new_products > 0:
        return True, f"New products detected ({new_products} products)"
    
    # Check for product status changes
    status_changes = check_product_status_changes(conn, check_since)
    if status_changes > 0:
        return True, f"Product changes detected ({status_changes} products)"
    
    # Check for inventory changes
    inv_changes = check_inventory_changes(conn, check_since)
    if inv_changes > 0:
        return True, f"Inventory changes detected ({inv_changes} items)"
    
    # No events detected, don't sync yet
    return False, f"No changes detected (last sync: {hours_since_sync:.1f} hours ago)"


def main():
    """Main function - returns exit code 0 if sync needed, 1 if not needed."""
    try:
        with connection_ctx() as conn:
            should_sync, reason = should_sync_inventory(conn, hours_threshold=12)
            
            print(f"============================================================")
            print(f"Inventory Sync Check")
            print(f"============================================================")
            print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"")
            print(f"Should sync: {'YES' if should_sync else 'NO'}")
            print(f"Reason: {reason}")
            print(f"")
            
            if should_sync:
                print(f"Sync is needed - proceeding with inventory sync")
                return 0
            else:
                print(f"Sync not needed - skipping (will check again later)")
                return 1
                
    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()
        # On error, default to syncing (safe fallback)
        return 0


if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)

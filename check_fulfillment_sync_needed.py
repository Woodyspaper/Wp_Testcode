"""
check_fulfillment_sync_needed.py
Checks if fulfillment status sync is needed based on:
- Orders with SHIP_DAT set (shipped) that haven't been synced to WooCommerce
- Validates shipping information exists before syncing
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


def check_shipped_orders_with_validation(conn) -> Tuple[int, Optional[datetime]]:
    """
    Check for orders that are shipped in CounterPoint and have valid shipping information.
    
    Returns:
        (count: int, newest_ship_date: Optional[datetime])
    """
    try:
        cursor = conn.cursor()
        # Check for orders that:
        # 1. Are applied (IS_APPLIED = 1)
        # 2. Have CP_DOC_ID (order exists in CounterPoint)
        # 3. Have SHIP_DAT set (order is shipped)
        # 4. Have valid shipping address (SHIP_TO_CONTACT_ID exists and links to AR_SHIP_ADRS with valid address)
        cursor.execute("""
            SELECT 
                COUNT(*) AS ShippedCount,
                MAX(h.SHIP_DAT) AS NewestShipDate
            FROM dbo.USER_ORDER_STAGING s
            INNER JOIN dbo.PS_DOC_HDR h ON TRY_CAST(s.CP_DOC_ID AS BIGINT) = h.DOC_ID
            LEFT JOIN dbo.AR_SHIP_ADRS ship ON ship.CUST_NO = h.CUST_NO 
                AND ship.SHIP_ADRS_ID = CAST(h.SHIP_TO_CONTACT_ID AS VARCHAR(10))
            WHERE s.IS_APPLIED = 1
              AND s.CP_DOC_ID IS NOT NULL
              AND TRY_CAST(s.CP_DOC_ID AS BIGINT) IS NOT NULL
              AND h.SHIP_DAT IS NOT NULL  -- Order has been shipped
              AND h.SHIP_TO_CONTACT_ID IS NOT NULL  -- Has shipping contact
              AND ship.SHIP_ADRS_ID IS NOT NULL  -- Shipping address exists
              AND ship.NAM IS NOT NULL  -- Has name
              AND ship.ADRS_1 IS NOT NULL  -- Has address line 1
              AND ship.CITY IS NOT NULL  -- Has city
              AND ship.STATE IS NOT NULL  -- Has state
              AND ship.ZIP_COD IS NOT NULL  -- Has ZIP code
        """)
        row = cursor.fetchone()
        cursor.close()
        
        if row:
            count = row[0] or 0
            newest = row[1] if row[1] else None
            return count, newest
        return 0, None
    except Exception as e:
        print(f"  Warning: Could not check shipped orders: {e}")
        return 0, None


def get_last_fulfillment_sync_time(conn) -> Optional[datetime]:
    """Get the timestamp of the last successful fulfillment sync run."""
    try:
        cursor = conn.cursor()
        # Check USER_SYNC_LOG for fulfillment sync runs
        cursor.execute("""
            SELECT TOP 1 START_TIME
            FROM dbo.USER_SYNC_LOG
            WHERE OPERATION_TYPE = 'fulfillment_status_sync'
            ORDER BY START_TIME DESC;
        """)
        row = cursor.fetchone()
        cursor.close()
        return row[0] if row and row[0] else None
    except Exception as e:
        # If table doesn't exist or query fails, return None (will trigger sync)
        return None


def should_sync_fulfillment(conn, min_check_interval_minutes: int = 30) -> Tuple[bool, str]:
    """
    Determine if fulfillment status sync is needed.
    
    Args:
        conn: Database connection
        min_check_interval_minutes: Minimum time between checks (fallback) - default 30 minutes
    
    Returns:
        (should_sync: bool, reason: str)
    """
    now = datetime.now()
    last_run = get_last_fulfillment_sync_time(conn)
    
    # Check for shipped orders with valid shipping information
    shipped_count, newest_ship_date = check_shipped_orders_with_validation(conn)
    
    if shipped_count > 0:
        # Calculate how long since newest order was shipped
        if newest_ship_date:
            minutes_since_ship = (now - newest_ship_date).total_seconds() / 60
            return True, f"{shipped_count} shipped order(s) with valid shipping info (newest shipped {minutes_since_ship:.1f} minutes ago)"
        else:
            return True, f"{shipped_count} shipped order(s) with valid shipping info"
    
    # No shipped orders - check if we should run anyway (fallback check)
    if last_run:
        minutes_since_run = (now - last_run).total_seconds() / 60
        hours_since_run = minutes_since_run / 60
        if minutes_since_run >= min_check_interval_minutes:
            return True, f"Periodic check: {hours_since_run:.1f} hours since last run"
    else:
        # Never run before - run now to establish baseline
        return True, "First run - establishing baseline"
    
    # No shipped orders and too soon for periodic check
    if last_run:
        minutes_since = (now - last_run).total_seconds() / 60
        hours_since = minutes_since / 60
        return False, f"No shipped orders with valid shipping info (last run: {hours_since:.1f} hours ago)"
    else:
        return False, "No shipped orders with valid shipping info"


def main():
    """Main function - returns exit code 0 if sync needed, 1 if not needed."""
    try:
        with connection_ctx() as conn:
            # Default: 30 minutes - can be changed via environment variable
            import os
            interval_minutes = int(os.getenv('FULFILLMENT_SYNC_INTERVAL_MINUTES', '30'))
            should_sync, reason = should_sync_fulfillment(conn, min_check_interval_minutes=interval_minutes)
            
            print(f"============================================================")
            print(f"Fulfillment Status Sync Check")
            print(f"============================================================")
            print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"")
            print(f"Should sync: {'YES' if should_sync else 'NO'}")
            print(f"Reason: {reason}")
            print(f"")
            
            if should_sync:
                print(f"Sync needed - proceeding with fulfillment status sync")
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

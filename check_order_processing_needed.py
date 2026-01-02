"""
check_order_processing_needed.py
Checks if order processing is needed based on:
- Pending orders in staging (IS_APPLIED = 0) - processes immediately
- Otherwise, check periodically (every 2-3 hours as fallback)
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


def get_last_order_processing_time(conn) -> Optional[datetime]:
    """Get the timestamp of the last successful order processing run."""
    try:
        cursor = conn.cursor()
        # Check USER_SYNC_LOG for order processing runs
        cursor.execute("""
            SELECT TOP 1 START_TIME
            FROM dbo.USER_SYNC_LOG
            WHERE OPERATION_TYPE = 'order_processing'
            ORDER BY START_TIME DESC;
        """)
        row = cursor.fetchone()
        cursor.close()
        return row[0] if row and row[0] else None
    except Exception as e:
        # If table doesn't exist or query fails, return None (will trigger processing)
        return None


def check_pending_orders(conn) -> Tuple[int, Optional[datetime]]:
    """
    Check for pending orders in staging table.
    
    Returns:
        (count: int, oldest_order_date: Optional[datetime])
    """
    try:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT 
                COUNT(*) AS PendingCount,
                MIN(CREATED_DT) AS OldestOrder
            FROM dbo.USER_ORDER_STAGING
            WHERE IS_APPLIED = 0;
        """)
        row = cursor.fetchone()
        cursor.close()
        
        if row:
            count = row[0] or 0
            oldest = row[1] if row[1] else None
            return count, oldest
        return 0, None
    except Exception as e:
        print(f"  Warning: Could not check pending orders: {e}")
        return 0, None


def check_failed_orders_retry(conn, hours_old: int = 1) -> int:
    """
    Check for failed orders that might be ready to retry.
    Orders that failed but haven't been retried recently.
    """
    try:
        cursor = conn.cursor()
        # Check for orders that failed validation or processing
        # and haven't been retried in the last hour
        cursor.execute("""
            SELECT COUNT(*)
            FROM dbo.USER_ORDER_STAGING
            WHERE IS_APPLIED = 0
              AND (IS_VALIDATED = 0 OR VALIDATION_ERROR IS NOT NULL)
              AND CREATED_DT < DATEADD(HOUR, -?, GETDATE())
              AND (APPLIED_DT IS NULL OR APPLIED_DT < DATEADD(HOUR, -?, GETDATE()));
        """, (hours_old, hours_old))
        count = cursor.fetchone()[0]
        cursor.close()
        return count or 0
    except Exception as e:
        print(f"  Warning: Could not check failed orders: {e}")
        return 0


def should_process_orders(conn, min_check_interval_minutes: int = 120) -> Tuple[bool, str]:
    """
    Determine if order processing is needed.
    
    Args:
        conn: Database connection
        min_check_interval_minutes: Minimum time between checks (fallback) - default 2 hours
    
    Returns:
        (should_process: bool, reason: str)
    """
    now = datetime.now()
    last_run = get_last_order_processing_time(conn)
    
    # Check for pending orders
    pending_count, oldest_order = check_pending_orders(conn)
    
    if pending_count > 0:
        # Calculate how long oldest order has been waiting
        if oldest_order:
            wait_minutes = (now - oldest_order).total_seconds() / 60
            return True, f"{pending_count} pending order(s) (oldest waiting {wait_minutes:.1f} minutes)"
        else:
            return True, f"{pending_count} pending order(s)"
    
    # No pending orders - check if we should run anyway (fallback check)
    if last_run:
        minutes_since_run = (now - last_run).total_seconds() / 60
        hours_since_run = minutes_since_run / 60
        if minutes_since_run >= min_check_interval_minutes:
            # Check for failed orders that might be ready to retry
            failed_retry = check_failed_orders_retry(conn, hours_old=1)
            if failed_retry > 0:
                return True, f"Periodic check: {failed_retry} failed order(s) ready for retry"
            return True, f"Periodic check: {hours_since_run:.1f} hours since last run"
    else:
        # Never run before - run now to establish baseline
        return True, "First run - establishing baseline"
    
    # No pending orders and too soon for periodic check
    if last_run:
        minutes_since = (now - last_run).total_seconds() / 60
        hours_since = minutes_since / 60
        return False, f"No pending orders (last run: {hours_since:.1f} hours ago)"
    else:
        return False, "No pending orders"


def main():
    """Main function - returns exit code 0 if processing needed, 1 if not needed."""
    try:
        with connection_ctx() as conn:
            # Default: 2 hours (120 minutes) - can be changed via environment variable
            import os
            interval_minutes = int(os.getenv('ORDER_PROCESSING_INTERVAL_MINUTES', '120'))
            should_process, reason = should_process_orders(conn, min_check_interval_minutes=interval_minutes)
            
            print(f"============================================================")
            print(f"Order Processing Check")
            print(f"============================================================")
            print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"")
            print(f"Should process: {'YES' if should_process else 'NO'}")
            print(f"Reason: {reason}")
            print(f"")
            
            if should_process:
                print(f"Processing needed - proceeding with order processing")
                return 0
            else:
                print(f"Processing not needed - skipping (will check again later)")
                return 1
                
    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()
        # On error, default to processing (safe fallback)
        return 0


if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)

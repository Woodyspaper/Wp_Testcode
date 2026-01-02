"""
cp_order_processor.py - Process staged orders into CounterPoint

This script calls the stored procedures to validate and create orders
from USER_ORDER_STAGING into PS_DOC_HDR/PS_DOC_LIN.

Usage:
    python cp_order_processor.py list                    # List pending staged orders
    python cp_order_processor.py validate <STAGING_ID>  # Validate a specific order
    python cp_order_processor.py process <STAGING_ID>   # Process a single order
    python cp_order_processor.py process --all           # Process all pending orders
    python cp_order_processor.py process --batch <ID>   # Process orders in a batch
"""

import sys
import logging
import time
from datetime import datetime
from typing import List, Dict, Optional, Tuple

from database import get_connection, run_query
from woo_client import WooClient

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────────────────────────────────────
# SQL QUERIES
# ─────────────────────────────────────────────────────────────────────────────

GET_PENDING_ORDERS_SQL = """
SELECT 
    STAGING_ID,
    WOO_ORDER_ID,
    WOO_ORDER_NO,
    CUST_NO,
    CUST_EMAIL,
    ORD_DAT,
    TOT_AMT,
    IS_VALIDATED,
    IS_APPLIED,
    VALIDATION_ERROR,
    CP_DOC_ID,
    CREATED_DT
FROM dbo.USER_ORDER_STAGING
WHERE IS_APPLIED = 0
ORDER BY CREATED_DT ASC
"""

GET_ORDERS_BY_BATCH_SQL = """
SELECT 
    STAGING_ID,
    WOO_ORDER_ID,
    WOO_ORDER_NO,
    CUST_NO,
    CUST_EMAIL,
    ORD_DAT,
    TOT_AMT,
    IS_VALIDATED,
    IS_APPLIED,
    VALIDATION_ERROR,
    CP_DOC_ID,
    CREATED_DT
FROM dbo.USER_ORDER_STAGING
WHERE BATCH_ID = ? AND IS_APPLIED = 0
ORDER BY CREATED_DT ASC
"""

GET_ORDER_DETAILS_SQL = """
SELECT 
    STAGING_ID,
    WOO_ORDER_ID,
    WOO_ORDER_NO,
    CUST_NO,
    CUST_EMAIL,
    ORD_DAT,
    ORD_STATUS,
    SUBTOT,
    SHIP_AMT,
    TAX_AMT,
    DISC_AMT,
    TOT_AMT,
    IS_VALIDATED,
    IS_APPLIED,
    VALIDATION_ERROR,
    CP_DOC_ID,
    CREATED_DT,
    APPLIED_DT,
    LINE_ITEMS_JSON
FROM dbo.USER_ORDER_STAGING
WHERE STAGING_ID = ?
"""

UPDATE_RETRY_COUNT_SQL = """
UPDATE dbo.USER_ORDER_STAGING
SET VALIDATION_ERROR = ?
WHERE STAGING_ID = ?
"""

MAX_RETRIES = 3
RETRY_DELAY_BASE = 2  # Base delay in seconds (exponential backoff: 2, 4, 8 seconds)


# ─────────────────────────────────────────────────────────────────────────────
# STORED PROCEDURE CALLS
# ─────────────────────────────────────────────────────────────────────────────

def validate_staged_order(staging_id: int) -> Tuple[bool, str]:
    """
    Validate a staged order using sp_ValidateStagedOrder.
    
    Returns:
        Tuple of (is_valid, error_message)
    """
    conn = get_connection()
    cursor = conn.cursor()
    
    try:
        # Call stored procedure with OUTPUT parameters
        cursor.execute("""
            DECLARE @IsValid BIT;
            DECLARE @ErrorMessage NVARCHAR(500);
            
            EXEC dbo.sp_ValidateStagedOrder
                @StagingID = ?,
                @IsValid = @IsValid OUTPUT,
                @ErrorMessage = @ErrorMessage OUTPUT;
            
            SELECT @IsValid AS IsValid, @ErrorMessage AS ErrorMessage;
        """, (staging_id,))
        
        result = cursor.fetchone()
        if result:
            is_valid = bool(result[0])
            error_msg = result[1] or ''
            return is_valid, error_msg
        
        return False, 'No result from validation procedure'
        
    except Exception as e:
        logger.error(f"Error validating order {staging_id}: {e}")
        return False, str(e)
    finally:
        cursor.close()
        conn.close()


def create_order_from_staging(staging_id: int) -> Tuple[bool, Optional[int], Optional[str], str]:
    """
    Create CounterPoint order from staged order using sp_CreateOrderFromStaging.
    
    Returns:
        Tuple of (success, doc_id, tkt_no, error_message)
    """
    conn = get_connection()
    # Ensure autocommit is enabled - the stored procedure manages its own transaction
    conn.autocommit = True
    cursor = conn.cursor()
    
    try:
        # Call stored procedure with OUTPUT parameters
        # Note: The stored procedure manages its own transaction internally
        cursor.execute("""
            DECLARE @DocID BIGINT;
            DECLARE @TktNo VARCHAR(15);
            DECLARE @Success BIT;
            DECLARE @ErrorMessage NVARCHAR(500);
            
            EXEC dbo.sp_CreateOrderFromStaging
                @StagingID = ?,
                @DocID = @DocID OUTPUT,
                @TktNo = @TktNo OUTPUT,
                @Success = @Success OUTPUT,
                @ErrorMessage = @ErrorMessage OUTPUT;
            
            SELECT @Success AS Success, @DocID AS DocID, @TktNo AS TktNo, @ErrorMessage AS ErrorMessage;
        """, (staging_id,))
        
        result = cursor.fetchone()
        if result:
            success = bool(result[0])
            doc_id = int(result[1]) if result[1] is not None else None
            tkt_no = result[2] if result[2] else None
            error_msg = result[3] or ''
            
            # The stored procedure already committed/rolled back its own transaction
            # No need to call commit() or rollback() here
            
            return success, doc_id, tkt_no, error_msg
        
        return False, None, None, 'No result from create procedure'
        
    except Exception as e:
        logger.error(f"Error creating order from staging {staging_id}: {e}")
        # The stored procedure handles its own transaction rollback on error
        return False, None, None, str(e)
    finally:
        cursor.close()
        conn.close()


# ─────────────────────────────────────────────────────────────────────────────
# LIST FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────

def list_pending_orders():
    """List all pending orders in staging."""
    orders = run_query(GET_PENDING_ORDERS_SQL)
    
    if not orders:
        print("\nNo pending orders in staging.")
        return
    
    print(f"\n{'='*100}")
    print("Pending Staged Orders")
    print(f"{'='*100}")
    print(f"\n{'STAGING_ID':<12} {'WOO_ID':<10} {'CUST_NO':<12} {'DATE':<12} {'TOTAL':>10} {'VALIDATED':<10} {'ERROR':<30}")
    print("-" * 100)
    
    for o in orders:
        validated = 'Yes' if o['IS_VALIDATED'] else 'No'
        error = (o['VALIDATION_ERROR'] or '')[:30]
        date_str = str(o.get('ORD_DAT', ''))[:10]
        print(f"{o['STAGING_ID']:<12} {o['WOO_ORDER_ID']:<10} "
              f"{(o['CUST_NO'] or 'UNMAPPED'):<12} {date_str:<12} "
              f"${o['TOT_AMT']:>9.2f} {validated:<10} {error:<30}")
    
    print(f"\nTotal: {len(orders)} pending orders")


def show_order_details(staging_id: int):
    """Show detailed information about a specific staged order."""
    orders = run_query(GET_ORDER_DETAILS_SQL, (staging_id,))
    
    if not orders:
        print(f"\nOrder {staging_id} not found in staging.")
        return
    
    o = orders[0]
    
    print(f"\n{'='*80}")
    print(f"Staged Order Details: STAGING_ID = {staging_id}")
    print(f"{'='*80}")
    
    print(f"\nWooCommerce:")
    print(f"  Order ID: {o['WOO_ORDER_ID']}")
    print(f"  Order No: {o['WOO_ORDER_NO'] or 'N/A'}")
    
    print(f"\nCustomer:")
    print(f"  CUST_NO: {o['CUST_NO'] or 'NOT MAPPED'}")
    print(f"  Email: {o['CUST_EMAIL'] or 'N/A'}")
    
    print(f"\nOrder Info:")
    print(f"  Date: {o['ORD_DAT']}")
    print(f"  Status: {o['ORD_STATUS'] or 'N/A'}")
    print(f"  Subtotal: ${o['SUBTOT']:.2f}")
    print(f"  Shipping: ${o['SHIP_AMT']:.2f}")
    print(f"  Tax: ${o['TAX_AMT']:.2f}")
    print(f"  Discount: ${o['DISC_AMT']:.2f}")
    print(f"  Total: ${o['TOT_AMT']:.2f}")
    
    print(f"\nProcessing Status:")
    print(f"  Validated: {'Yes' if o['IS_VALIDATED'] else 'No'}")
    print(f"  Applied: {'Yes' if o['IS_APPLIED'] else 'No'}")
    if o['VALIDATION_ERROR']:
        print(f"  Validation Error: {o['VALIDATION_ERROR']}")
    if o['CP_DOC_ID']:
        print(f"  CP_DOC_ID: {o['CP_DOC_ID']}")
    if o['APPLIED_DT']:
        print(f"  Applied Date: {o['APPLIED_DT']}")
    
    print(f"\nCreated: {o['CREATED_DT']}")
    
    # Show line items summary
    import json
    if o['LINE_ITEMS_JSON']:
        try:
            line_items = json.loads(o['LINE_ITEMS_JSON'])
            print(f"\nLine Items ({len(line_items)}):")
            for item in line_items:
                print(f"  - {item.get('sku', 'N/A'):<20} {item.get('name', 'N/A'):<40} "
                      f"Qty: {item.get('quantity', 0):<5} ${item.get('total', 0):>8.2f}")
        except json.JSONDecodeError:
            print(f"\nLine Items: JSON parse error")
    
    print(f"{'='*80}")


# ─────────────────────────────────────────────────────────────────────────────
# PROCESSING FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────

def validate_order(staging_id: int) -> bool:
    """Validate a single staged order."""
    print(f"\n{'='*80}")
    print(f"Validating Order: STAGING_ID = {staging_id}")
    print(f"{'='*80}")
    
    is_valid, error_msg = validate_staged_order(staging_id)
    
    if is_valid:
        print(f"\n[OK] Order {staging_id} is VALID")
        
        # Update validation status in staging table
        conn = get_connection()
        cursor = conn.cursor()
        try:
            cursor.execute("""
                UPDATE dbo.USER_ORDER_STAGING
                SET IS_VALIDATED = 1, VALIDATION_ERROR = NULL
                WHERE STAGING_ID = ?
            """, (staging_id,))
            conn.commit()
            print(f"    Validation status updated in staging table")
        except Exception as e:
            logger.error(f"Error updating validation status: {e}")
            conn.rollback()
        finally:
            cursor.close()
            conn.close()
        
        return True
    else:
        print(f"\n[✗] Order {staging_id} is INVALID")
        print(f"    Error: {error_msg}")
        
        # Update validation error in staging table
        conn = get_connection()
        cursor = conn.cursor()
        try:
            cursor.execute("""
                UPDATE dbo.USER_ORDER_STAGING
                SET IS_VALIDATED = 0, VALIDATION_ERROR = ?
                WHERE STAGING_ID = ?
            """, (error_msg[:500], staging_id))
            conn.commit()
        except Exception as e:
            logger.error(f"Error updating validation error: {e}")
            conn.rollback()
        finally:
            cursor.close()
            conn.close()
        
        return False


def sync_order_status_to_woocommerce(woo_order_id: int, doc_id: int, tkt_no: str) -> bool:
    """
    Update WooCommerce order status and add note with CP information.
    
    Args:
        woo_order_id: WooCommerce order ID
        doc_id: CounterPoint DOC_ID
        tkt_no: CounterPoint TKT_NO
    
    Returns:
        True if successful, False otherwise
    """
    try:
        client = WooClient()
        
        # Update status to 'processing' (order is now in CounterPoint)
        note = f"Order created in CounterPoint. DOC_ID: {doc_id}, TKT_NO: {tkt_no}"
        success, error_msg = client.update_order_status(
            order_id=woo_order_id,
            status='processing',
            note=note
        )
        
        if success:
            logger.info(f"Successfully synced order status to WooCommerce for order {woo_order_id}")
            return True
        else:
            logger.warning(f"Failed to sync order status to WooCommerce for order {woo_order_id}: {error_msg}")
            return False
            
    except Exception as e:
        logger.error(f"Exception syncing order status to WooCommerce for order {woo_order_id}: {e}")
        return False


def process_order(staging_id: int, validate_first: bool = True, retry_on_failure: bool = True) -> bool:
    """
    Process a single staged order (validate and create) with retry logic.
    
    Args:
        staging_id: Staging ID to process
        validate_first: If True, validate before processing
        retry_on_failure: If True, retry on failure with exponential backoff
    
    Returns:
        True if successful, False otherwise
    """
    print(f"\n{'='*80}")
    print(f"Processing Order: STAGING_ID = {staging_id}")
    print(f"{'='*80}")
    
    # Get order details for WooCommerce sync
    order_details = run_query(GET_ORDER_DETAILS_SQL, (staging_id,))
    if not order_details:
        print(f"\n[✗] Order {staging_id} not found in staging")
        return False
    
    order_info = order_details[0]
    woo_order_id = order_info['WOO_ORDER_ID']
    
    # Validate first if requested
    if validate_first:
        is_valid, error_msg = validate_staged_order(staging_id)
        if not is_valid:
            print(f"\n[✗] Validation failed: {error_msg}")
            print(f"    Order will not be processed.")
            # Update error in staging
            conn = get_connection()
            cursor = conn.cursor()
            try:
                cursor.execute(UPDATE_RETRY_COUNT_SQL, (error_msg[:500], staging_id))
                conn.commit()
            except Exception as e:
                logger.error(f"Error updating validation error: {e}")
                conn.rollback()
            finally:
                cursor.close()
                conn.close()
            return False
        print(f"\n[OK] Validation passed")
    
    # Create order with retry logic
    max_attempts = MAX_RETRIES if retry_on_failure else 1
    
    for attempt in range(1, max_attempts + 1):
        if attempt > 1:
            wait_time = RETRY_DELAY_BASE * (2 ** (attempt - 2))  # 2, 4, 8 seconds
            print(f"\n[Retry {attempt}/{max_attempts}] Waiting {wait_time} seconds before retry...")
            time.sleep(wait_time)
            print(f"Retrying order creation...")
        else:
            print(f"\nCreating order in CounterPoint...")
        
        success, doc_id, tkt_no, error_msg = create_order_from_staging(staging_id)
        
        if success:
            print(f"\n[OK] Order created successfully!")
            print(f"    DOC_ID: {doc_id}")
            print(f"    TKT_NO: {tkt_no}")
            print(f"    Staging ID: {staging_id}")
            
            # Sync order status to WooCommerce
            print(f"\nSyncing order status to WooCommerce...")
            if sync_order_status_to_woocommerce(woo_order_id, doc_id, tkt_no):
                print(f"[OK] Order status synced to WooCommerce")
            else:
                print(f"[⚠] Warning: Failed to sync order status to WooCommerce (order still created in CP)")
            
            return True
        else:
            print(f"\n[✗] Order creation failed (attempt {attempt}/{max_attempts})")
            print(f"    Error: {error_msg}")
            
            # Update error in staging
            conn = get_connection()
            cursor = conn.cursor()
            try:
                error_with_attempt = f"[Attempt {attempt}/{max_attempts}] {error_msg}"
                cursor.execute(UPDATE_RETRY_COUNT_SQL, (error_with_attempt[:500], staging_id))
                conn.commit()
            except Exception as e:
                logger.error(f"Error updating error message: {e}")
                conn.rollback()
            finally:
                cursor.close()
                conn.close()
            
            # If this was the last attempt, return False
            if attempt == max_attempts:
                print(f"\n[✗] Order creation failed after {max_attempts} attempts")
                return False
    
    return False


def process_all_pending():
    """Process all pending orders in staging."""
    orders = run_query(GET_PENDING_ORDERS_SQL)
    
    if not orders:
        print("\nNo pending orders to process.")
        return
    
    print(f"\n{'='*80}")
    print(f"Processing All Pending Orders ({len(orders)} orders)")
    print(f"{'='*80}")
    
    success_count = 0
    error_count = 0
    
    for order in orders:
        staging_id = order['STAGING_ID']
        woo_id = order['WOO_ORDER_ID']
        
        print(f"\n[{success_count + error_count + 1}/{len(orders)}] Processing STAGING_ID={staging_id} (WOO_ID={woo_id})...")
        
        if process_order(staging_id, validate_first=True):
            success_count += 1
        else:
            error_count += 1
    
    print(f"\n{'='*80}")
    print(f"Processing Complete")
    print(f"{'='*80}")
    print(f"  Successful: {success_count}")
    print(f"  Failed: {error_count}")
    print(f"  Total: {len(orders)}")


def process_batch(batch_id: str):
    """Process all orders in a specific batch."""
    orders = run_query(GET_ORDERS_BY_BATCH_SQL, (batch_id,))
    
    if not orders:
        print(f"\nNo pending orders found for batch: {batch_id}")
        return
    
    print(f"\n{'='*80}")
    print(f"Processing Batch: {batch_id} ({len(orders)} orders)")
    print(f"{'='*80}")
    
    success_count = 0
    error_count = 0
    
    for order in orders:
        staging_id = order['STAGING_ID']
        woo_id = order['WOO_ORDER_ID']
        
        print(f"\n[{success_count + error_count + 1}/{len(orders)}] Processing STAGING_ID={staging_id} (WOO_ID={woo_id})...")
        
        if process_order(staging_id, validate_first=True):
            success_count += 1
        else:
            error_count += 1
    
    print(f"\n{'='*80}")
    print(f"Batch Processing Complete")
    print(f"{'='*80}")
    print(f"  Successful: {success_count}")
    print(f"  Failed: {error_count}")
    print(f"  Total: {len(orders)}")


# ─────────────────────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────────────────────

def print_help():
    print("""
cp_order_processor.py - Process Staged Orders into CounterPoint
================================================================

This script validates and creates orders from USER_ORDER_STAGING
using the stored procedures:
  - sp_ValidateStagedOrder
  - sp_CreateOrderFromStaging
  - sp_CreateOrderLines

COMMANDS:

  list                          List all pending staged orders
  show <STAGING_ID>             Show detailed info for a staged order
  
  validate <STAGING_ID>         Validate a single staged order
  process <STAGING_ID>          Process a single order (validate + create)
  process --all                 Process all pending orders
  process --batch <BATCH_ID>    Process all orders in a batch

WORKFLOW:

  1. List pending orders:
     python cp_order_processor.py list

  2. Review a specific order:
     python cp_order_processor.py show 123

  3. Validate an order:
     python cp_order_processor.py validate 123

  4. Process a single order:
     python cp_order_processor.py process 123

  5. Process all pending orders:
     python cp_order_processor.py process --all

  6. Process a batch:
     python cp_order_processor.py process --batch WOO_ORDERS_20251231_120000

NOTES:

  - Orders are validated before processing
  - Validation checks: customer exists, line items present, not already applied
  - Successful processing creates records in PS_DOC_HDR, PS_DOC_LIN, PS_DOC_HDR_TOT
  - Staging record is updated with CP_DOC_ID and IS_APPLIED=1
  - Retry logic: Automatically retries failed orders up to 3 times with exponential backoff
  - Order status sync: Updates WooCommerce order status to 'processing' and adds note with CP DOC_ID/TKT_NO
""")


def main():
    args = sys.argv[1:]
    
    if not args or args[0] in ['help', '-h', '--help']:
        print_help()
        return
    
    cmd = args[0].lower()
    
    if cmd == 'list':
        list_pending_orders()
    
    elif cmd == 'show' and len(args) > 1:
        try:
            staging_id = int(args[1])
            show_order_details(staging_id)
        except ValueError:
            print("Error: STAGING_ID must be a number")
    
    elif cmd == 'validate' and len(args) > 1:
        try:
            staging_id = int(args[1])
            validate_order(staging_id)
        except ValueError:
            print("Error: STAGING_ID must be a number")
    
    elif cmd == 'process':
        if '--all' in args:
            process_all_pending()
        elif '--batch' in args:
            idx = args.index('--batch')
            if idx + 1 < len(args):
                batch_id = args[idx + 1]
                process_batch(batch_id)
            else:
                print("Error: --batch requires a batch ID")
        elif len(args) > 1:
            try:
                staging_id = int(args[1])
                process_order(staging_id)
            except ValueError:
                print("Error: STAGING_ID must be a number")
        else:
            print("Error: process command requires STAGING_ID, --all, or --batch <ID>")
            print_help()
    
    else:
        print(f"Unknown command: {cmd}")
        print_help()


if __name__ == "__main__":
    main()

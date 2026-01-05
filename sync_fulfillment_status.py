"""Sync fulfillment status from CounterPoint to WooCommerce

Monitors PS_DOC_HDR.SHIP_DAT to detect when orders are shipped,
then updates WooCommerce order status to 'completed'.
"""
from database import run_query, get_connection
from woo_client import WooClient
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def find_fulfilled_orders():
    """
    Find orders in CounterPoint that are shipped but WooCommerce still shows 'processing'.
    
    Returns list of orders ready to mark as completed:
    - Order has SHIP_DAT set (not NULL) = shipped
    - Order has valid shipping information (SHIP_TO_CONTACT_ID and AR_SHIP_ADRS)
    - WooCommerce order status is still 'processing' (not yet completed)
    """
    sql = """
        SELECT 
            s.WOO_ORDER_ID,
            s.CP_DOC_ID,
            h.TKT_NO,
            h.SHIP_DAT,
            h.TKT_DT,
            ship.NAM AS SHIP_NAME,
            ship.ADRS_1 AS SHIP_ADDRESS,
            ship.CITY AS SHIP_CITY,
            ship.STATE AS SHIP_STATE,
            ship.ZIP_COD AS SHIP_ZIP
        FROM dbo.USER_ORDER_STAGING s
        INNER JOIN dbo.PS_DOC_HDR h ON TRY_CAST(s.CP_DOC_ID AS BIGINT) = h.DOC_ID
        LEFT JOIN dbo.AR_SHIP_ADRS ship ON ship.CUST_NO = h.CUST_NO 
            AND ship.SHIP_ADRS_ID = CAST(h.SHIP_TO_CONTACT_ID AS VARCHAR(10))
        WHERE s.IS_APPLIED = 1
          AND s.CP_DOC_ID IS NOT NULL
          AND TRY_CAST(s.CP_DOC_ID AS BIGINT) IS NOT NULL  -- Valid numeric DOC_ID
          AND h.SHIP_DAT IS NOT NULL  -- Order has been shipped
          AND h.SHIP_TO_CONTACT_ID IS NOT NULL  -- Has shipping contact
          AND ship.SHIP_ADRS_ID IS NOT NULL  -- Shipping address exists
          AND ship.NAM IS NOT NULL  -- Has name
          AND ship.ADRS_1 IS NOT NULL  -- Has address line 1
          AND ship.CITY IS NOT NULL  -- Has city
          AND ship.STATE IS NOT NULL  -- Has state
          AND ship.ZIP_COD IS NOT NULL  -- Has ZIP code
        ORDER BY h.SHIP_DAT DESC
    """
    
    return run_query(sql)

def check_woocommerce_status(woo_order_id: int) -> str:
    """Check current WooCommerce order status"""
    try:
        client = WooClient()
        url = client._url(f"/orders/{woo_order_id}")
        response = client.session.get(url, timeout=30)
        
        if response.ok:
            order = response.json()
            return order.get('status', 'unknown')
        else:
            logger.warning(f"Could not fetch WooCommerce order {woo_order_id}: {response.status_code}")
            return 'unknown'
    except Exception as e:
        logger.error(f"Error checking WooCommerce status for order {woo_order_id}: {e}")
        return 'unknown'

def sync_fulfillment_to_woocommerce(dry_run: bool = True):
    """
    Sync fulfillment status from CounterPoint to WooCommerce.
    
    Finds orders that are shipped in CounterPoint (SHIP_DAT is set)
    and updates WooCommerce status to 'completed'.
    """
    print("="*80)
    print(f"{'DRY RUN - ' if dry_run else ''}SYNCING FULFILLMENT STATUS TO WOOCOMMERCE")
    print("="*80)
    
    fulfilled_orders = find_fulfilled_orders()
    
    if not fulfilled_orders:
        print("\n[INFO] No fulfilled orders found (all orders either not shipped or already completed)")
        return 0, 0
    
    print(f"\nFound {len(fulfilled_orders)} orders that are shipped in CounterPoint")
    
    client = WooClient()
    updated = 0
    skipped = 0
    
    for order in fulfilled_orders:
        woo_id = order['WOO_ORDER_ID']
        doc_id = order['CP_DOC_ID']
        tkt_no = order['TKT_NO']
        ship_date = order['SHIP_DAT']
        
        # Check current WooCommerce status
        current_status = check_woocommerce_status(woo_id)
        
        # Get shipping info for validation display
        ship_name = order.get('SHIP_NAME', 'N/A')
        ship_address = order.get('SHIP_ADDRESS', 'N/A')
        ship_city = order.get('SHIP_CITY', 'N/A')
        ship_state = order.get('SHIP_STATE', 'N/A')
        ship_zip = order.get('SHIP_ZIP', 'N/A')
        
        print(f"\nOrder #{woo_id} (CP: {tkt_no}):")
        print(f"  Ship Date: {ship_date}")
        print(f"  Shipping To: {ship_name}, {ship_address}, {ship_city}, {ship_state} {ship_zip}")
        print(f"  Current WooCommerce Status: {current_status}")
        
        # Only update if status is still 'processing' or 'pending' (not already completed)
        if current_status in ('processing', 'pending'):
            # Format ship date safely (handle datetime objects from SQL Server)
            if ship_date:
                if hasattr(ship_date, 'strftime'):
                    ship_date_str = ship_date.strftime('%Y-%m-%d')
                else:
                    ship_date_str = str(ship_date)[:10]  # First 10 chars (YYYY-MM-DD)
            else:
                ship_date_str = 'N/A'
            note = f"Order fulfilled and shipped from CounterPoint. Ship Date: {ship_date_str}"
            
            if dry_run:
                print(f"  [DRY RUN] Would update status to 'completed'")
                updated += 1
            else:
                success, error_msg = client.update_order_status(
                    order_id=woo_id,
                    status='completed',
                    note=note
                )
                
                if success:
                    print(f"  [OK] Status updated to 'completed'")
                    updated += 1
                else:
                    print(f"  [ERROR] Failed to update: {error_msg}")
                    skipped += 1
        elif current_status == 'completed':
            print(f"  [SKIP] Already completed in WooCommerce")
            skipped += 1
        else:
            print(f"  [SKIP] Status is '{current_status}' (not processing/pending)")
            skipped += 1
    
    print("\n" + "="*80)
    print(f"SYNC COMPLETE")
    print("="*80)
    print(f"  Updated: {updated}")
    print(f"  Skipped: {skipped}")
    print(f"  Total: {len(fulfilled_orders)}")
    
    if dry_run:
        print(f"\n[DRY RUN] No changes made. Run with --apply to update WooCommerce status.")
    
    return updated, skipped

if __name__ == "__main__":
    import sys
    dry_run = '--apply' not in sys.argv
    
    sync_fulfillment_to_woocommerce(dry_run=dry_run)

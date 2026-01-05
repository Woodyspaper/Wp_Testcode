"""Re-sync order status to WordPress with CounterPoint information"""
from database import run_query
from woo_client import WooClient

client = WooClient()

# Get the two orders
orders = run_query("""
    SELECT STAGING_ID, WOO_ORDER_ID, CP_DOC_ID
    FROM dbo.USER_ORDER_STAGING
    WHERE STAGING_ID IN (28, 29) AND CP_DOC_ID IS NOT NULL
""")

if not orders:
    print("No orders found to sync")
    exit(1)

print("="*80)
print("RE-SYNCING ORDER STATUS TO WOOCOMMERCE")
print("="*80)

for order in orders:
    woo_id = order['WOO_ORDER_ID']
    doc_id = int(order['CP_DOC_ID'])
    
    # Get ticket number from CounterPoint
    cp_order = run_query("""
        SELECT TKT_NO
        FROM dbo.PS_DOC_HDR
        WHERE DOC_ID = ?
    """, (doc_id,))
    
    if not cp_order:
        print(f"\n[SKIP] Order {woo_id}: CP order not found (DOC_ID: {doc_id})")
        continue
    
    tkt_no = cp_order[0]['TKT_NO']
    
    print(f"\nOrder #{woo_id}:")
    print(f"  CP DOC_ID: {doc_id}")
    print(f"  CP Ticket: {tkt_no}")
    
    # Update status and add note
    note = f"Order created in CounterPoint. DOC_ID: {doc_id}, TKT_NO: {tkt_no}"
    success, error_msg = client.update_order_status(
        order_id=woo_id,
        status='processing',
        note=note
    )
    
    if success:
        print(f"  [OK] Status synced to WordPress")
    else:
        print(f"  [ERROR] Failed to sync: {error_msg}")

print("\n" + "="*80)
print("SYNC COMPLETE")
print("="*80)

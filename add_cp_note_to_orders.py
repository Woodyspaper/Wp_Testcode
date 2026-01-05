"""Add CounterPoint notes to the two orders"""
from database import run_query
from woo_client import WooClient
import logging

logging.basicConfig(level=logging.INFO)
client = WooClient()

# Get the two orders
orders = run_query("""
    SELECT STAGING_ID, WOO_ORDER_ID, CP_DOC_ID
    FROM dbo.USER_ORDER_STAGING
    WHERE STAGING_ID IN (28, 29) AND CP_DOC_ID IS NOT NULL
""")

print("="*80)
print("ADDING COUNTERPOINT NOTES TO WOOCOMMERCE ORDERS")
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
    
    # Add note directly
    note = f"Order created in CounterPoint. DOC_ID: {doc_id}, TKT_NO: {tkt_no}"
    note_url = client._url(f"/orders/{woo_id}/notes")
    note_payload = {
        "note": note,
        "customer_note": False  # Internal note
    }
    
    try:
        note_response = client.session.post(note_url, json=note_payload, timeout=30)
        
        if note_response.ok:
            print(f"  [OK] Note added successfully")
            result = note_response.json()
            print(f"      Note ID: {result.get('id', 'N/A')}")
        else:
            print(f"  [ERROR] Failed to add note: {note_response.status_code}")
            print(f"      Response: {note_response.text[:200]}")
    except Exception as e:
        print(f"  [ERROR] Exception: {e}")

print("\n" + "="*80)
print("COMPLETE")
print("="*80)
print("\nCheck WordPress admin -> Orders -> Order notes to see the CounterPoint note")

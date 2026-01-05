"""Check the actual WordPress order status"""
from woo_client import WooClient

client = WooClient()

# Check the two orders
order_ids = [15487, 15479]

print("="*80)
print("WOOCOMMERCE ORDER STATUS CHECK")
print("="*80)

for order_id in order_ids:
    try:
        url = client._url(f"/orders/{order_id}")
        response = client.session.get(url, timeout=30)
        
        if response.ok:
            order = response.json()
            status = order.get('status', 'unknown')
            notes = order.get('meta_data', [])
            
            # Get order notes
            notes_url = client._url(f"/orders/{order_id}/notes")
            notes_response = client.session.get(notes_url, timeout=30)
            order_notes = []
            if notes_response.ok:
                order_notes = notes_response.json()
            
            print(f"\nOrder #{order_id}:")
            print(f"  Status: {status}")
            print(f"  Number: {order.get('number', 'N/A')}")
            print(f"  Customer: {order.get('billing', {}).get('first_name', '')} {order.get('billing', {}).get('last_name', '')}")
            
            # Show all notes
            if order_notes:
                print(f"  Order Notes ({len(order_notes)} total):")
                for note in order_notes[-5:]:  # Show last 5 notes
                    note_text = note.get('note', '')
                    is_cp = 'CounterPoint' in note_text or 'DOC_ID' in note_text
                    marker = "[CP]" if is_cp else ""
                    print(f"      {marker} {note_text[:80]}")
            else:
                print(f"  [INFO] No order notes found")
                
        else:
            print(f"\nOrder #{order_id}: [ERROR] Could not fetch: {response.status_code}")
    except Exception as e:
        print(f"\nOrder #{order_id}: [ERROR] Exception: {e}")

print("\n" + "="*80)
print("NOTE: 'processing' status is CORRECT - it means the order is being processed")
print("      in CounterPoint. This is the expected status after order creation.")
print("="*80)

"""Check detailed note information to see why it might not be showing"""
from woo_client import WooClient

client = WooClient()

order_id = 15487

print("="*80)
print(f"DETAILED NOTE INFORMATION FOR ORDER #{order_id}")
print("="*80)

# Get all notes with full details
notes_url = client._url(f"/orders/{order_id}/notes")
notes_response = client.session.get(notes_url, timeout=30)

if notes_response.ok:
    notes = notes_response.json()
    print(f"\nTotal notes: {len(notes)}\n")
    
    for i, note in enumerate(notes, 1):
        print(f"Note #{i}:")
        print(f"  ID: {note.get('id')}")
        print(f"  Date Created: {note.get('date_created')}")
        print(f"  Note: {note.get('note', '')[:100]}")
        print(f"  Customer Note: {note.get('customer_note')}")
        print(f"  Added By: {note.get('added_by')}")
        print()
else:
    print(f"Error fetching notes: {notes_response.status_code}")
    print(notes_response.text[:200])

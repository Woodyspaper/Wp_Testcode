"""Quick script to check order JSON format"""
from database import run_query
import json

result = run_query("SELECT STAGING_ID, WOO_ORDER_ID, LINE_ITEMS_JSON FROM dbo.USER_ORDER_STAGING WHERE STAGING_ID IN (28, 29)")

for r in result:
    print(f"\n{'='*60}")
    print(f"STAGING_ID: {r['STAGING_ID']}, WOO_ORDER_ID: {r['WOO_ORDER_ID']}")
    print(f"{'='*60}")
    json_str = r['LINE_ITEMS_JSON']
    print(f"JSON (first 500 chars): {json_str[:500]}")
    print()
    
    # Try to parse it
    try:
        items = json.loads(json_str)
        print(f"Parsed {len(items)} items:")
        for i, item in enumerate(items, 1):
            print(f"  Item {i}:")
            print(f"    sku: {item.get('sku')} (type: {type(item.get('sku'))})")
            print(f"    quantity: {item.get('quantity')} (type: {type(item.get('quantity'))})")
            print(f"    price: {item.get('price')} (type: {type(item.get('price'))})")
            print(f"    total: {item.get('total')} (type: {type(item.get('total'))})")
    except Exception as e:
        print(f"Error parsing JSON: {e}")

"""Check if items exist in CounterPoint"""
from database import run_query

skus = ['01-10251-PACKAGE', '01-11051-BOX']

for sku in skus:
    print(f"\nChecking SKU: {sku}")
    
    # Check exact match
    exact = run_query("SELECT ITEM_NO, DESCR FROM dbo.IM_ITEM WHERE ITEM_NO = ?", (sku,))
    if exact:
        print(f"  [FOUND] Exact match: {exact[0]['ITEM_NO']}")
        continue
    
    # Check without suffix
    base = sku.split('-')[0] + '-' + sku.split('-')[1] if '-' in sku else sku
    similar = run_query("SELECT TOP 5 ITEM_NO, DESCR FROM dbo.IM_ITEM WHERE ITEM_NO LIKE ? ORDER BY ITEM_NO", (base + '%',))
    if similar:
        print(f"  [SIMILAR] Found {len(similar)} items starting with {base}:")
        for item in similar:
            print(f"    - {item['ITEM_NO']}: {item['DESCR'][:50]}")
    else:
        print(f"  [NOT FOUND] No items found matching {sku}")

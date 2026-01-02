"""
generate_product_sync_report.py - Generate detailed product sync report

Creates a comprehensive report showing:
  - Products ready to sync (by status)
  - Stock availability breakdown
  - Category mapping status
  - Products already in WooCommerce
"""

import sys
from collections import defaultdict
from database import connection_ctx
from config import load_integration_config
from woo_client import WooClient
from compare_products import fetch_all_cp_products, fetch_all_woo_products, get_product_map


def generate_sync_report():
    """Generate comprehensive product sync report."""
    
    print("=" * 80)
    print("PRODUCT SYNC REPORT - CounterPoint to WooCommerce")
    print("=" * 80)
    print()
    
    try:
        config = load_integration_config()
        woo_client = WooClient(config)
        
        with connection_ctx() as conn:
            cur = conn.cursor()
            
            # Get detailed product breakdown from IM_ITEM (with STAT field)
            print("Analyzing CounterPoint products by status...")
            cur.execute("""
                SELECT 
                    i.ITEM_NO AS SKU,
                    i.DESCR AS NAME,
                    i.IS_ECOMM_ITEM,
                    i.STAT,
                    i.CATEG_COD AS CATEGORY_CODE,
                    ISNULL(SUM(inv.QTY_ON_HND), 0) AS STOCK_QTY,
                    CASE 
                        WHEN ISNULL(SUM(inv.QTY_ON_HND), 0) > 0 THEN 'IN_STOCK'
                        WHEN ISNULL(SUM(inv.QTY_ON_HND), 0) = 0 THEN 'OUT_OF_STOCK'
                        WHEN ISNULL(SUM(inv.QTY_ON_HND), 0) < 0 THEN 'ON_ORDER'
                        ELSE 'NO_DATA'
                    END AS STOCK_STATUS
                FROM dbo.IM_ITEM i
                LEFT JOIN dbo.IM_INV inv ON inv.ITEM_NO = i.ITEM_NO
                WHERE i.ITEM_NO IS NOT NULL
                GROUP BY i.ITEM_NO, i.DESCR, i.IS_ECOMM_ITEM, i.STAT, i.CATEG_COD
                ORDER BY i.IS_ECOMM_ITEM DESC, i.STAT, i.ITEM_NO;
            """)
            
            cols = [c[0] for c in cur.description]
            cp_products = [dict(zip(cols, r)) for r in cur.fetchall()]
            
            # Get WooCommerce products
            print("Fetching WooCommerce products...")
            woo_products = fetch_all_woo_products(woo_client)
            woo_skus = set(woo_products.keys())
            
            # Get product mappings
            product_map = get_product_map(conn)
            
            # Categorize products
            ready_to_sync = []  # IS_ECOMM_ITEM = 'Y' AND STAT = 'A'
            needs_review = []   # IS_ECOMM_ITEM = 'Y' AND STAT = 'V'
            do_not_sync = []    # IS_ECOMM_ITEM = 'N' OR STAT = 'D'
            already_in_woo = [] # Already exists in WooCommerce
            
            for cp_prod in cp_products:
                sku = cp_prod['SKU']
                is_ecomm = cp_prod['IS_ECOMM_ITEM'] == 'Y'
                stat = cp_prod['STAT']
                in_woo = sku in woo_skus
                is_mapped = sku in product_map
                
                cp_prod['IN_WOOCOMMERCE'] = in_woo
                cp_prod['IS_MAPPED'] = is_mapped
                
                if is_ecomm and stat == 'A':
                    ready_to_sync.append(cp_prod)
                elif is_ecomm and stat == 'V':
                    needs_review.append(cp_prod)
                elif is_ecomm and stat == 'D':
                    do_not_sync.append(cp_prod)
                else:
                    do_not_sync.append(cp_prod)
            
            # Print summary
            print("\n" + "=" * 80)
            print("SYNC STATUS SUMMARY")
            print("=" * 80)
            print(f"\nTotal CounterPoint Products: {len(cp_products):,}")
            print(f"Products in WooCommerce: {len(woo_skus):,}")
            print(f"Products with Mappings: {len(product_map):,}")
            
            print(f"\n[READY] READY TO SYNC (Active E-Commerce): {len(ready_to_sync):,}")
            print(f"   - Already in WooCommerce: {sum(1 for p in ready_to_sync if p['IN_WOOCOMMERCE']):,}")
            print(f"   - Not in WooCommerce: {sum(1 for p in ready_to_sync if not p['IN_WOOCOMMERCE']):,}")
            
            print(f"\n[REVIEW] NEEDS REVIEW (Void but E-Commerce): {len(needs_review):,}")
            print(f"   - Already in WooCommerce: {sum(1 for p in needs_review if p['IN_WOOCOMMERCE']):,}")
            print(f"   - Not in WooCommerce: {sum(1 for p in needs_review if not p['IN_WOOCOMMERCE']):,}")
            
            print(f"\n[SKIP] DO NOT SYNC: {len(do_not_sync):,}")
            print(f"   - Non-E-Commerce: {sum(1 for p in do_not_sync if p['IS_ECOMM_ITEM'] == 'N'):,}")
            print(f"   - Discontinued: {sum(1 for p in do_not_sync if p['STAT'] == 'D'):,}")
            
            # Stock breakdown for ready to sync
            print("\n" + "=" * 80)
            print("STOCK STATUS - READY TO SYNC PRODUCTS")
            print("=" * 80)
            stock_breakdown = defaultdict(int)
            for p in ready_to_sync:
                stock_breakdown[p['STOCK_STATUS']] += 1
            
            for status, count in sorted(stock_breakdown.items(), key=lambda x: x[1], reverse=True):
                print(f"  {status}: {count:,}")
            
            # Category breakdown for ready to sync
            print("\n" + "=" * 80)
            print("TOP 10 CATEGORIES - READY TO SYNC")
            print("=" * 80)
            category_breakdown = defaultdict(int)
            for p in ready_to_sync:
                cat = p['CATEGORY_CODE'] or 'NO_CATEGORY'
                category_breakdown[cat] += 1
            
            for cat, count in sorted(category_breakdown.items(), key=lambda x: x[1], reverse=True)[:10]:
                print(f"  {cat:20} : {count:,} products")
            
            # Export to CSV
            print("\n" + "=" * 80)
            print("EXPORTING DETAILED REPORT")
            print("=" * 80)
            
            import csv
            filename = "product_sync_report.csv"
            with open(filename, 'w', newline='', encoding='utf-8') as f:
                writer = csv.writer(f)
                
                # Header
                writer.writerow(['SKU', 'Name', 'CP_Status', 'E-Commerce', 'Category', 
                               'Stock_Qty', 'Stock_Status', 'In_WooCommerce', 'Is_Mapped',
                               'Sync_Action', 'WooCommerce_ID'])
                
                # Ready to sync
                for p in ready_to_sync:
                    action = 'UPDATE' if p['IN_WOOCOMMERCE'] else 'CREATE'
                    woo_id = product_map.get(p['SKU'], '') if p['IS_MAPPED'] else ''
                    writer.writerow([
                        p['SKU'],
                        p['NAME'],
                        p['STAT'],
                        'Yes',
                        p['CATEGORY_CODE'] or '',
                        p['STOCK_QTY'],
                        p['STOCK_STATUS'],
                        'Yes' if p['IN_WOOCOMMERCE'] else 'No',
                        'Yes' if p['IS_MAPPED'] else 'No',
                        action,
                        woo_id
                    ])
                
                # Needs review
                for p in needs_review:
                    action = 'REVIEW' if not p['IN_WOOCOMMERCE'] else 'UPDATE (REVIEW STATUS)'
                    woo_id = product_map.get(p['SKU'], '') if p['IS_MAPPED'] else ''
                    writer.writerow([
                        p['SKU'],
                        p['NAME'],
                        p['STAT'],
                        'Yes',
                        p['CATEGORY_CODE'] or '',
                        p['STOCK_QTY'],
                        p['STOCK_STATUS'],
                        'Yes' if p['IN_WOOCOMMERCE'] else 'No',
                        'Yes' if p['IS_MAPPED'] else 'No',
                        action,
                        woo_id
                    ])
                
                # Do not sync
                for p in do_not_sync[:100]:  # Limit to first 100
                    writer.writerow([
                        p['SKU'],
                        p['NAME'],
                        p['STAT'],
                        'No' if p['IS_ECOMM_ITEM'] == 'N' else 'Yes',
                        p['CATEGORY_CODE'] or '',
                        p['STOCK_QTY'],
                        p['STOCK_STATUS'],
                        'Yes' if p['IN_WOOCOMMERCE'] else 'No',
                        'Yes' if p['IS_MAPPED'] else 'No',
                        'DO NOT SYNC',
                        ''
                    ])
            
            print(f"\n[OK] Report exported to: {filename}")
            print(f"   - Ready to Sync: {len(ready_to_sync):,} products")
            print(f"   - Needs Review: {len(needs_review):,} products")
            print(f"   - Do Not Sync: {len(do_not_sync):,} products (showing first 100)")
            
    except Exception as ex:
        print(f"\nERROR: {ex}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    generate_sync_report()


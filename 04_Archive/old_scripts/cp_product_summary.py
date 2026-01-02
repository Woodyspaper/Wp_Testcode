"""
cp_product_summary.py - CounterPoint Product Summary Report

Shows:
  - Total products
  - Active vs Inactive breakdown
  - Stock status (In Stock, Out of Stock, On Order)
  - E-commerce vs Non-E-commerce breakdown
"""

import sys
from collections import defaultdict
from database import connection_ctx


def generate_cp_summary():
    """Generate CounterPoint product summary report."""
    
    print("=" * 80)
    print("COUNTERPOINT PRODUCT SUMMARY")
    print("=" * 80)
    print()
    
    try:
        with connection_ctx() as conn:
            cur = conn.cursor()
            
            # Get comprehensive product data
            print("Analyzing CounterPoint products...")
            cur.execute("""
                SELECT 
                    i.ITEM_NO AS SKU,
                    i.DESCR AS NAME,
                    i.IS_ECOMM_ITEM,
                    i.STAT,
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
                GROUP BY i.ITEM_NO, i.DESCR, i.IS_ECOMM_ITEM, i.STAT
                ORDER BY i.IS_ECOMM_ITEM DESC, i.STAT, i.ITEM_NO;
            """)
            
            cols = [c[0] for c in cur.description]
            products = [dict(zip(cols, r)) for r in cur.fetchall()]
            
            # Categorize products
            total_products = len(products)
            active_products = []
            inactive_products = []
            
            stock_in_stock = []
            stock_out_of_stock = []
            stock_on_order = []
            
            ecomm_products = []
            non_ecomm_products = []
            
            for prod in products:
                # Active vs Inactive (STAT field)
                if prod['STAT'] == 'A':
                    active_products.append(prod)
                else:
                    inactive_products.append(prod)
                
                # Stock status
                if prod['STOCK_STATUS'] == 'IN_STOCK':
                    stock_in_stock.append(prod)
                elif prod['STOCK_STATUS'] == 'OUT_OF_STOCK':
                    stock_out_of_stock.append(prod)
                elif prod['STOCK_STATUS'] == 'ON_ORDER':
                    stock_on_order.append(prod)
                
                # E-commerce vs Non-E-commerce
                if prod['IS_ECOMM_ITEM'] == 'Y':
                    ecomm_products.append(prod)
                else:
                    non_ecomm_products.append(prod)
            
            # Print summary
            print("=" * 80)
            print("TOTAL PRODUCTS")
            print("=" * 80)
            print(f"Total Products in CounterPoint: {total_products:,}")
            print()
            
            # Active vs Inactive
            print("=" * 80)
            print("ACTIVE vs INACTIVE STATUS")
            print("=" * 80)
            print(f"Active Products (STAT = 'A'):     {len(active_products):,}")
            print(f"Inactive Products (STAT = 'V'):   {len([p for p in inactive_products if p['STAT'] == 'V']):,}")
            print(f"Discontinued Products (STAT = 'D'): {len([p for p in inactive_products if p['STAT'] == 'D']):,}")
            print()
            
            # Breakdown by status
            print("=" * 80)
            print("DETAILED STATUS BREAKDOWN")
            print("=" * 80)
            status_breakdown = defaultdict(int)
            for prod in products:
                status_breakdown[prod['STAT']] += 1
            
            for stat in sorted(status_breakdown.keys()):
                count = status_breakdown[stat]
                stat_name = {'A': 'Active', 'V': 'Void/Inactive', 'D': 'Discontinued'}.get(stat, stat)
                print(f"  Status '{stat}' ({stat_name}): {count:,} products")
            print()
            
            # Stock Status
            print("=" * 80)
            print("STOCK STATUS")
            print("=" * 80)
            print(f"In Stock:      {len(stock_in_stock):,} products")
            print(f"Out of Stock:  {len(stock_out_of_stock):,} products")
            print(f"On Order:      {len(stock_on_order):,} products")
            print()
            
            # Stock status by active/inactive
            print("=" * 80)
            print("STOCK STATUS BY ACTIVE/INACTIVE")
            print("=" * 80)
            
            # Active products stock breakdown
            active_in_stock = [p for p in active_products if p['STOCK_STATUS'] == 'IN_STOCK']
            active_out_stock = [p for p in active_products if p['STOCK_STATUS'] == 'OUT_OF_STOCK']
            active_on_order = [p for p in active_products if p['STOCK_STATUS'] == 'ON_ORDER']
            
            print(f"\nActive Products (STAT = 'A'):")
            print(f"  In Stock:      {len(active_in_stock):,}")
            print(f"  Out of Stock:  {len(active_out_stock):,}")
            print(f"  On Order:      {len(active_on_order):,}")
            
            # Inactive products stock breakdown
            inactive_in_stock = [p for p in inactive_products if p['STOCK_STATUS'] == 'IN_STOCK']
            inactive_out_stock = [p for p in inactive_products if p['STOCK_STATUS'] == 'OUT_OF_STOCK']
            inactive_on_order = [p for p in inactive_products if p['STOCK_STATUS'] == 'ON_ORDER']
            
            print(f"\nInactive Products (STAT = 'V' or 'D'):")
            print(f"  In Stock:      {len(inactive_in_stock):,}")
            print(f"  Out of Stock:  {len(inactive_out_stock):,}")
            print(f"  On Order:      {len(inactive_on_order):,}")
            print()
            
            # E-commerce breakdown
            print("=" * 80)
            print("E-COMMERCE vs NON-E-COMMERCE")
            print("=" * 80)
            print(f"E-Commerce Active (IS_ECOMM_ITEM = 'Y'): {len(ecomm_products):,}")
            print(f"Non-E-Commerce (IS_ECOMM_ITEM = 'N'):   {len(non_ecomm_products):,}")
            print()
            
            # E-commerce stock breakdown
            ecomm_in_stock = [p for p in ecomm_products if p['STOCK_STATUS'] == 'IN_STOCK']
            ecomm_out_stock = [p for p in ecomm_products if p['STOCK_STATUS'] == 'OUT_OF_STOCK']
            ecomm_on_order = [p for p in ecomm_products if p['STOCK_STATUS'] == 'ON_ORDER']
            
            print("E-Commerce Products Stock Status:")
            print(f"  In Stock:      {len(ecomm_in_stock):,}")
            print(f"  Out of Stock:  {len(ecomm_out_stock):,}")
            print(f"  On Order:      {len(ecomm_on_order):,}")
            print()
            
            # Combined view: Active E-Commerce (ready to sync)
            print("=" * 80)
            print("ACTIVE E-COMMERCE PRODUCTS (Ready for WooCommerce Sync)")
            print("=" * 80)
            active_ecomm = [p for p in products if p['IS_ECOMM_ITEM'] == 'Y' and p['STAT'] == 'A']
            active_ecomm_in_stock = [p for p in active_ecomm if p['STOCK_STATUS'] == 'IN_STOCK']
            active_ecomm_out_stock = [p for p in active_ecomm if p['STOCK_STATUS'] == 'OUT_OF_STOCK']
            active_ecomm_on_order = [p for p in active_ecomm if p['STOCK_STATUS'] == 'ON_ORDER']
            
            print(f"Total Active E-Commerce Products: {len(active_ecomm):,}")
            print(f"  In Stock:      {len(active_ecomm_in_stock):,}")
            print(f"  Out of Stock:  {len(active_ecomm_out_stock):,}")
            print(f"  On Order:      {len(active_ecomm_on_order):,}")
            print()
            
            # Export to CSV
            print("=" * 80)
            print("EXPORTING DETAILED REPORT")
            print("=" * 80)
            
            import csv
            filename = "cp_product_summary.csv"
            with open(filename, 'w', newline='', encoding='utf-8') as f:
                writer = csv.writer(f)
                
                # Header
                writer.writerow(['SKU', 'Name', 'Status', 'E-Commerce', 'Stock_Qty', 'Stock_Status'])
                
                # Write all products
                for p in products:
                    status_name = {'A': 'Active', 'V': 'Void', 'D': 'Discontinued'}.get(p['STAT'], p['STAT'])
                    ecomm = 'Yes' if p['IS_ECOMM_ITEM'] == 'Y' else 'No'
                    writer.writerow([
                        p['SKU'],
                        p['NAME'],
                        status_name,
                        ecomm,
                        p['STOCK_QTY'],
                        p['STOCK_STATUS']
                    ])
            
            print(f"\n[OK] Report exported to: {filename}")
            print(f"   - Total Products: {total_products:,}")
            print(f"   - Active: {len(active_products):,}")
            print(f"   - Inactive: {len(inactive_products):,}")
            print(f"   - In Stock: {len(stock_in_stock):,}")
            print(f"   - Out of Stock: {len(stock_out_of_stock):,}")
            print(f"   - On Order: {len(stock_on_order):,}")
            
    except Exception as ex:
        print(f"\nERROR: {ex}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    generate_cp_summary()



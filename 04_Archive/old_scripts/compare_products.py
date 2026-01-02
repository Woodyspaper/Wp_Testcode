"""
compare_products.py - Compare CounterPoint products with WooCommerce products

Shows:
  - Products in CP but not in WooCommerce
  - Products in WooCommerce but not in CP
  - Products in both (with sync status)
  - Summary statistics
"""

import sys
from typing import Dict, List, Set, Tuple
from collections import defaultdict

from database import connection_ctx
from config import load_integration_config
from woo_client import WooClient
from woo_products import fetch_products, get_product_map


def fetch_all_cp_products(conn) -> Dict[str, Dict]:
    """Fetch all products from CounterPoint, indexed by SKU."""
    print("Fetching all products from CounterPoint...")
    products = fetch_products(conn, max_records=None)
    print(f"  Found {len(products)} products in CounterPoint")
    
    # Index by SKU
    cp_products = {}
    for p in products:
        sku = p.get('SKU')
        if sku:
            cp_products[sku] = {
                'SKU': sku,
                'NAME': p.get('NAME', ''),
                'ACTIVE': p.get('ACTIVE', 0),
                'CATEGORY_CODE': p.get('CATEGORY_CODE', ''),
                'STOCK_QTY': p.get('STOCK_QTY', 0),
            }
    
    return cp_products


def fetch_all_woo_products(client: WooClient) -> Dict[str, Dict]:
    """Fetch all products from WooCommerce, indexed by SKU."""
    import time
    
    print("Fetching all products from WooCommerce...")
    
    woo_products = {}
    page = 1
    per_page = 50  # Reduced from 100 to avoid overwhelming server
    max_pages = 1000  # Safety limit (50,000 products max)
    total_fetched = 0
    consecutive_errors = 0
    max_consecutive_errors = 3
    
    while page <= max_pages:
        url = client._url("/products")
        params = {"per_page": per_page, "page": page}
        
        # Retry logic for 503 errors
        max_retries = 3
        retry_delay = 2  # Start with 2 seconds
        response = None
        
        for attempt in range(max_retries):
            try:
                response = client.session.get(url, params=params, timeout=30)
                
                # Success - break out of retry loop
                if response.ok:
                    consecutive_errors = 0
                    break
                
                # 503 error - retry with exponential backoff
                if response.status_code == 503:
                    if attempt < max_retries - 1:
                        wait_time = retry_delay * (2 ** attempt)  # 2, 4, 8 seconds
                        print(f"  Page {page}: 503 error, retrying in {wait_time} seconds... (attempt {attempt + 1}/{max_retries})")
                        time.sleep(wait_time)
                        continue
                    else:
                        print(f"  Page {page}: 503 error after {max_retries} attempts. Server may be overloaded.")
                        consecutive_errors += 1
                        if consecutive_errors >= max_consecutive_errors:
                            print(f"  Too many consecutive errors ({consecutive_errors}). Stopping fetch.")
                            return woo_products
                        # Wait before trying next page
                        time.sleep(5)
                        break
                
                # Other errors - don't retry
                print(f"  Error fetching page {page}: {response.status_code} {response.reason}")
                consecutive_errors += 1
                if consecutive_errors >= max_consecutive_errors:
                    print(f"  Too many consecutive errors ({consecutive_errors}). Stopping fetch.")
                    return woo_products
                break
                
            except Exception as e:
                if attempt < max_retries - 1:
                    wait_time = retry_delay * (2 ** attempt)
                    print(f"  Page {page}: Exception {type(e).__name__}, retrying in {wait_time} seconds...")
                    time.sleep(wait_time)
                else:
                    print(f"  Page {page}: Exception after {max_retries} attempts: {e}")
                    consecutive_errors += 1
                    if consecutive_errors >= max_consecutive_errors:
                        return woo_products
                    break
        
        # If we got a successful response, process it
        if response and response.ok:
            try:
                data = response.json()
                if not data:
                    break
                
                for product in data:
                    sku = product.get("sku")
                    if sku:
                        woo_products[sku] = {
                            'SKU': sku,
                            'ID': product.get('id'),
                            'NAME': product.get('name', ''),
                            'STATUS': product.get('status', ''),
                            'STOCK_STATUS': product.get('stock_status', ''),
                            'STOCK_QUANTITY': product.get('stock_quantity', 0),
                        }
                
                total_fetched += len(data)
                if len(data) < per_page:
                    break
                
                # Small delay between pages to avoid rate limiting
                time.sleep(0.5)
                
            except Exception as e:
                print(f"  Error processing page {page}: {e}")
                break
        else:
            # Failed to get response - skip this page
            page += 1
            continue
        
        page += 1
        
        # Progress indicator
        if page % 10 == 0:
            print(f"  Fetched {total_fetched} products so far...")
    
    print(f"  Found {len(woo_products)} products in WooCommerce")
    if total_fetched < len(woo_products):
        print(f"  NOTE: Some products may have been skipped due to errors")
    return woo_products


def compare_products(cp_products: Dict[str, Dict], woo_products: Dict[str, Dict], 
                    product_map: Dict[str, int]) -> Tuple[Dict, Dict, Dict]:
    """Compare products and categorize them."""
    
    cp_skus = set(cp_products.keys())
    woo_skus = set(woo_products.keys())
    
    # Products in CP but not in WooCommerce
    only_in_cp = {sku: cp_products[sku] for sku in cp_skus - woo_skus}
    
    # Products in WooCommerce but not in CP
    only_in_woo = {sku: woo_products[sku] for sku in woo_skus - cp_skus}
    
    # Products in both
    in_both = {}
    for sku in cp_skus & woo_skus:
        cp_prod = cp_products[sku]
        woo_prod = woo_products[sku]
        in_both[sku] = {
            'CP': cp_prod,
            'Woo': woo_prod,
            'Mapped': sku in product_map,
        }
    
    return only_in_cp, only_in_woo, in_both


def print_summary(only_in_cp: Dict, only_in_woo: Dict, in_both: Dict, 
                 cp_products: Dict, woo_products: Dict):
    """Print comparison summary."""
    print("\n" + "=" * 80)
    print("PRODUCT COMPARISON SUMMARY")
    print("=" * 80)
    print(f"\nCounterPoint Products:     {len(cp_products):,}")
    print(f"WooCommerce Products:      {len(woo_products):,}")
    print(f"\nProducts in BOTH:         {len(in_both):,}")
    print(f"Products ONLY in CP:       {len(only_in_cp):,}")
    print(f"Products ONLY in Woo:      {len(only_in_woo):,}")
    
    # E-commerce products breakdown
    cp_ecomm = sum(1 for p in cp_products.values() if p.get('ACTIVE', 0) == 1)
    print(f"\nCP E-Commerce Active:      {cp_ecomm:,} (IS_ECOMM_ITEM = 'Y')")
    print(f"CP Non-E-Commerce:         {len(cp_products) - cp_ecomm:,}")
    
    # Only in CP - active vs inactive
    only_cp_active = sum(1 for p in only_in_cp.values() if p.get('ACTIVE', 0) == 1)
    only_cp_inactive = len(only_in_cp) - only_cp_active
    print(f"\nOnly in CP (Active):       {only_cp_active:,}")
    print(f"Only in CP (Inactive):     {only_cp_inactive:,}")
    
    # Mapped products
    mapped_count = sum(1 for p in in_both.values() if p.get('Mapped', False))
    print(f"\nProducts with Mapping:     {mapped_count:,} / {len(in_both):,}")


def print_details(only_in_cp: Dict, only_in_woo: Dict, in_both: Dict, 
                 show_all: bool = False, max_display: int = 50):
    """Print detailed comparison."""
    
    print("\n" + "=" * 80)
    print("DETAILED BREAKDOWN")
    print("=" * 80)
    
    # Products only in CP
    if only_in_cp:
        print(f"\n[CP ONLY] PRODUCTS ONLY IN COUNTERPOINT ({len(only_in_cp):,} total)")
        print("-" * 80)
        sorted_cp = sorted(only_in_cp.items(), 
                          key=lambda x: (x[1].get('ACTIVE', 0), x[0]),
                          reverse=True)
        
        display_count = len(sorted_cp) if show_all else min(max_display, len(sorted_cp))
        for i, (sku, prod) in enumerate(sorted_cp[:display_count], 1):
            active = "[ACTIVE]" if prod.get('ACTIVE', 0) == 1 else "[INACTIVE]"
            print(f"{i:4}. {sku:15} | {active:10} | {prod.get('NAME', '')[:50]}")
        
        if len(sorted_cp) > display_count:
            print(f"\n  ... and {len(sorted_cp) - display_count:,} more (use --show-all to see all)")
    
    # Products only in WooCommerce
    if only_in_woo:
        print(f"\n[WOO ONLY] PRODUCTS ONLY IN WOOCOMMERCE ({len(only_in_woo):,} total)")
        print("-" * 80)
        sorted_woo = sorted(only_in_woo.items(), key=lambda x: x[0])
        
        display_count = len(sorted_woo) if show_all else min(max_display, len(sorted_woo))
        for i, (sku, prod) in enumerate(sorted_woo[:display_count], 1):
            status = prod.get('STATUS', 'unknown')
            print(f"{i:4}. {sku:15} | ID:{str(prod.get('ID', '')):8} | {status:10} | {prod.get('NAME', '')[:40]}")
        
        if len(sorted_woo) > display_count:
            print(f"\n  ... and {len(sorted_woo) - display_count:,} more (use --show-all to see all)")
    
    # Products in both
    if in_both:
        print(f"\n[BOTH] PRODUCTS IN BOTH SYSTEMS ({len(in_both):,} total)")
        print("-" * 80)
        
        # Show unmapped products first
        unmapped = {k: v for k, v in in_both.items() if not v.get('Mapped', False)}
        if unmapped:
            print(f"\n  [WARNING] UNMAPPED ({len(unmapped):,} products - need mapping):")
            sorted_unmapped = sorted(unmapped.items(), key=lambda x: x[0])
            display_count = min(20, len(sorted_unmapped))
            for i, (sku, data) in enumerate(sorted_unmapped[:display_count], 1):
                cp_name = data['CP'].get('NAME', '')[:40]
                woo_id = data['Woo'].get('ID', '')
                print(f"    {i:3}. {sku:15} | Woo ID: {woo_id:8} | {cp_name}")
            
            if len(unmapped) > display_count:
                print(f"    ... and {len(unmapped) - display_count:,} more unmapped products")
        
        # Show mapped products
        mapped = {k: v for k, v in in_both.items() if v.get('Mapped', False)}
        if mapped:
            print(f"\n  [OK] MAPPED ({len(mapped):,} products):")
            if not show_all:
                print(f"    (Showing first 10 - use --show-all to see all)")
            sorted_mapped = sorted(mapped.items(), key=lambda x: x[0])
            display_count = len(sorted_mapped) if show_all else min(10, len(sorted_mapped))
            for i, (sku, data) in enumerate(sorted_mapped[:display_count], 1):
                cp_name = data['CP'].get('NAME', '')[:40]
                woo_id = data['Woo'].get('ID', '')
                print(f"    {i:3}. {sku:15} | Woo ID: {woo_id:8} | {cp_name}")


def export_to_csv(only_in_cp: Dict, only_in_woo: Dict, in_both: Dict, filename: str = "product_comparison.csv"):
    """Export comparison to CSV file."""
    import csv
    
    print(f"\nExporting comparison to {filename}...")
    
    with open(filename, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        
        # Header
        writer.writerow(['SKU', 'Status', 'CP_Name', 'CP_Active', 'CP_Category', 'CP_Stock',
                        'Woo_ID', 'Woo_Name', 'Woo_Status', 'Woo_Stock', 'Mapped'])
        
        # Products only in CP
        for sku, prod in sorted(only_in_cp.items()):
            writer.writerow([
                sku,
                'ONLY_IN_CP',
                prod.get('NAME', ''),
                'Yes' if prod.get('ACTIVE', 0) == 1 else 'No',
                prod.get('CATEGORY_CODE', ''),
                prod.get('STOCK_QTY', 0),
                '', '', '', '', 'No'
            ])
        
        # Products only in WooCommerce
        for sku, prod in sorted(only_in_woo.items()):
            writer.writerow([
                sku,
                'ONLY_IN_WOO',
                '',
                '', '', '',
                prod.get('ID', ''),
                prod.get('NAME', ''),
                prod.get('STATUS', ''),
                prod.get('STOCK_QUANTITY', 0),
                'No'
            ])
        
        # Products in both
        for sku, data in sorted(in_both.items()):
            cp = data['CP']
            woo = data['Woo']
            writer.writerow([
                sku,
                'IN_BOTH',
                cp.get('NAME', ''),
                'Yes' if cp.get('ACTIVE', 0) == 1 else 'No',
                cp.get('CATEGORY_CODE', ''),
                cp.get('STOCK_QTY', 0),
                woo.get('ID', ''),
                woo.get('NAME', ''),
                woo.get('STATUS', ''),
                woo.get('STOCK_QUANTITY', 0),
                'Yes' if data.get('Mapped', False) else 'No'
            ])
    
    print(f"  [OK] Exported {len(only_in_cp) + len(only_in_woo) + len(in_both):,} products to {filename}")


def main():
    import argparse
    
    parser = argparse.ArgumentParser(description="Compare CounterPoint products with WooCommerce")
    parser.add_argument("--show-all", action="store_true", 
                       help="Show all products (default: limit to 50)")
    parser.add_argument("--export", type=str, default=None,
                       help="Export comparison to CSV file")
    args = parser.parse_args()
    
    print("=" * 80)
    print("PRODUCT COMPARISON: CounterPoint vs WooCommerce")
    print("=" * 80)
    print()
    
    try:
        config = load_integration_config()
        woo_client = WooClient(config)
        
        with connection_ctx() as conn:
            # Fetch all products
            cp_products = fetch_all_cp_products(conn)
            woo_products = fetch_all_woo_products(woo_client)
            product_map = get_product_map(conn)
            
            # Compare
            only_in_cp, only_in_woo, in_both = compare_products(
                cp_products, woo_products, product_map
            )
            
            # Print summary
            print_summary(only_in_cp, only_in_woo, in_both, cp_products, woo_products)
            
            # Print details
            print_details(only_in_cp, only_in_woo, in_both, 
                        show_all=args.show_all)
            
            # Export if requested
            if args.export:
                export_to_csv(only_in_cp, only_in_woo, in_both, args.export)
            elif not args.export and (len(only_in_cp) > 0 or len(only_in_woo) > 0):
                print(f"\n[TIP] Use --export filename.csv to export full comparison to CSV")
            
    except Exception as ex:
        print(f"\nERROR: {ex}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()


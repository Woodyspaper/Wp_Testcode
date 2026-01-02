"""
Test if a WooCommerce product exists and is accessible via API
"""

import sys
import os

# Add project root to path
project_root = os.path.dirname(os.path.abspath(__file__))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

from woo_client import WooClient

def test_product(product_id: int):
    """Test if product exists in WooCommerce."""
    client = WooClient()
    
    print(f"\n{'='*60}")
    print(f"Testing WooCommerce Product: {product_id}")
    print(f"{'='*60}")
    
    url = client._url(f"/products/{product_id}")
    print(f"URL: {url}")
    
    try:
        resp = client.session.get(url, timeout=30)
        
        print(f"\nStatus Code: {resp.status_code}")
        
        if resp.ok:
            product = resp.json()
            print(f"\n[OK] Product Found:")
            print(f"  ID: {product.get('id')}")
            print(f"  SKU: {product.get('sku')}")
            print(f"  Name: {product.get('name')}")
            print(f"  Type: {product.get('type')}")
            print(f"  Status: {product.get('status')}")
            print(f"  Manage Stock: {product.get('manage_stock')}")
            print(f"  Stock Quantity: {product.get('stock_quantity')}")
            print(f"  Stock Status: {product.get('stock_status')}")
            return True
        else:
            print(f"\n[ERROR] Product Not Found or Error:")
            print(f"  Status: {resp.status_code}")
            print(f"  Response: {resp.text[:500]}")
            return False
    
    except Exception as e:
        print(f"\n[ERROR] Exception:")
        print(f"  {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='Test if WooCommerce product exists')
    parser.add_argument('product_id', type=int, help='WooCommerce product ID')
    
    args = parser.parse_args()
    
    success = test_product(args.product_id)
    sys.exit(0 if success else 1)

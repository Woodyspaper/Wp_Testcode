"""
Test Customer Sync Script
Extracts 1-2 customers from WooCommerce and inserts into staging for testing
"""
import sys
import os
from datetime import datetime

# Add project root to Python path (this file is in root, but ensure path is set)
project_root = os.path.dirname(os.path.abspath(__file__))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

from woo_customers import extract_customers_from_woo, insert_customers_into_staging
from config import load_integration_config

def main():
    print("="*70)
    print("TEST CUSTOMER SYNC")
    print("="*70)
    print()
    
    # Load configuration
    try:
        cfg = load_integration_config()
        print("✅ Configuration loaded")
    except Exception as e:
        print(f"❌ Error loading configuration: {e}")
        return 1
    
    # Extract only 1-2 customers for testing
    print("\n[Step 1] Extracting test customers from WooCommerce...")
    try:
        customers = extract_customers_from_woo(
            base_url=cfg['woocommerce']['base_url'],
            consumer_key=cfg['woocommerce']['consumer_key'],
            consumer_secret=cfg['woocommerce']['consumer_secret'],
            limit=2  # Only get 2 customers for testing
        )
        print(f"✅ Found {len(customers)} customers")
        
        if not customers:
            print("⚠️  No customers found in WooCommerce")
            return 0
        
        # Show customer info
        for i, customer in enumerate(customers, 1):
            print(f"\n  Customer {i}:")
            print(f"    ID: {customer.get('id', 'N/A')}")
            print(f"    Email: {customer.get('email', 'N/A')}")
            print(f"    Name: {customer.get('billing', {}).get('first_name', '')} {customer.get('billing', {}).get('last_name', '')}")
            
    except Exception as e:
        print(f"❌ Error extracting customers: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    # Insert into staging
    print("\n[Step 2] Inserting into staging table...")
    try:
        batch_id = f"TEST_BATCH_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        print(f"  Batch ID: {batch_id}")
        
        inserted = insert_customers_into_staging(
            customers=customers,
            batch_id=batch_id,
            connection_string=cfg['counterpoint']['connection_string']
        )
        
        print(f"✅ Inserted {inserted} customers into staging")
        print(f"\n📋 Next Steps:")
        print(f"   1. Run preflight validation in SQL Server:")
        print(f"      EXEC dbo.usp_Preflight_Validate_Customer_Staging @BatchID = '{batch_id}';")
        print(f"   2. If validation passes, create customers:")
        print(f"      EXEC dbo.usp_Create_Customers_From_Staging @BatchID = '{batch_id}';")
        print(f"   3. Check sync log:")
        print(f"      SELECT * FROM dbo.USER_SYNC_LOG WHERE BATCH_ID = '{batch_id}';")
        
        return 0
        
    except Exception as e:
        print(f"❌ Error inserting into staging: {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == '__main__':
    sys.exit(main())


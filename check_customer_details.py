"""
Quick script to check why a specific customer was flagged as spam.
Usage: python check_customer_details.py tim@northshoreprinting.com
"""

import sys
from woo_client import WooClient
from woo_customers import get_existing_woo_customers_full

def check_customer(email: str):
    """Check customer details and explain why they might be flagged as spam."""
    client = WooClient()
    
    print(f"\n{'='*60}")
    print(f"Checking Customer: {email}")
    print(f"{'='*60}\n")
    
    # Get all customers
    customers = get_existing_woo_customers_full(client)
    
    # Find the customer
    customer = None
    for c in customers:
        if c.get('email', '').lower() == email.lower():
            customer = c
            break
    
    if not customer:
        print(f"[ERROR] Customer not found: {email}")
        return
    
    print(f"Customer ID: {customer.get('id')}")
    print(f"Username: {customer.get('username', 'N/A')}")
    print(f"Email: {customer.get('email', 'N/A')}")
    print(f"Name: {customer.get('first_name', '')} {customer.get('last_name', '')}")
    print(f"Date Created: {customer.get('date_created', 'N/A')}")
    print()
    
    billing = customer.get('billing', {})
    shipping = customer.get('shipping', {})
    
    print("Billing Information:")
    print(f"  Company: {billing.get('company', 'MISSING')}")
    print(f"  Phone: {billing.get('phone', 'MISSING')}")
    print(f"  Address 1: {billing.get('address_1', 'MISSING')}")
    print(f"  City: {billing.get('city', 'MISSING')}")
    print(f"  State: {billing.get('state', 'MISSING')}")
    print()
    
    print("Shipping Information:")
    print(f"  Company: {shipping.get('company', 'MISSING')}")
    print(f"  Phone: {shipping.get('phone', 'MISSING')}")
    print(f"  Address 1: {shipping.get('address_1', 'MISSING')}")
    print()
    
    # Check orders
    from cleanup_spam_registrations import get_customer_orders
    orders = get_customer_orders(client, customer['id'])
    print(f"Orders: {len(orders)}")
    print()
    
    # Check spam criteria
    print("Spam Detection Check:")
    print("-" * 60)
    
    company = billing.get('company', '').strip() or shipping.get('company', '').strip()
    phone = billing.get('phone', '').strip() or shipping.get('phone', '').strip()
    address_1 = billing.get('address_1', '').strip() or shipping.get('address_1', '').strip()
    
    issues = []
    
    if not company:
        issues.append("[MISSING] Company name")
    else:
        print(f"[OK] Company: {company}")
    
    if not phone:
        issues.append("[MISSING] Phone number")
    else:
        print(f"[OK] Phone: {phone}")
    
    if not address_1:
        issues.append("[MISSING] Address")
    else:
        print(f"[OK] Address: {address_1}")
    
    if len(orders) == 0:
        issues.append("[MISSING] No orders placed")
    else:
        print(f"[OK] Orders: {len(orders)}")
    
    # Check username pattern
    username = customer.get('username', '').lower()
    email_local = customer.get('email', '').split('@')[0].lower()
    if username == email_local:
        issues.append("[WARNING] Username matches email (bot pattern)")
    else:
        print(f"[OK] Username different from email")
    
    print()
    if issues:
        print("Why this customer was flagged as spam:")
        for issue in issues:
            print(f"  {issue}")
        
        print("\nSpam Detection Logic:")
        if not company and not phone and not address_1:
            print("  → Missing company, phone, AND address = SPAM")
        elif not phone and not address_1:
            print("  → Missing phone AND address = SPAM")
        elif not address_1 and len(orders) == 0:
            print("  → Missing address AND no orders = SPAM")
        elif len(orders) == 0 and not company and not phone:
            print("  → No orders AND missing company/phone = SPAM")
    else:
        print("✅ This customer should NOT be flagged as spam")
        print("   (All required fields present)")
    
    print()

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python check_customer_details.py <email>")
        print("Example: python check_customer_details.py tim@northshoreprinting.com")
        sys.exit(1)
    
    check_customer(sys.argv[1])

"""
cleanup_spam_registrations.py - Identify and remove spam/bot registrations from WooCommerce

Usage:
    python cleanup_spam_registrations.py list          # List spam registrations (dry-run)
    python cleanup_spam_registrations.py delete        # Delete spam registrations (dry-run)
    python cleanup_spam_registrations.py delete --apply # Actually delete spam registrations
"""

import sys
from datetime import datetime, timedelta
from typing import List, Dict

from woo_client import WooClient
from data_utils import is_valid_email, DISPOSABLE_DOMAINS
from woo_customers import get_existing_woo_customers_full

# Spam detection criteria
SPAM_CRITERIA = {
    'disposable_email': True,      # Disposable email domains
    'missing_company': True,       # Missing company name
    'missing_phone': True,         # Missing phone number
    'missing_address': True,       # Missing billing address
    'no_orders': True,             # No orders placed
    'recent_inactive': True,       # Registered recently but no activity
    'suspicious_email': True,      # Suspicious email patterns
    'suspicious_username': True,   # Suspicious username patterns
}

# Recent registration threshold (days)
RECENT_DAYS = 30

# Minimum activity threshold (days since last order or login)
INACTIVE_DAYS = 7


def is_spam_customer(customer: Dict, orders: List[Dict] = None) -> tuple[bool, List[str]]:
    """
    Determine if a customer is likely spam based on multiple criteria.
    
    Returns:
        Tuple of (is_spam, reasons)
    """
    reasons = []
    is_spam = False
    
    email = customer.get('email', '').strip().lower()
    username = customer.get('username', '').strip().lower()
    billing = customer.get('billing', {})
    shipping = customer.get('shipping', {})
    
    # Check disposable email
    if SPAM_CRITERIA['disposable_email']:
        email_domain = email.split('@')[1] if '@' in email else ''
        if email_domain.lower() in DISPOSABLE_DOMAINS:
            reasons.append('Disposable email domain')
            is_spam = True
    
    # Check missing company name (only flag if ALSO missing other required fields)
    if SPAM_CRITERIA['missing_company']:
        company = billing.get('company', '').strip() or shipping.get('company', '').strip()
        if not company:
            # Only flag as spam if ALSO missing phone AND address (likely bot)
            phone = billing.get('phone', '').strip() or shipping.get('phone', '').strip()
            address_1 = billing.get('address_1', '').strip() or shipping.get('address_1', '').strip()
            if not phone and not address_1:
                reasons.append('Missing company name, phone, and address')
                is_spam = True
    
    # Check missing phone (only flag if ALSO missing address)
    if SPAM_CRITERIA['missing_phone']:
        phone = billing.get('phone', '').strip() or shipping.get('phone', '').strip()
        if not phone:
            address_1 = billing.get('address_1', '').strip() or shipping.get('address_1', '').strip()
            if not address_1:
                reasons.append('Missing phone and address')
                is_spam = True
    
    # Check missing address (only flag if ALSO no orders)
    if SPAM_CRITERIA['missing_address']:
        address_1 = billing.get('address_1', '').strip() or shipping.get('address_1', '').strip()
        if not address_1:
            if orders is None:
                orders = []
            if len(orders) == 0:
                reasons.append('Missing address and no orders')
                is_spam = True
    
    # Check no orders (only flag if ALSO missing multiple required fields)
    if SPAM_CRITERIA['no_orders']:
        if orders is None:
            orders = []
        if len(orders) == 0:
            # Only flag as spam if ALSO missing company AND phone (likely bot)
            company = billing.get('company', '').strip() or shipping.get('company', '').strip()
            phone = billing.get('phone', '').strip() or shipping.get('phone', '').strip()
            if not company and not phone:
                reasons.append('No orders and missing company/phone')
                is_spam = True
    
    # Check suspicious email patterns
    if SPAM_CRITERIA['suspicious_email']:
        # Random character patterns
        if len(email.split('@')[0]) > 20 and not any(c.isalpha() for c in email.split('@')[0][:5]):
            reasons.append('Suspicious email pattern')
            is_spam = True
        
        # Invalid email format
        if not is_valid_email(email):
            reasons.append('Invalid email format')
            is_spam = True
    
    # Check suspicious username
    if SPAM_CRITERIA['suspicious_username']:
        # Username matches email (common bot pattern)
        if username == email.split('@')[0]:
            reasons.append('Username matches email (bot pattern)')
            is_spam = True
        
        # Random character username
        if len(username) > 15 and not any(c.isalpha() for c in username[:5]):
            reasons.append('Suspicious username pattern')
            is_spam = True
    
    # Check recent but inactive
    if SPAM_CRITERIA['recent_inactive']:
        date_created = customer.get('date_created', '')
        if date_created:
            try:
                created_dt = datetime.fromisoformat(date_created.replace('Z', '+00:00'))
                days_old = (datetime.now(created_dt.tzinfo) - created_dt).days
                
                if days_old <= RECENT_DAYS:
                    # Recent registration
                    if orders is None:
                        orders = []
                    if len(orders) == 0:
                        reasons.append(f'Recent registration ({days_old} days) with no orders')
                        is_spam = True
            except:
                pass
    
    return is_spam, reasons


def get_customer_orders(client: WooClient, customer_id: int) -> List[Dict]:
    """Get all orders for a customer."""
    try:
        url = client._url("/orders")
        orders = []
        page = 1
        while True:
            resp = client.session.get(url, params={"customer": customer_id, "per_page": 100, "page": page}, timeout=30)
            if not resp.ok:
                break
            data = resp.json()
            if not data:
                break
            orders.extend(data)
            if len(data) < 100:
                break
            page += 1
        return orders
    except:
        return []


def list_spam_customers(dry_run: bool = True) -> List[Dict]:
    """
    List all customers that match spam criteria.
    
    Returns:
        List of spam customer records with reasons
    """
    client = WooClient()
    
    print(f"\n{'='*60}")
    print(f"{'DRY RUN - ' if dry_run else ''}Identifying Spam Registrations")
    print(f"{'='*60}\n")
    
    print("Fetching all WooCommerce customers...")
    customers = get_existing_woo_customers_full(client)
    print(f"Total customers: {len(customers)}\n")
    
    print("Checking customers for spam criteria...")
    print("(This may take a minute - checking orders for each customer)\n")
    
    spam_customers = []
    
    for i, customer in enumerate(customers, 1):
        if i % 10 == 0 or i == 1:
            print(f"  Checking customer {i}/{len(customers)}...", end='\r')
        
        # Get customer orders
        orders = get_customer_orders(client, customer['id'])
        
        # Check if spam
        is_spam, reasons = is_spam_customer(customer, orders)
        
        if is_spam:
            spam_customers.append({
                'customer': customer,
                'reasons': reasons,
                'order_count': len(orders)
            })
    
    print(f"\n  Checked {len(customers)} customers" + " " * 20)  # Clear progress line
    
    print(f"\n{'='*60}")
    print(f"SPAM REGISTRATIONS FOUND: {len(spam_customers)}")
    print(f"{'='*60}\n")
    
    # Group by reason
    reason_counts = {}
    for item in spam_customers:
        for reason in item['reasons']:
            reason_counts[reason] = reason_counts.get(reason, 0) + 1
    
    print("Spam Detection Reasons:")
    for reason, count in sorted(reason_counts.items(), key=lambda x: x[1], reverse=True):
        print(f"  - {reason}: {count}")
    
    print(f"\n{'='*60}")
    print("SPAM CUSTOMERS:")
    print(f"{'='*60}\n")
    
    for item in spam_customers[:20]:  # Show first 20
        customer = item['customer']
        print(f"ID: {customer['id']}")
        print(f"  Username: {customer.get('username', 'N/A')}")
        print(f"  Email: {customer.get('email', 'N/A')}")
        print(f"  Name: {customer.get('first_name', '')} {customer.get('last_name', '')}")
        print(f"  Company: {customer.get('billing', {}).get('company', 'N/A')}")
        print(f"  Orders: {item['order_count']}")
        print(f"  Reasons: {', '.join(item['reasons'])}")
        print()
    
    if len(spam_customers) > 20:
        print(f"... and {len(spam_customers) - 20} more\n")
    
    return spam_customers


def delete_spam_customers(spam_customers: List[Dict], apply: bool = False) -> tuple[int, int]:
    """
    Delete spam customers from WooCommerce.
    
    Returns:
        Tuple of (deleted_count, error_count)
    """
    client = WooClient()
    
    if not apply:
        print(f"\n{'='*60}")
        print("DRY RUN - Would delete the following customers:")
        print(f"{'='*60}\n")
        for item in spam_customers[:10]:
            customer = item['customer']
            print(f"  - ID {customer['id']}: {customer.get('email', 'N/A')} ({', '.join(item['reasons'])})")
        if len(spam_customers) > 10:
            print(f"  ... and {len(spam_customers) - 10} more")
        print(f"\nTotal: {len(spam_customers)} customers would be deleted")
        print("\nTo actually delete, run with --apply flag")
        return 0, 0
    
    print(f"\n{'='*60}")
    print("DELETING SPAM CUSTOMERS")
    print(f"{'='*60}\n")
    
    deleted = 0
    errors = 0
    
    for i, item in enumerate(spam_customers, 1):
        customer = item['customer']
        customer_id = customer['id']
        email = customer.get('email', 'N/A')
        
        if i % 10 == 0:
            print(f"  Deleting customer {i}/{len(spam_customers)}...")
        
        try:
            # Delete customer via WooCommerce API
            url = client._url(f"/customers/{customer_id}")
            resp = client.session.delete(url, params={"force": True}, timeout=30)
            if resp.ok:
                deleted += 1
            else:
                errors += 1
                print(f"  ERROR deleting customer {customer_id} ({email}): {resp.status_code} {resp.text[:100]}")
        except Exception as e:
            print(f"  ERROR deleting customer {customer_id} ({email}): {e}")
            errors += 1
    
    print(f"\n{'='*60}")
    print(f"DELETION COMPLETE")
    print(f"{'='*60}")
    print(f"Deleted: {deleted}")
    print(f"Errors: {errors}")
    print(f"Total: {len(spam_customers)}")
    
    return deleted, errors


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python cleanup_spam_registrations.py list          # List spam (dry-run)")
        print("  python cleanup_spam_registrations.py delete        # Delete spam (dry-run)")
        print("  python cleanup_spam_registrations.py delete --apply # Actually delete")
        sys.exit(1)
    
    command = sys.argv[1].lower()
    apply = '--apply' in sys.argv
    
    if command == 'list':
        spam_customers = list_spam_customers(dry_run=True)
        print(f"\n✅ Found {len(spam_customers)} spam registrations")
        print("\nTo delete them, run:")
        print("  python cleanup_spam_registrations.py delete --apply")
    
    elif command == 'delete':
        spam_customers = list_spam_customers(dry_run=not apply)
        if spam_customers:
            deleted, errors = delete_spam_customers(spam_customers, apply=apply)
            if apply:
                print(f"\n✅ Deleted {deleted} spam registrations ({errors} errors)")
        else:
            print("\n✅ No spam registrations found")
    
    else:
        print(f"Unknown command: {command}")
        print("Use 'list' or 'delete'")
        sys.exit(1)


if __name__ == '__main__':
    main()

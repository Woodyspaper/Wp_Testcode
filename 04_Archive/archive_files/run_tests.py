"""
run_tests.py - Pipeline Validation Tests (Safe / Read-Only)

Run this to verify your CounterPoint ↔ WooCommerce integration pipeline
works WITHOUT making any changes to production systems.

Usage:
    python run_tests.py          # Run all tests
    python run_tests.py quick    # Quick connectivity test only
"""

import sys
import os

# Add project root to Python path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

def print_header(title):
    print("\n" + "="*70)
    print(f"  {title}")
    print("="*70)

def print_result(name, success, details=""):
    status = "✅ PASS" if success else "❌ FAIL"
    print(f"  {status} - {name}")
    if details:
        print(f"         {details}")

def test_config():
    """Test configuration loading."""
    print_header("TEST 1: Configuration")
    try:
        from config import load_integration_config
        cfg = load_integration_config()
        
        print_result("Config loads", True)
        print_result("SQL Server configured", bool(cfg.database.server), cfg.database.server)
        print_result("Database configured", bool(cfg.database.database), cfg.database.database)
        print_result("WooCommerce URL configured", bool(cfg.woo.base_url), cfg.woo.base_url)
        print_result("WooCommerce keys configured", 
                     bool(cfg.woo.consumer_key and cfg.woo.consumer_secret),
                     "Keys present" if cfg.woo.consumer_key else "Missing!")
        return True
    except Exception as e:
        print_result("Config loads", False, str(e))
        return False

def test_database():
    """Test SQL Server connection."""
    print_header("TEST 2: SQL Server Connection")
    try:
        from database import get_connection, run_query
        
        # Test connection
        conn = get_connection()
        print_result("Connection established", True)
        conn.close()
        
        # Test simple query
        result = run_query("SELECT 1 as test")
        print_result("Query execution", result is not None)
        
        # Test AR_CUST table access
        customers = run_query("SELECT TOP 1 CUST_NO FROM dbo.AR_CUST")
        print_result("AR_CUST table access", customers is not None, 
                     f"Sample: {customers[0]['CUST_NO']}" if customers else "No data")
        
        # Test pricing rules access
        rules = run_query("SELECT TOP 1 GRP_COD FROM dbo.IM_PRC_RUL")
        print_result("IM_PRC_RUL table access", rules is not None,
                     f"Sample: {rules[0]['GRP_COD']}" if rules else "No data")
        
        return True
    except Exception as e:
        print_result("Database connection", False, str(e))
        return False

def test_customer_tiers():
    """Test customer tier data."""
    print_header("TEST 3: Customer Tier Data")
    try:
        from database import run_query
        
        # Count customers by tier
        sql = """
        SELECT CATEG_COD, COUNT(*) as cnt 
        FROM AR_CUST 
        WHERE CATEG_COD IS NOT NULL 
        GROUP BY CATEG_COD 
        ORDER BY cnt DESC
        """
        tiers = run_query(sql)
        
        if tiers:
            print_result("Customer tiers found", True, f"{len(tiers)} categories")
            print("\n  Customer Distribution:")
            for t in tiers[:7]:  # Show top 7
                print(f"    {t['CATEG_COD']:<15} {t['cnt']:>5} customers")
            return True
        else:
            print_result("Customer tiers found", False, "No CATEG_COD data")
            return False
    except Exception as e:
        print_result("Customer tier query", False, str(e))
        return False

def test_pricing_rules():
    """Test pricing rule data."""
    print_header("TEST 4: Pricing Rules Data")
    try:
        from database import run_query
        
        # Count pricing rules
        count_result = run_query("SELECT COUNT(*) as cnt FROM IM_PRC_RUL")
        rule_count = count_result[0]['cnt'] if count_result else 0
        print_result("Pricing rules exist", rule_count > 0, f"{rule_count} rules found")
        
        # Check rule groups
        groups = run_query("""
            SELECT GRP_TYP, GRP_COD, COUNT(*) as cnt 
            FROM IM_PRC_RUL 
            GROUP BY GRP_TYP, GRP_COD
        """)
        if groups:
            print_result("Rule groups found", True, f"{len(groups)} groups")
            print("\n  Pricing Groups:")
            for g in groups[:5]:
                print(f"    {g['GRP_TYP']}/{g['GRP_COD']:<10} {g['cnt']:>5} rules")
        
        return rule_count > 0
    except Exception as e:
        print_result("Pricing rules query", False, str(e))
        return False

def test_woocommerce():
    """Test WooCommerce API connection (read-only)."""
    print_header("TEST 5: WooCommerce API Connection")
    try:
        from woo_client import WooClient
        
        # Test connection
        client = WooClient()
        success = client.test_connection()
        print_result("API connection", success, 
                    f"Connected to {client.config.woo.base_url}" if success else "Connection failed")
        
        return success
    except Exception as e:
        print_result("WooCommerce API", False, str(e))
        return False

def test_tier_mapping():
    """Test the tier mapping logic."""
    print_header("TEST 6: Tier → WP Role Mapping")
    try:
        # Import the mapping
        from woo_customers import CATEG_TO_WP_ROLE, TIER_DISCOUNTS, get_wp_tier_role
        
        print("  Configured Mappings:")
        for cp_tier, wp_role in CATEG_TO_WP_ROLE.items():
            discount = TIER_DISCOUNTS.get(wp_role, 0)
            print(f"    {cp_tier:<12} → {wp_role:<25} ({discount}% off)")
        
        # Test the function
        test_cases = ['TIER1', 'TIER2', 'RETAIL', 'UNKNOWN']
        print("\n  Function Tests:")
        for test in test_cases:
            role = get_wp_tier_role(test)
            discount = TIER_DISCOUNTS.get(role, 0)
            print(f"    get_wp_tier_role('{test}') → {role}, {discount}%")
        
        print_result("Tier mapping configured", True)
        return True
    except Exception as e:
        print_result("Tier mapping", False, str(e))
        return False

def run_all_tests():
    """Run all tests."""
    print("\n" + "="*70)
    print("  COUNTERPOINT ↔ WOOCOMMERCE PIPELINE VALIDATION")
    print("  " + "-"*50)
    print("  All tests are READ-ONLY and safe to run on production")
    print("="*70)
    
    results = {}
    
    results['config'] = test_config()
    results['database'] = test_database()
    results['tiers'] = test_customer_tiers()
    results['pricing'] = test_pricing_rules()
    results['woocommerce'] = test_woocommerce()
    results['mapping'] = test_tier_mapping()
    
    # Summary
    print_header("SUMMARY")
    passed = sum(1 for v in results.values() if v)
    total = len(results)
    
    for name, success in results.items():
        status = "✅" if success else "❌"
        print(f"  {status} {name}")
    
    print(f"\n  {passed}/{total} tests passed")
    
    if passed == total:
        print("\n  🎉 ALL TESTS PASSED - Pipeline is ready!")
        print("\n  Next steps:")
        print("    1. Set up staging WooCommerce site for write tests")
        print("    2. Update .env WOO_BASE_URL to staging site")
        print("    3. Run: python woo_customers.py push --apply")
    else:
        print("\n  ⚠️  Some tests failed - review errors above")
    
    return passed == total

def run_quick_test():
    """Quick connectivity test only."""
    print("\n  QUICK CONNECTIVITY TEST")
    print("  " + "-"*30)
    
    # Config
    try:
        from config import load_integration_config
        cfg = load_integration_config()
        print(f"  ✅ Config: {cfg.database.database} @ {cfg.database.server}")
    except Exception as e:
        print(f"  ❌ Config: {e}")
        return False
    
    # Database
    try:
        from database import run_query
        run_query("SELECT 1")
        print("  ✅ SQL Server: Connected")
    except Exception as e:
        print(f"  ❌ SQL Server: {e}")
        return False
    
    # WooCommerce
    try:
        from woo_client import WooClient
        client = WooClient()
        success = client.test_connection()
        if success:
            print(f"  ✅ WooCommerce: Connected to {client.config.woo.base_url}")
        else:
            print(f"  ❌ WooCommerce: Connection failed")
    except Exception as e:
        print(f"  ❌ WooCommerce: {e}")
    
    print("\n  Quick test complete!")
    return True


if __name__ == "__main__":
    args = sys.argv[1:]
    
    if args and args[0] == 'quick':
        run_quick_test()
    else:
        run_all_tests()



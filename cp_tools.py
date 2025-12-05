"""
cp_tools.py - CounterPoint utilities for WOODYS_CP integration.

Simple functions for:
  - Fetching customers from AR_CUST
  - Fetching/validating contract pricing from IM_PRC_RUL  
  - Comparing CP vs Woo prices

Usage:
    python cp_tools.py customers [--limit 10]
    python cp_tools.py pricing [--validate]
    python cp_tools.py compare [--limit 100]
"""

import csv
import sys
from decimal import Decimal

from database import run_query
from woo_client import WooClient
from config import load_integration_config


# ─────────────────────────────────────────────────────────────────────────────
# SQL QUERIES
# ─────────────────────────────────────────────────────────────────────────────

CUSTOMERS_SQL = """
SELECT {top}
    CUST_NO, NAM, FST_NAM, LST_NAM, EMAIL_ADRS_1, PHONE_1,
    ADRS_1, ADRS_2, CITY, STATE, ZIP_COD, CNTRY,
    CUST_TYP, CATEG_COD, TERMS_COD, TAX_COD
FROM dbo.AR_CUST
WHERE IS_ECOMM_CUST = 'Y'
ORDER BY CUST_NO
"""

PRICING_RULES_SQL = """
SELECT 
    r.RUL_SEQ_NO, r.DESCR, r.GRP_TYP, r.GRP_COD, r.CUST_NO, r.ITEM_NO,
    r.MIN_QTY AS RULE_MIN_QTY,
    b.PRC_METH, b.PRC_BASIS, b.AMT_OR_PCT, b.MIN_QTY AS BRK_MIN_QTY
FROM dbo.IM_PRC_RUL r
LEFT JOIN dbo.IM_PRC_RUL_BRK b ON r.GRP_TYP = b.GRP_TYP 
    AND r.GRP_COD = b.GRP_COD AND r.RUL_SEQ_NO = b.RUL_SEQ_NO
ORDER BY r.RUL_SEQ_NO
"""

PRICES_SQL = """
SELECT {top} ITEM_NO, DESCR, PRC_1, QTY_AVAIL
FROM dbo.VI_IM_ITEM_WITH_INV
WHERE LOC_ID = ? AND IS_ECOMM_ITEM = 'Y'
ORDER BY ITEM_NO
"""


# ─────────────────────────────────────────────────────────────────────────────
# CUSTOMERS
# ─────────────────────────────────────────────────────────────────────────────

def get_customers(limit=None):
    """Fetch e-commerce customers from AR_CUST."""
    top = f"TOP {limit}" if limit else ""
    return run_query(CUSTOMERS_SQL.format(top=top))


def customer_to_woo_payload(c):
    """Convert a customer dict to WooCommerce API payload."""
    email = c.get("EMAIL_ADRS_1") or f"{c['CUST_NO'].lower()}@placeholder.local"
    return {
        "email": email.strip().lower(),
        "first_name": c.get("FST_NAM", ""),
        "last_name": c.get("LST_NAM", ""),
        "billing": {
            "company": c.get("NAM", ""),
            "address_1": c.get("ADRS_1", ""),
            "city": c.get("CITY", ""),
            "state": c.get("STATE", ""),
            "postcode": c.get("ZIP_COD", ""),
            "country": c.get("CNTRY", "US"),
            "phone": c.get("PHONE_1", ""),
        },
        "meta_data": [
            {"key": "cp_cust_no", "value": c["CUST_NO"]},
            {"key": "cp_categ_cod", "value": c.get("CATEG_COD", "")},
        ],
    }


# ─────────────────────────────────────────────────────────────────────────────
# CONTRACT PRICING
# ─────────────────────────────────────────────────────────────────────────────

def get_pricing_rules():
    """Fetch active pricing rules from IM_PRC_RUL."""
    return run_query(PRICING_RULES_SQL)


def validate_pricing_rules(rules):
    """
    Validate pricing rules. Returns (valid_rules, errors).
    
    Checks:
      - Discount 0-90%
      - Has at least one target (customer, item, or group)
    """
    valid, errors = [], []
    
    for r in rules:
        rule_id = r.get("RUL_SEQ_NO", "?")
        amt = r.get("AMT_OR_PCT") or 0
        
        # Check discount range
        if r.get("PRC_METH") == "D" and (amt < 0 or amt > 90):
            errors.append(f"Rule {rule_id}: Discount {amt}% out of range (0-90)")
            continue
        
        # Check has target
        if not any([r.get("CUST_NO"), r.get("ITEM_NO"), r.get("GRP_COD")]):
            errors.append(f"Rule {rule_id}: No target specified")
            continue
        
        valid.append(r)
    
    return valid, errors


def export_rules_to_csv(rules, path="pricing_rules.csv"):
    """Export pricing rules to CSV."""
    if not rules:
        return
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=rules[0].keys())
        w.writeheader()
        w.writerows(rules)
    print(f"Exported {len(rules)} rules to {path}")


# ─────────────────────────────────────────────────────────────────────────────
# PRICE COMPARISON
# ─────────────────────────────────────────────────────────────────────────────

def get_cp_prices(limit=None):
    """Fetch prices from CounterPoint."""
    cfg = load_integration_config()
    top = f"TOP {limit}" if limit else ""
    return run_query(PRICES_SQL.format(top=top), (cfg.default_loc_id,))


def get_woo_prices(limit=100):
    """Fetch prices from WooCommerce. Returns dict of sku -> price."""
    client = WooClient()
    prices = {}
    page = 1
    
    while len(prices) < limit:
        url = client._url("/products")
        resp = client.session.get(url, params={"per_page": 100, "page": page}, timeout=30)
        if not resp.ok:
            break
        data = resp.json()
        if not data:
            break
        for p in data:
            if p.get("sku"):
                prices[p["sku"]] = Decimal(p.get("regular_price") or "0")
        page += 1
    
    return prices


def compare_prices(limit=None):
    """
    Compare CounterPoint vs WooCommerce prices.
    Returns list of mismatches: [{"sku", "name", "cp_price", "woo_price", "diff"}]
    """
    cp_items = get_cp_prices(limit)
    woo_prices = get_woo_prices(limit or 1000)
    
    mismatches = []
    for item in cp_items:
        sku = item["ITEM_NO"]
        cp_price = Decimal(str(item.get("PRC_1") or 0))
        woo_price = woo_prices.get(sku)
        
        if woo_price is None:
            mismatches.append({
                "sku": sku, "name": item.get("DESCR", ""),
                "cp_price": cp_price, "woo_price": None, "status": "NOT_IN_WOO"
            })
        elif cp_price != woo_price:
            mismatches.append({
                "sku": sku, "name": item.get("DESCR", ""),
                "cp_price": cp_price, "woo_price": woo_price, "status": "MISMATCH"
            })
    
    return mismatches


def print_comparison_report(mismatches):
    """Print a simple comparison report."""
    if not mismatches:
        print("✓ All prices match!")
        return
    
    print(f"\n{'SKU':<20} {'Status':<12} {'CP Price':>10} {'Woo Price':>10}")
    print("-" * 55)
    for m in mismatches[:50]:
        cp = f"${m['cp_price']:.2f}" if m['cp_price'] else "N/A"
        woo = f"${m['woo_price']:.2f}" if m['woo_price'] else "N/A"
        print(f"{m['sku']:<20} {m['status']:<12} {cp:>10} {woo:>10}")
    
    if len(mismatches) > 50:
        print(f"... and {len(mismatches) - 50} more")
    print(f"\nTotal mismatches: {len(mismatches)}")


# ─────────────────────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────────────────────

def main():
    """Simple CLI for cp_tools."""
    args = sys.argv[1:]
    cmd = args[0] if args else "help"
    limit = None
    
    # Parse --limit N
    if "--limit" in args:
        idx = args.index("--limit")
        limit = int(args[idx + 1]) if idx + 1 < len(args) else 10
    
    if cmd == "customers":
        customers = get_customers(limit or 10)
        print(f"\n{'CUST_NO':<15} {'NAME':<30} {'EMAIL':<30} {'CATEG':<10}")
        print("-" * 90)
        for c in customers:
            print(f"{c['CUST_NO']:<15} {(c.get('NAM') or '')[:30]:<30} "
                  f"{(c.get('EMAIL_ADRS_1') or '')[:30]:<30} {c.get('CATEG_COD') or '':<10}")
        print(f"\nTotal: {len(customers)} customers")
    
    elif cmd == "pricing":
        rules = get_pricing_rules()
        if "--validate" in args:
            valid, errors = validate_pricing_rules(rules)
            print(f"\nValid rules: {len(valid)}")
            print(f"Errors: {len(errors)}")
            for e in errors[:20]:
                print(f"  ✗ {e}")
        elif "--export" in args:
            export_rules_to_csv(rules)
        else:
            print(f"\nActive pricing rules: {len(rules)}")
            by_method = {}
            for r in rules:
                m = r.get("PRC_METH", "?")
                by_method[m] = by_method.get(m, 0) + 1
            for m, count in sorted(by_method.items()):
                name = {"D": "Discount%", "O": "Override", "M": "Markup%", "A": "Amount Off"}.get(m, m)
                print(f"  {name}: {count}")
    
    elif cmd == "compare":
        print("Comparing CP vs Woo prices...")
        mismatches = compare_prices(limit)
        print_comparison_report(mismatches)
    
    else:
        print("""
cp_tools.py - CounterPoint utilities

Commands:
  customers [--limit N]     List e-commerce customers
  pricing [--validate]      Show/validate pricing rules  
  pricing --export          Export rules to CSV
  compare [--limit N]       Compare CP vs Woo prices

Examples:
  python cp_tools.py customers --limit 20
  python cp_tools.py pricing --validate
  python cp_tools.py compare --limit 100
""")


if __name__ == "__main__":
    main()


"""Show the actual pricing for each tier."""

from database import run_query

print("\n" + "="*70)
print("TIERED PRICING RULES DETAIL")
print("="*70)

# Get the TIERED group rules
sql = """
SELECT 
    r.RUL_SEQ_NO,
    r.DESCR as Tier_Name,
    b.PRC_METH,
    b.AMT_OR_PCT as Discount_Pct,
    r.CUST_FILT_TEXT
FROM IM_PRC_RUL r
LEFT JOIN IM_PRC_RUL_BRK b ON r.GRP_TYP = b.GRP_TYP 
    AND r.GRP_COD = b.GRP_COD 
    AND r.RUL_SEQ_NO = b.RUL_SEQ_NO
WHERE r.GRP_COD = 'TIERED'
ORDER BY r.RUL_SEQ_NO
"""

print("\nTIERED Pricing Group Rules:")
print(f"{'Tier Name':<25} {'Method':>8} {'Discount%':>12}")
print("-"*50)

results = run_query(sql)
for r in results:
    name = (r['Tier_Name'] or '')[:25]
    meth = r['PRC_METH'] or '-'
    disc = f"{r['Discount_Pct']:.1f}%" if r['Discount_Pct'] else '-'
    print(f"{name:<25} {meth:>8} {disc:>12}")

# Also check for customer-specific contract pricing
print("\n" + "="*70)
print("CUSTOMER-SPECIFIC CONTRACT PRICING (Sample)")
print("="*70)

# The numeric GRP_CODs might be customer IDs
sql2 = """
SELECT TOP 5
    r.GRP_COD,
    c.NAM as Customer_Name,
    c.CATEG_COD,
    COUNT(DISTINCT r.RUL_SEQ_NO) as Num_Rules,
    AVG(b.AMT_OR_PCT) as Avg_Discount
FROM IM_PRC_RUL r
JOIN AR_CUST c ON c.CUST_NO = r.GRP_COD
LEFT JOIN IM_PRC_RUL_BRK b ON r.GRP_TYP = b.GRP_TYP 
    AND r.GRP_COD = b.GRP_COD 
    AND r.RUL_SEQ_NO = b.RUL_SEQ_NO
WHERE r.GRP_TYP = 'C'
  AND ISNUMERIC(r.GRP_COD) = 1
GROUP BY r.GRP_COD, c.NAM, c.CATEG_COD
ORDER BY Num_Rules DESC
"""

print("\nCustomers with Custom Contract Pricing:")
print(f"{'CUST_NO':<12} {'Customer':<25} {'Tier':<10} {'Rules':>6} {'Avg Disc':>10}")
print("-"*70)

try:
    results2 = run_query(sql2)
    for r in results2:
        name = (r['Customer_Name'] or '')[:25]
        tier = r['CATEG_COD'] or '-'
        disc = f"{r['Avg_Discount']:.1f}%" if r['Avg_Discount'] else '-'
        print(f"{r['GRP_COD']:<12} {name:<25} {tier:<10} {r['Num_Rules']:>6} {disc:>10}")
except:
    print("  (Could not match GRP_COD to customer numbers)")

print("\n" + "="*70)
print("SUMMARY")
print("="*70)
print("""
Your CounterPoint has TWO types of pricing:

1. TIERED PRICING (GRP_COD = 'TIERED')
   - Applies based on customer's CATEG_COD (TIER1, TIER2, etc.)
   - Same discount % for all customers in that tier

2. CUSTOMER-SPECIFIC CONTRACTS (GRP_TYP = 'C')
   - Individual negotiated prices per customer
   - GRP_COD = Customer Number
   - More specific than tier pricing

For WooCommerce/B2BKing:
   - B2BKing groups = Your CATEG_COD tiers
   - Per-product wholesale prices = Based on tier discounts
""")

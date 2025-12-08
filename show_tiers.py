"""Quick script to show customer tiers and discounts."""

from database import run_query

# Get tier summary with discount info
sql = """
SELECT 
    CATEG_COD,
    COUNT(*) as Customers,
    AVG(DISC_PCT) as Avg_Discount,
    MIN(DISC_PCT) as Min_Discount,
    MAX(DISC_PCT) as Max_Discount
FROM AR_CUST 
WHERE CATEG_COD IS NOT NULL
GROUP BY CATEG_COD
ORDER BY 
    CASE CATEG_COD 
        WHEN 'RETAIL' THEN 1
        WHEN 'TIER1' THEN 2
        WHEN 'TIER2' THEN 3
        WHEN 'TIER3' THEN 4
        WHEN 'TIER4' THEN 5
        WHEN 'GOV-TIER1' THEN 6
        WHEN 'GOV-TIER2' THEN 7
        ELSE 99
    END
"""

print("\n" + "="*70)
print("COUNTERPOINT CUSTOMER TIERS")
print("="*70)
print(f"\n{'CATEGORY':<15} {'Customers':>10} {'Avg Disc%':>12} {'Min':>8} {'Max':>8}")
print("-"*55)

results = run_query(sql)
for r in results:
    avg_disc = f"{r['Avg_Discount']:.1f}%" if r['Avg_Discount'] else "0%"
    min_disc = f"{r['Min_Discount']:.0f}%" if r['Min_Discount'] else "-"
    max_disc = f"{r['Max_Discount']:.0f}%" if r['Max_Discount'] else "-"
    print(f"{r['CATEG_COD']:<15} {r['Customers']:>10} {avg_disc:>12} {min_disc:>8} {max_disc:>8}")

# Show sample customers from each tier
print("\n" + "="*70)
print("SAMPLE CUSTOMERS BY TIER")
print("="*70)

sample_sql = """
SELECT CATEG_COD, CUST_NO, NAM, DISC_PCT
FROM AR_CUST
WHERE CATEG_COD IN ('TIER1','TIER2','TIER3','TIER4','GOV-TIER1','GOV-TIER2')
ORDER BY CATEG_COD, CUST_NO
"""

samples = run_query(sample_sql)
current_tier = None

for r in samples:
    if r['CATEG_COD'] != current_tier:
        current_tier = r['CATEG_COD']
        print(f"\n{current_tier}:")
    disc = f"{r['DISC_PCT']:.0f}%" if r['DISC_PCT'] else "0%"
    print(f"  {r['CUST_NO']:<15} {r['NAM'][:30]:<30} Discount: {disc}")

print("\n" + "="*70)

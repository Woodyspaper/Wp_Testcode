"""Check how pricing rules relate to customer tiers."""

from database import run_query

print("\n" + "="*70)
print("COUNTERPOINT PRICING RULES SUMMARY")
print("="*70)

# Check pricing rule groups
sql = """
SELECT GRP_TYP, GRP_COD, COUNT(*) as Rules
FROM IM_PRC_RUL
GROUP BY GRP_TYP, GRP_COD
ORDER BY GRP_TYP, GRP_COD
"""

print("\nPricing Rule Groups:")
print(f"{'GRP_TYP':<10} {'GRP_COD':<15} {'Rules':>8}")
print("-"*35)
for r in run_query(sql):
    print(f"{r['GRP_TYP']:<10} {r['GRP_COD']:<15} {r['Rules']:>8}")

# Check pricing methods
sql2 = """
SELECT b.PRC_METH, COUNT(*) as cnt,
    CASE b.PRC_METH
        WHEN 'D' THEN 'Discount %'
        WHEN 'O' THEN 'Override Price'
        WHEN 'M' THEN 'Markup %'
        WHEN 'A' THEN 'Amount Off'
        ELSE b.PRC_METH
    END as Method_Name
FROM IM_PRC_RUL_BRK b
GROUP BY b.PRC_METH
ORDER BY cnt DESC
"""

print("\nPricing Methods Used:")
print(f"{'Method':<5} {'Description':<20} {'Count':>8}")
print("-"*35)
for r in run_query(sql2):
    print(f"{r['PRC_METH']:<5} {r['Method_Name']:<20} {r['cnt']:>8}")

# Sample pricing rules with descriptions
sql3 = """
SELECT TOP 20
    r.GRP_TYP, r.GRP_COD, r.RUL_SEQ_NO,
    r.DESCR,
    r.CUST_NO,
    r.ITEM_NO,
    b.PRC_METH,
    b.AMT_OR_PCT
FROM IM_PRC_RUL r
LEFT JOIN IM_PRC_RUL_BRK b ON r.GRP_TYP = b.GRP_TYP 
    AND r.GRP_COD = b.GRP_COD 
    AND r.RUL_SEQ_NO = b.RUL_SEQ_NO
ORDER BY r.GRP_COD, r.RUL_SEQ_NO
"""

print("\nSample Pricing Rules (first 20):")
print(f"{'GRP_COD':<12} {'DESCR':<25} {'CUST_NO':<12} {'ITEM_NO':<15} {'Method':>6} {'Amt/%':>8}")
print("-"*80)
for r in run_query(sql3):
    desc = (r['DESCR'] or '')[:25]
    cust = r['CUST_NO'] or '-'
    item = (r['ITEM_NO'] or '-')[:15]
    meth = r['PRC_METH'] or '-'
    amt = f"{r['AMT_OR_PCT']:.1f}" if r['AMT_OR_PCT'] else '-'
    print(f"{r['GRP_COD']:<12} {desc:<25} {cust:<12} {item:<15} {meth:>6} {amt:>8}")

# Check if any rules reference tier categories
sql4 = """
SELECT DISTINCT r.DESCR, r.GRP_COD
FROM IM_PRC_RUL r
WHERE r.DESCR LIKE '%TIER%' 
   OR r.GRP_COD LIKE '%TIER%'
   OR r.CUST_FILT_TEXT LIKE '%TIER%'
"""

print("\nRules mentioning 'TIER':")
results = run_query(sql4)
if results:
    for r in results:
        print(f"  {r['GRP_COD']}: {r['DESCR']}")
else:
    print("  (No rules found with 'TIER' in name)")

print("\n" + "="*70)
print("NOTE: Your tiers likely work through GRP_COD pricing groups,")
print("not through DISC_PCT. Check if GRP_COD values match your tiers.")
print("="*70)

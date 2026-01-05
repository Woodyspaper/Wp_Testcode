"""Find the orders we just created in CounterPoint"""
from database import run_query

# Find both orders
sql = """
SELECT 
    h.DOC_ID,
    h.TKT_NO,
    h.CUST_NO,
    h.TKT_DT,
    t.SUB_TOT,
    t.TAX_AMT,
    t.TOT
FROM dbo.PS_DOC_HDR h
LEFT JOIN dbo.PS_DOC_HDR_TOT t ON h.DOC_ID = t.DOC_ID AND t.TOT_TYP = 'S'
WHERE h.DOC_ID IN (103398648481, 103398648482)
ORDER BY h.DOC_ID
"""

result = run_query(sql)

if result:
    print("\n" + "="*80)
    print("ORDERS FOUND IN COUNTERPOINT")
    print("="*80)
    for r in result:
        print(f"\nDOC_ID: {r['DOC_ID']}")
        print(f"  Ticket Number: {r['TKT_NO']}")
        print(f"  Customer: {r['CUST_NO']}")
        print(f"  Order Date: {r['TKT_DT']}")
        print(f"  Subtotal: ${r['SUB_TOT']:.2f}")
        print(f"  Tax: ${r['TAX_AMT']:.2f}")
        print(f"  Total: ${r['TOT']:.2f}")
    
    # Get line items
    print("\n" + "="*80)
    print("LINE ITEMS")
    print("="*80)
    
    line_sql = """
    SELECT 
        h.DOC_ID,
        h.TKT_NO,
        l.LIN_SEQ_NO,
        l.ITEM_NO,
        l.DESCR,
        l.QTY_SOLD,
        l.PRC,
        l.EXT_PRC
    FROM dbo.PS_DOC_HDR h
    JOIN dbo.PS_DOC_LIN l ON h.DOC_ID = l.DOC_ID
    WHERE h.DOC_ID IN (103398648481, 103398648482)
    ORDER BY h.DOC_ID, l.LIN_SEQ_NO
    """
    
    lines = run_query(line_sql)
    if lines:
        for line in lines:
            print(f"\n{line['TKT_NO']} - Line {line['LIN_SEQ_NO']}:")
            print(f"  SKU: {line['ITEM_NO']}")
            print(f"  Description: {line['DESCR'][:50]}")
            print(f"  Qty: {line['QTY_SOLD']} @ ${line['PRC']:.2f} = ${line['EXT_PRC']:.2f}")
else:
    print("No orders found with those DOC_IDs")

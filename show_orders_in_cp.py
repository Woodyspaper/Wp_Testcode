"""Quick script to show the two orders in CounterPoint"""
from database import run_query

print("="*80)
print("FINDING YOUR TWO ORDERS IN COUNTERPOINT")
print("="*80)

# Find both orders
sql = """
SELECT 
    h.TKT_NO,
    h.CUST_NO,
    c.NAM AS CustomerName,
    h.TKT_DT,
    h.SHIP_DAT,
    s.WOO_ORDER_ID,
    t.SUB_TOT,
    t.TAX_AMT,
    t.TOT AS TotalAmount
FROM dbo.PS_DOC_HDR h
LEFT JOIN dbo.AR_CUST c ON h.CUST_NO = c.CUST_NO
INNER JOIN dbo.USER_ORDER_STAGING s ON CAST(s.CP_DOC_ID AS BIGINT) = h.DOC_ID
LEFT JOIN dbo.PS_DOC_HDR_TOT t ON h.DOC_ID = t.DOC_ID AND t.TOT_TYP = 'S'
WHERE h.TKT_NO IN ('101-000004', '101-000005')
ORDER BY h.TKT_NO
"""

result = run_query(sql)

if result:
    for r in result:
        print(f"\n{'='*80}")
        print(f"Ticket Number: {r['TKT_NO']}")
        print(f"WooCommerce Order: #{r['WOO_ORDER_ID']}")
        print(f"Customer: {r['CustomerName']} (CUST_NO: {r['CUST_NO']})")
        print(f"Order Date: {r['TKT_DT']}")
        print(f"Ship Date: {r['SHIP_DAT'] or 'Not Shipped Yet'}")
        print(f"Subtotal: ${r['SUB_TOT']:.2f}" if r['SUB_TOT'] else "Subtotal: N/A")
        print(f"Tax: ${r['TAX_AMT']:.2f}" if r['TAX_AMT'] else "Tax: N/A")
        print(f"Total: ${r['TotalAmount']:.2f}" if r['TotalAmount'] else "Total: N/A")
        
        # Get line items
        line_sql = """
        SELECT 
            l.LIN_SEQ_NO,
            l.ITEM_NO,
            l.DESCR,
            l.QTY_SOLD,
            l.PRC,
            l.EXT_PRC
        FROM dbo.PS_DOC_HDR h
        INNER JOIN dbo.PS_DOC_LIN l ON h.DOC_ID = l.DOC_ID
        WHERE h.TKT_NO = ?
        ORDER BY l.LIN_SEQ_NO
        """
        lines = run_query(line_sql, (r['TKT_NO'],))
        
        if lines:
            print(f"\n  Line Items:")
            for line in lines:
                print(f"    Line {line['LIN_SEQ_NO']}: {line['ITEM_NO']} - {line['DESCR'][:40]}")
                print(f"      Qty: {line['QTY_SOLD']} @ ${line['PRC']:.2f} = ${line['EXT_PRC']:.2f}")
        
        # Get shipping address
        ship_sql = """
        SELECT 
            ship.NAM,
            ship.ADRS_1,
            ship.ADRS_2,
            ship.CITY,
            ship.STATE,
            ship.ZIP_COD,
            ship.PHONE_1
        FROM dbo.PS_DOC_HDR h
        LEFT JOIN dbo.AR_SHIP_ADRS ship ON ship.CUST_NO = h.CUST_NO 
            AND ship.SHIP_ADRS_ID = CAST(h.SHIP_TO_CONTACT_ID AS VARCHAR(10))
        WHERE h.TKT_NO = ?
        """
        ship = run_query(ship_sql, (r['TKT_NO'],))
        
        if ship and ship[0].get('NAM'):
            s = ship[0]
            print(f"\n  Shipping Address:")
            print(f"    {s['NAM']}")
            print(f"    {s['ADRS_1']}")
            if s.get('ADRS_2'):
                print(f"    {s['ADRS_2']}")
            print(f"    {s['CITY']}, {s['STATE']} {s['ZIP_COD']}")
            if s.get('PHONE_1'):
                print(f"    Phone: {s['PHONE_1']}")
        else:
            print(f"\n  Shipping Address: Not found or not linked")
    
    print(f"\n{'='*80}")
    print("HOW TO FIND IN COUNTERPOINT UI:")
    print("="*80)
    print("1. Open CounterPoint")
    print("2. Go to: Sales -> Sales Tickets (or Tickets)")
    print("3. Search for ticket number:")
    print("   - Order #15487: Search '101-000004'")
    print("   - Order #15479: Search '101-000005'")
    print("\nOR search by customer name:")
    print("   - Order #15487: Search 'OSCAR GOMEZ'")
    print("   - Order #15479: Search 'Jon Wittenberg' or 'Minuteman Press'")
else:
    print("\n[ERROR] Orders not found in CounterPoint")

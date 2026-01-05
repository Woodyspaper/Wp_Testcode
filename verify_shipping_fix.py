"""Verify shipping addresses are now linked to orders"""
from database import run_query

result = run_query("""
SELECT 
    h.DOC_ID, 
    h.TKT_NO, 
    h.CUST_NO, 
    h.SHIP_TO_CONTACT_ID,
    s.NAM AS ShipName,
    s.ADRS_1 AS ShipAddress,
    s.CITY AS ShipCity,
    s.STATE AS ShipState,
    s.PHONE_1 AS ShipPhone
FROM dbo.PS_DOC_HDR h
LEFT JOIN dbo.AR_SHIP_ADRS s ON h.CUST_NO = s.CUST_NO AND s.SHIP_ADRS_ID = '1'
WHERE h.DOC_ID IN (103398648481, 103398648482)
ORDER BY h.DOC_ID
""")

print("="*80)
print("VERIFICATION: Orders with Shipping Addresses")
print("="*80)

if result:
    for r in result:
        print(f"\nOrder: {r['TKT_NO']} (DOC_ID: {r['DOC_ID']})")
        print(f"  Customer: {r['CUST_NO']}")
        print(f"  SHIP_TO_CONTACT_ID: {r['SHIP_TO_CONTACT_ID'] or '(NULL)'}")
        if r['ShipName']:
            print(f"  Ship To: {r['ShipName']}")
            print(f"  Address: {r['ShipAddress'] or '(empty)'}")
            print(f"  City: {r['ShipCity'] or '(empty)'}, {r['ShipState'] or '(empty)'}")
            print(f"  Phone: {r['ShipPhone'] or '(empty)'}")
        else:
            print("  [WARNING] No ship-to address found")
else:
    print("No orders found")

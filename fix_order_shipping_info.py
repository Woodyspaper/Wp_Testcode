"""Check what shipping info we have in staging vs what's in the orders"""
from database import run_query

# Check staging data
print("="*80)
print("SHIPPING INFO IN STAGING TABLE")
print("="*80)
staging = run_query("""
SELECT STAGING_ID, WOO_ORDER_ID, CUST_NO,
       SHIP_NAM, SHIP_ADRS_1, SHIP_CITY, SHIP_STATE, SHIP_ZIP_COD, SHIP_PHONE,
       CUST_EMAIL
FROM dbo.USER_ORDER_STAGING
WHERE STAGING_ID IN (28, 29)
ORDER BY STAGING_ID
""")

if staging:
    for s in staging:
        print(f"\nSTAGING_ID: {s['STAGING_ID']} (WOO_ORDER_ID: {s['WOO_ORDER_ID']})")
        print(f"  Customer: {s['CUST_NO']}")
        print(f"  Ship Name: {s['SHIP_NAM'] or '(empty)'}")
        print(f"  Address: {s['SHIP_ADRS_1'] or '(empty)'}")
        print(f"  City: {s['SHIP_CITY'] or '(empty)'}")
        print(f"  State: {s['SHIP_STATE'] or '(empty)'}")
        print(f"  Zip: {s['SHIP_ZIP_COD'] or '(empty)'}")
        print(f"  Phone: {s['SHIP_PHONE'] or '(empty)'}")
        print(f"  Email: {s['CUST_EMAIL'] or '(empty)'}")

# Check what's in the orders
print("\n" + "="*80)
print("SHIPPING INFO IN PS_DOC_HDR (Current Orders)")
print("="*80)
orders = run_query("""
SELECT h.DOC_ID, h.TKT_NO, h.CUST_NO, h.SHIP_TO_CONTACT_ID
FROM dbo.PS_DOC_HDR h
WHERE h.DOC_ID IN (103398648481, 103398648482)
ORDER BY h.DOC_ID
""")

if orders:
    for o in orders:
        print(f"\nDOC_ID: {o['DOC_ID']} (TKT_NO: {o['TKT_NO']})")
        print(f"  Customer: {o['CUST_NO']}")
        print(f"  SHIP_TO_CONTACT_ID: {o['SHIP_TO_CONTACT_ID'] or '(NULL)'}")

# Check customer info
print("\n" + "="*80)
print("CUSTOMER INFO IN AR_CUST")
print("="*80)
customers = run_query("""
SELECT CUST_NO, NAM, EMAIL_ADRS_1, PHONE_1, ADRS_1, CITY, STATE
FROM dbo.AR_CUST
WHERE CUST_NO IN ('10057', '10022')
ORDER BY CUST_NO
""")

if customers:
    for c in customers:
        print(f"\nCustomer: {c['CUST_NO']}")
        print(f"  Name: {c['NAM'] or '(empty)'}")
        print(f"  Email: {c['EMAIL_ADRS_1'] or '(empty)'}")
        print(f"  Phone: {c['PHONE_1'] or '(empty)'}")
        print(f"  Address: {c['ADRS_1'] or '(empty)'}")
        print(f"  City: {c['CITY'] or '(empty)'}")

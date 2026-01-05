"""Check what fields in PS_DOC_HDR indicate fulfillment/shipping status"""
from database import run_query

print("="*80)
print("CHECKING FULFILLMENT/SHIPPING FIELDS IN PS_DOC_HDR")
print("="*80)

# Check for status/shipment related columns
fields = run_query("""
    SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'dbo' 
      AND TABLE_NAME = 'PS_DOC_HDR'
      AND (COLUMN_NAME LIKE '%STAT%' 
           OR COLUMN_NAME LIKE '%SHIP%'
           OR COLUMN_NAME LIKE '%INVC%'
           OR COLUMN_NAME LIKE '%FULFILL%'
           OR COLUMN_NAME LIKE '%COMPLETE%')
    ORDER BY COLUMN_NAME
""")

if fields:
    print("\nFulfillment/Status Related Columns:")
    print("-" * 80)
    for f in fields:
        nullable = "NULL" if f['IS_NULLABLE'] == 'YES' else "NOT NULL"
        print(f"  {f['COLUMN_NAME']:<30} {f['DATA_TYPE']:<20} {nullable}")
else:
    print("\n[INFO] No obvious fulfillment/status columns found")

# Check our two orders to see what fields have values
print("\n" + "="*80)
print("CHECKING ACTUAL ORDER DATA FOR FULFILLMENT INDICATORS")
print("="*80)

orders = run_query("""
    SELECT DOC_ID, TKT_NO, TKT_DT, SHIP_DAT, SHIP_VIA_COD, LST_MAINT_DT
    FROM dbo.PS_DOC_HDR
    WHERE DOC_ID IN (103398648481, 103398648482)
    ORDER BY DOC_ID
""")

if orders:
    for o in orders:
        print(f"\nOrder {o['TKT_NO']} (DOC_ID: {o['DOC_ID']}):")
        print(f"  Order Date (TKT_DT): {o['TKT_DT']}")
        print(f"  Ship Date (SHIP_DAT): {o['SHIP_DAT'] or '(NULL - not shipped yet)'}")
        print(f"  Shipping Method: {o['SHIP_VIA_COD'] or '(NULL)'}")
        print(f"  Last Maintenance: {o['LST_MAINT_DT'] or '(NULL)'}")
        
        if o['SHIP_DAT']:
            print(f"  [FULFILLMENT INDICATOR] SHIP_DAT is set - order may be shipped!")
        else:
            print(f"  [INFO] SHIP_DAT is NULL - order not yet shipped")
else:
    print("\n[ERROR] Orders not found")

# Check if there are any other status-related tables
print("\n" + "="*80)
print("CHECKING FOR STATUS/TRACKING TABLES")
print("="*80)

tables = run_query("""
    SELECT TABLE_NAME
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'dbo'
      AND (TABLE_NAME LIKE '%STAT%'
           OR TABLE_NAME LIKE '%TRACK%'
           OR TABLE_NAME LIKE '%SHIP%'
           OR TABLE_NAME LIKE '%FULFILL%')
    ORDER BY TABLE_NAME
""")

if tables:
    print("\nPotential Status/Tracking Tables:")
    for t in tables:
        print(f"  {t['TABLE_NAME']}")
else:
    print("\n[INFO] No obvious status/tracking tables found")

"""Check if orders were processed and their status"""
from database import run_query

# Check staging table
print("="*80)
print("ORDER PROCESSING STATUS")
print("="*80)

staging = run_query("""
    SELECT STAGING_ID, WOO_ORDER_ID, CP_DOC_ID, IS_APPLIED, APPLIED_DT
    FROM dbo.USER_ORDER_STAGING
    WHERE STAGING_ID IN (28, 29)
    ORDER BY STAGING_ID
""")

if staging:
    for s in staging:
        print(f"\nWooCommerce Order #{s['WOO_ORDER_ID']} (STAGING_ID: {s['STAGING_ID']}):")
        print(f"  CP_DOC_ID: {s['CP_DOC_ID'] or '(not created)'}")
        print(f"  IS_APPLIED: {s['IS_APPLIED']}")
        print(f"  APPLIED_DT: {s['APPLIED_DT'] or '(not applied)'}")
        
        if s['CP_DOC_ID']:
            # Check if order exists in CounterPoint
            cp_order = run_query("""
                SELECT DOC_ID, TKT_NO, CUST_NO, TKT_DT
                FROM dbo.PS_DOC_HDR
                WHERE DOC_ID = ?
            """, (int(s['CP_DOC_ID']),))
            
            if cp_order:
                o = cp_order[0]
                print(f"  [OK] Order exists in CounterPoint:")
                print(f"      Ticket Number: {o['TKT_NO']}")
                print(f"      Customer: {o['CUST_NO']}")
                print(f"      Date: {o['TKT_DT']}")
            else:
                print(f"  [ERROR] CP_DOC_ID exists but order not found in PS_DOC_HDR")
        else:
            print(f"  [PENDING] Order not yet processed into CounterPoint")

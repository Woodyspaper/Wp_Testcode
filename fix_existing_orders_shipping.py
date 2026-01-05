"""Add shipping addresses to the two existing orders"""
from database import get_connection

conn = get_connection()
cursor = conn.cursor()

try:
    # Get staging data for the two orders
    cursor.execute("""
        SELECT STAGING_ID, CUST_NO, SHIP_NAM, SHIP_ADRS_1, SHIP_ADRS_2, 
               SHIP_CITY, SHIP_STATE, SHIP_ZIP_COD, SHIP_CNTRY, SHIP_PHONE
        FROM dbo.USER_ORDER_STAGING
        WHERE STAGING_ID IN (28, 29)
        ORDER BY STAGING_ID
    """)
    staging_records = cursor.fetchall()
    
    # Get the DOC_IDs for these orders (match by staging ID)
    cursor.execute("""
        SELECT s.STAGING_ID, s.CUST_NO, s.CP_DOC_ID
        FROM dbo.USER_ORDER_STAGING s
        WHERE s.STAGING_ID IN (28, 29) AND s.CP_DOC_ID IS NOT NULL
    """)
    orders = cursor.fetchall()
    
    print("="*80)
    print("FIXING EXISTING ORDERS - Adding Shipping Addresses")
    print("="*80)
    
    for order in orders:
        staging_id = order[0]
        cust_no = order[1]
        doc_id_str = order[2]
        
        # Convert DOC_ID string to bigint
        try:
            doc_id = int(doc_id_str)
        except:
            print(f"\n[SKIP] Invalid DOC_ID for staging {staging_id}: {doc_id_str}")
            continue
        
        # Find matching staging record
        staging = next((s for s in staging_records if s[0] == staging_id), None)
        if not staging:
            print(f"\n[SKIP] No staging record found for DOC_ID {doc_id}")
            continue
        
        ship_nam = staging[2]
        ship_adrs1 = staging[3]
        ship_adrs2 = staging[4]
        ship_city = staging[5]
        ship_state = staging[6]
        ship_zip = staging[7]
        ship_cntry = staging[8] or 'US'
        ship_phone = staging[9]
        
        print(f"\nProcessing DOC_ID: {doc_id} (Customer: {cust_no})")
        print(f"  Ship To: {ship_nam}")
        print(f"  Address: {ship_adrs1}")
        
        # Check if ship-to address already exists
        cursor.execute("""
            SELECT TOP 1 SHIP_ADRS_ID
            FROM dbo.AR_SHIP_ADRS
            WHERE CUST_NO = ? AND ADRS_1 = ? AND CITY = ? AND STATE = ?
        """, (cust_no, ship_adrs1, ship_city, ship_state))
        existing = cursor.fetchone()
        
        if existing:
            ship_adrs_id = existing[0]
            print(f"  [FOUND] Existing ship-to address: {ship_adrs_id}")
        else:
            # Generate new SHIP_ADRS_ID
            cursor.execute("""
                SELECT ISNULL(MAX(TRY_CAST(SHIP_ADRS_ID AS INT)), 0) + 1
                FROM dbo.AR_SHIP_ADRS
                WHERE CUST_NO = ? AND TRY_CAST(SHIP_ADRS_ID AS INT) IS NOT NULL
            """, (cust_no,))
            next_id = cursor.fetchone()[0]
            ship_adrs_id = str(next_id)
            
            # Create ship-to address
            cursor.execute("""
                INSERT INTO dbo.AR_SHIP_ADRS (
                    CUST_NO, SHIP_ADRS_ID, NAM, NAM_UPR,
                    ADRS_1, ADRS_2, CITY, STATE, ZIP_COD, CNTRY,
                    PHONE_1
                )
                VALUES (?, ?, ?, UPPER(?), ?, ?, ?, UPPER(?), ?, UPPER(?), ?)
            """, (
                cust_no, ship_adrs_id,
                ship_nam[:40] if ship_nam else None,
                ship_nam[:40] if ship_nam else None,
                ship_adrs1[:40] if ship_adrs1 else None,
                ship_adrs2[:40] if ship_adrs2 else None,
                ship_city[:20] if ship_city else None,
                ship_state[:10] if ship_state else None,
                ship_zip[:15] if ship_zip else None,
                ship_cntry[:20] if ship_cntry else 'US',
                ship_phone[:25] if ship_phone else None
            ))
            print(f"  [CREATED] New ship-to address: {ship_adrs_id}")
        
        # Update order with SHIP_TO_CONTACT_ID (use 1 for first ship-to)
        cursor.execute("""
            UPDATE dbo.PS_DOC_HDR
            SET SHIP_TO_CONTACT_ID = 1
            WHERE DOC_ID = ?
        """, (doc_id,))
        print(f"  [LINKED] Order linked to ship-to address")
    
    conn.commit()
    print("\n" + "="*80)
    print("[OK] All orders updated with shipping addresses")
    print("="*80)
    
except Exception as e:
    conn.rollback()
    print(f"\n[ERROR] Failed: {e}")
    import traceback
    traceback.print_exc()
finally:
    cursor.close()
    conn.close()

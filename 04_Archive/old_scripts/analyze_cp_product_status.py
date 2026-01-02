"""
analyze_cp_product_status.py - Analyze CounterPoint product status breakdown

Shows:
  - Active vs Inactive products
  - E-commerce vs Non-e-commerce
  - Discontinued products (if field exists)
  - Stock status breakdown
  - Category breakdown
"""

import sys
from collections import defaultdict
from database import connection_ctx


def analyze_product_status():
    """Analyze product status in CounterPoint database."""
    
    print("=" * 80)
    print("COUNTERPOINT PRODUCT STATUS ANALYSIS")
    print("=" * 80)
    print()
    
    try:
        with connection_ctx() as conn:
            cur = conn.cursor()
            
            # First, check what status fields are available in IM_ITEM
            print("Checking available status fields in IM_ITEM table...")
            cur.execute("""
                SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
                FROM INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_SCHEMA = 'dbo'
                  AND TABLE_NAME = 'IM_ITEM'
                  AND (COLUMN_NAME LIKE '%STAT%' 
                       OR COLUMN_NAME LIKE '%ACTIVE%'
                       OR COLUMN_NAME LIKE '%INACTIVE%'
                       OR COLUMN_NAME LIKE '%DISCONT%'
                       OR COLUMN_NAME LIKE '%ECOMM%'
                       OR COLUMN_NAME LIKE '%STOCK%')
                ORDER BY COLUMN_NAME;
            """)
            
            status_fields = cur.fetchall()
            if status_fields:
                print("  Found status-related fields:")
                for field in status_fields:
                    print(f"    - {field[0]} ({field[1]}, Nullable: {field[2]})")
            else:
                print("  No obvious status fields found")
            print()
            
            # Get total product count
            cur.execute("SELECT COUNT(*) FROM dbo.IM_ITEM WHERE ITEM_NO IS NOT NULL")
            total_products = cur.fetchone()[0]
            print(f"Total Products in CounterPoint: {total_products:,}")
            print()
            
            # Analyze by IS_ECOMM_ITEM (E-commerce flag)
            print("=" * 80)
            print("E-COMMERCE STATUS BREAKDOWN")
            print("=" * 80)
            cur.execute("""
                SELECT 
                    IS_ECOMM_ITEM,
                    COUNT(*) AS COUNT,
                    COUNT(CASE WHEN IS_ECOMM_ITEM = 'Y' THEN 1 END) AS ECOMM_COUNT,
                    COUNT(CASE WHEN IS_ECOMM_ITEM = 'N' OR IS_ECOMM_ITEM IS NULL THEN 1 END) AS NON_ECOMM_COUNT
                FROM dbo.IM_ITEM
                WHERE ITEM_NO IS NOT NULL
                GROUP BY IS_ECOMM_ITEM
                ORDER BY IS_ECOMM_ITEM;
            """)
            
            ecomm_results = cur.fetchall()
            ecomm_active = 0
            ecomm_inactive = 0
            
            for row in ecomm_results:
                status = row[0] if row[0] else 'NULL'
                count = row[1]
                if status == 'Y':
                    ecomm_active = count
                    print(f"  E-Commerce Active (IS_ECOMM_ITEM = 'Y'): {count:,}")
                else:
                    ecomm_inactive += count
                    print(f"  Non-E-Commerce (IS_ECOMM_ITEM = '{status}'): {count:,}")
            
            print(f"\n  Total E-Commerce Active: {ecomm_active:,}")
            print(f"  Total Non-E-Commerce: {ecomm_inactive:,}")
            print()
            
            # Check for ECOMM_PUB_STAT field (publish status)
            print("=" * 80)
            print("PUBLISH STATUS (ECOMM_PUB_STAT)")
            print("=" * 80)
            cur.execute("""
                SELECT 
                    ECOMM_PUB_STAT,
                    COUNT(*) AS COUNT
                FROM dbo.IM_ITEM
                WHERE ITEM_NO IS NOT NULL
                GROUP BY ECOMM_PUB_STAT
                ORDER BY ECOMM_PUB_STAT;
            """)
            
            pub_status = cur.fetchall()
            if pub_status:
                for row in pub_status:
                    stat = row[0] if row[0] is not None else 'NULL'
                    count = row[1]
                    print(f"  Status {stat}: {count:,}")
            else:
                print("  No publish status data found")
            print()
            
            # Check for discontinued/inactive flags
            print("=" * 80)
            print("CHECKING FOR DISCONTINUED/INACTIVE FIELDS")
            print("=" * 80)
            
            # Common field names for discontinued status
            possible_fields = ['INACTIVE_FLG', 'DISCONT_FLG', 'STATUS', 'ITEM_STATUS', 
                             'ACTIVE_FLG', 'INACTIVE', 'DISCONTINUED']
            
            for field_name in possible_fields:
                try:
                    cur.execute(f"""
                        SELECT TOP 1 {field_name}
                        FROM dbo.IM_ITEM
                        WHERE {field_name} IS NOT NULL;
                    """)
                    result = cur.fetchone()
                    if result:
                        print(f"  Found field: {field_name}")
                        # Get breakdown
                        cur.execute(f"""
                            SELECT 
                                {field_name},
                                COUNT(*) AS COUNT
                            FROM dbo.IM_ITEM
                            WHERE ITEM_NO IS NOT NULL
                            GROUP BY {field_name}
                            ORDER BY {field_name};
                        """)
                        breakdown = cur.fetchall()
                        for row in breakdown:
                            val = row[0] if row[0] is not None else 'NULL'
                            count = row[1]
                            print(f"    {val}: {count:,}")
                except Exception:
                    pass  # Field doesn't exist - not critical
            
            print()
            
            # Check STAT field (likely the main status field)
            print("=" * 80)
            print("PRODUCT STATUS (STAT FIELD)")
            print("=" * 80)
            cur.execute("""
                SELECT 
                    STAT,
                    COUNT(*) AS COUNT,
                    SUM(CASE WHEN IS_ECOMM_ITEM = 'Y' THEN 1 ELSE 0 END) AS ECOMM_COUNT
                FROM dbo.IM_ITEM
                WHERE ITEM_NO IS NOT NULL
                GROUP BY STAT
                ORDER BY COUNT DESC;
            """)
            
            stat_results = cur.fetchall()
            for row in stat_results:
                stat = row[0] if row[0] else 'NULL'
                count = row[1]
                ecomm = row[2]
                print(f"  Status '{stat}': {count:,} total ({ecomm:,} e-commerce)")
            print()
            
            # Check RS_STAT field
            print("=" * 80)
            print("RS_STAT FIELD (Possible Status)")
            print("=" * 80)
            cur.execute("""
                SELECT 
                    RS_STAT,
                    COUNT(*) AS COUNT,
                    SUM(CASE WHEN IS_ECOMM_ITEM = 'Y' THEN 1 ELSE 0 END) AS ECOMM_COUNT
                FROM dbo.IM_ITEM
                WHERE ITEM_NO IS NOT NULL
                GROUP BY RS_STAT
                ORDER BY RS_STAT;
            """)
            
            rs_stat_results = cur.fetchall()
            for row in rs_stat_results:
                stat = row[0] if row[0] is not None else 'NULL'
                count = row[1]
                ecomm = row[2]
                print(f"  RS_STAT {stat}: {count:,} total ({ecomm:,} e-commerce)")
            print()
            
            # Stock status breakdown (fixed query)
            print("=" * 80)
            print("STOCK STATUS BREAKDOWN")
            print("=" * 80)
            cur.execute("""
                WITH StockSummary AS (
                    SELECT 
                        i.ITEM_NO,
                        SUM(inv.QTY_ON_HND) AS TOTAL_STOCK
                    FROM dbo.IM_ITEM i
                    LEFT JOIN dbo.IM_INV inv ON inv.ITEM_NO = i.ITEM_NO
                    WHERE i.ITEM_NO IS NOT NULL
                    GROUP BY i.ITEM_NO
                )
                SELECT 
                    CASE 
                        WHEN TOTAL_STOCK > 0 THEN 'IN_STOCK'
                        WHEN TOTAL_STOCK = 0 THEN 'OUT_OF_STOCK'
                        WHEN TOTAL_STOCK < 0 THEN 'ON_ORDER'
                        ELSE 'NO_INVENTORY_DATA'
                    END AS STOCK_STATUS,
                    COUNT(*) AS PRODUCT_COUNT
                FROM StockSummary
                GROUP BY 
                    CASE 
                        WHEN TOTAL_STOCK > 0 THEN 'IN_STOCK'
                        WHEN TOTAL_STOCK = 0 THEN 'OUT_OF_STOCK'
                        WHEN TOTAL_STOCK < 0 THEN 'ON_ORDER'
                        ELSE 'NO_INVENTORY_DATA'
                    END
                ORDER BY PRODUCT_COUNT DESC;
            """)
            
            stock_results = cur.fetchall()
            for row in stock_results:
                status = row[0]
                count = row[1]
                print(f"  {status}: {count:,}")
            print()
            
            # Category breakdown
            print("=" * 80)
            print("TOP 10 CATEGORIES")
            print("=" * 80)
            cur.execute("""
                SELECT TOP 10
                    CATEG_COD,
                    COUNT(*) AS PRODUCT_COUNT,
                    SUM(CASE WHEN IS_ECOMM_ITEM = 'Y' THEN 1 ELSE 0 END) AS ECOMM_COUNT
                FROM dbo.IM_ITEM
                WHERE ITEM_NO IS NOT NULL
                  AND CATEG_COD IS NOT NULL
                GROUP BY CATEG_COD
                ORDER BY PRODUCT_COUNT DESC;
            """)
            
            category_results = cur.fetchall()
            for row in category_results:
                category = row[0]
                total = row[1]
                ecomm = row[2]
                print(f"  {category:20} | Total: {total:4,} | E-Commerce: {ecomm:4,}")
            print()
            
            # Check for stocked vs non-stocked items
            print("=" * 80)
            print("STOCKED vs NON-STOCKED ITEMS")
            print("=" * 80)
            
            # Check for common stocked flags
            stocked_fields = ['STOCKED_FLG', 'STOCKED', 'TRACK_INV', 'TRACK_INVENTORY', 
                            'INV_TRACK', 'STOCK_ITEM', 'NON_STOCK']
            
            found_stocked_field = None
            for field_name in stocked_fields:
                try:
                    cur.execute(f"""
                        SELECT TOP 1 {field_name}
                        FROM dbo.IM_ITEM
                        WHERE {field_name} IS NOT NULL;
                    """)
                    result = cur.fetchone()
                    if result:
                        found_stocked_field = field_name
                        print(f"  Found stocked field: {field_name}")
                        # Get breakdown
                        cur.execute(f"""
                            SELECT 
                                {field_name},
                                COUNT(*) AS COUNT,
                                SUM(CASE WHEN IS_ECOMM_ITEM = 'Y' THEN 1 ELSE 0 END) AS ECOMM_COUNT
                            FROM dbo.IM_ITEM
                            WHERE ITEM_NO IS NOT NULL
                            GROUP BY {field_name}
                            ORDER BY {field_name};
                        """)
                        breakdown = cur.fetchall()
                        for row in breakdown:
                            val = row[0] if row[0] is not None else 'NULL'
                            count = row[1]
                            ecomm = row[2]
                            print(f"    {val}: {count:,} total ({ecomm:,} e-commerce)")
                        break
                except Exception:
                    pass  # Field doesn't exist - not critical
            
            if not found_stocked_field:
                print("  No explicit stocked flag found. Checking inventory table presence...")
                # Check if items have inventory records (using CTE to avoid GROUP BY issue)
                cur.execute("""
                    WITH ItemInventory AS (
                        SELECT 
                            i.ITEM_NO,
                            i.IS_ECOMM_ITEM,
                            CASE 
                                WHEN EXISTS (SELECT 1 FROM dbo.IM_INV inv WHERE inv.ITEM_NO = i.ITEM_NO) 
                                THEN 'HAS_INVENTORY_RECORD'
                                ELSE 'NO_INVENTORY_RECORD'
                            END AS INVENTORY_STATUS
                        FROM dbo.IM_ITEM i
                        WHERE i.ITEM_NO IS NOT NULL
                    )
                    SELECT 
                        INVENTORY_STATUS,
                        COUNT(*) AS COUNT,
                        SUM(CASE WHEN IS_ECOMM_ITEM = 'Y' THEN 1 ELSE 0 END) AS ECOMM_COUNT
                    FROM ItemInventory
                    GROUP BY INVENTORY_STATUS
                    ORDER BY COUNT DESC;
                """)
                
                inv_results = cur.fetchall()
                for row in inv_results:
                    status = row[0]
                    count = row[1]
                    ecomm = row[2]
                    print(f"  {status}: {count:,} total ({ecomm:,} e-commerce)")
            
            print()
            
            # Detailed breakdown: Stocked vs Non-Stocked by Status
            print("=" * 80)
            print("STOCKED/NON-STOCKED BREAKDOWN BY STATUS")
            print("=" * 80)
            cur.execute("""
                WITH ItemInventory AS (
                    SELECT 
                        i.ITEM_NO,
                        i.STAT,
                        i.IS_ECOMM_ITEM,
                        CASE 
                            WHEN EXISTS (SELECT 1 FROM dbo.IM_INV inv WHERE inv.ITEM_NO = i.ITEM_NO) 
                            THEN 'STOCKED'
                            ELSE 'NON-STOCKED'
                        END AS STOCK_TYPE
                    FROM dbo.IM_ITEM i
                    WHERE i.ITEM_NO IS NOT NULL
                )
                SELECT 
                    STAT,
                    STOCK_TYPE,
                    COUNT(*) AS COUNT,
                    SUM(CASE WHEN IS_ECOMM_ITEM = 'Y' THEN 1 ELSE 0 END) AS ECOMM_COUNT
                FROM ItemInventory
                GROUP BY STAT, STOCK_TYPE
                ORDER BY STAT, STOCK_TYPE;
            """)
            
            stock_status_results = cur.fetchall()
            for row in stock_status_results:
                stat = row[0]
                stock_type = row[1]
                count = row[2]
                ecomm = row[3]
                print(f"  Status '{stat}' - {stock_type}: {count:,} total ({ecomm:,} e-commerce)")
            print()
            
            # Summary by status for WooCommerce sync
            print("=" * 80)
            print("SUMMARY FOR WOOCOMMERCE SYNC")
            print("=" * 80)
            cur.execute("""
                WITH ItemInventory AS (
                    SELECT 
                        i.ITEM_NO,
                        i.IS_ECOMM_ITEM,
                        CASE 
                            WHEN EXISTS (SELECT 1 FROM dbo.IM_INV inv WHERE inv.ITEM_NO = i.ITEM_NO) 
                            THEN 1
                            ELSE 0
                        END AS HAS_INVENTORY
                    FROM dbo.IM_ITEM i
                    WHERE i.ITEM_NO IS NOT NULL
                )
                SELECT 
                    COUNT(*) AS TOTAL,
                    SUM(CASE WHEN IS_ECOMM_ITEM = 'Y' THEN 1 ELSE 0 END) AS READY_TO_SYNC,
                    SUM(CASE WHEN IS_ECOMM_ITEM = 'N' OR IS_ECOMM_ITEM IS NULL THEN 1 ELSE 0 END) AS NOT_READY,
                    SUM(CASE WHEN IS_ECOMM_ITEM = 'Y' AND HAS_INVENTORY = 1 THEN 1 ELSE 0 END) AS ECOMM_STOCKED,
                    SUM(CASE WHEN IS_ECOMM_ITEM = 'Y' AND HAS_INVENTORY = 0 THEN 1 ELSE 0 END) AS ECOMM_NON_STOCKED
                FROM ItemInventory;
            """)
            
            summary = cur.fetchone()
            print(f"  Total Products: {summary[0]:,}")
            print(f"  Ready to Sync (E-Commerce Active): {summary[1]:,}")
            print(f"    - Stocked Items: {summary[3]:,}")
            print(f"    - Non-Stocked Items: {summary[4]:,}")
            print(f"  Not Ready (Non-E-Commerce): {summary[2]:,}")
            print()
            
    except Exception as ex:
        print(f"ERROR: {ex}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    analyze_product_status()


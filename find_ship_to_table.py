"""Find ship-to address tables in CounterPoint"""
from database import run_query

# Check for common ship-to table names
tables_to_check = [
    'PS_SHIP_TO',
    'AR_SHIP_TO',
    'SHIP_TO',
    'PS_DOC_SHIP_TO',
    'AR_CUST_SHIP_TO',
    'CUST_SHIP_TO'
]

print("Checking for ship-to address tables...\n")

for table in tables_to_check:
    sql = f"""
    SELECT TABLE_NAME 
    FROM INFORMATION_SCHEMA.TABLES 
    WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = '{table}'
    """
    result = run_query(sql)
    if result:
        print(f"✅ Found table: {table}")
        # Get columns
        cols_sql = f"""
        SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = '{table}'
        ORDER BY ORDINAL_POSITION
        """
        cols = run_query(cols_sql)
        if cols:
            print(f"   Columns ({len(cols)}):")
            for c in cols[:20]:  # Show first 20
                max_len = f"({c['CHARACTER_MAXIMUM_LENGTH']})" if c['CHARACTER_MAXIMUM_LENGTH'] else ""
                print(f"     {c['COLUMN_NAME']:<30} {c['DATA_TYPE']:<15} {max_len}")
            if len(cols) > 20:
                print(f"     ... and {len(cols) - 20} more")
        print()

# Also check what SHIP_TO_CONTACT_ID might reference
print("\nChecking AR_CUST for contact/ship-to fields...")
cust_cols = run_query("""
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo' 
  AND TABLE_NAME = 'AR_CUST'
  AND (COLUMN_NAME LIKE '%SHIP%' OR COLUMN_NAME LIKE '%CONTACT%' OR COLUMN_NAME LIKE '%ADRS%')
ORDER BY COLUMN_NAME
""")
if cust_cols:
    for c in cust_cols:
        max_len = f"({c['CHARACTER_MAXIMUM_LENGTH']})" if c['CHARACTER_MAXIMUM_LENGTH'] else ""
        print(f"  {c['COLUMN_NAME']:<30} {c['DATA_TYPE']:<15} {max_len}")

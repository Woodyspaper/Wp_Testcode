"""
show_schema.py - Quick schema dump for key CounterPoint tables.
Just run: python show_schema.py
"""

from database import run_query

def show_columns(table_name):
    """Show columns for a table."""
    sql = """
    SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = ?
    ORDER BY ORDINAL_POSITION
    """
    rows = run_query(sql, (table_name,), suppress_errors=True)
    
    if not rows:
        print(f"  Table '{table_name}' not found")
        return
    
    for r in rows:
        dtype = r['DATA_TYPE']
        if r['CHARACTER_MAXIMUM_LENGTH']:
            dtype += f"({r['CHARACTER_MAXIMUM_LENGTH']})"
        null = "NULL" if r['IS_NULLABLE'] == 'YES' else "NOT NULL"
        print(f"  {r['COLUMN_NAME']:<30} {dtype:<20} {null}")


def search_columns(keyword):
    """Find columns containing keyword."""
    sql = """
    SELECT TABLE_NAME, COLUMN_NAME
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE COLUMN_NAME LIKE ?
    ORDER BY TABLE_NAME, COLUMN_NAME
    """
    rows = run_query(sql, (f"%{keyword}%",), suppress_errors=True)
    return rows


print("=" * 70)
print("COUNTERPOINT SCHEMA EXPLORER")
print("=" * 70)

# 1. IM_PRC_RUL columns
print("\n>>> IM_PRC_RUL (Pricing Rules) <<<")
print("-" * 70)
show_columns("IM_PRC_RUL")

# 2. IM_PRC_RUL_BRK columns
print("\n>>> IM_PRC_RUL_BRK (Pricing Rule Breaks) <<<")
print("-" * 70)
show_columns("IM_PRC_RUL_BRK")

# 3. Search for PRC_COD columns
print("\n>>> Columns containing 'PRC_COD' <<<")
print("-" * 70)
results = search_columns("PRC_COD")
if results:
    for r in results:
        print(f"  {r['TABLE_NAME']}.{r['COLUMN_NAME']}")
else:
    print("  No columns found with 'PRC_COD'")

# 4. AR_CUST key columns
print("\n>>> AR_CUST (Customers) - Key Fields <<<")
print("-" * 70)
show_columns("AR_CUST")

print("\n" + "=" * 70)
print("DONE")
print("=" * 70)

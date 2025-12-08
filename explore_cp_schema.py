"""
explore_cp_schema.py - Explore CounterPoint database schema.

Quick discovery of key tables for integration planning.

Usage:
    python explore_cp_schema.py              # Show key tables overview
    python explore_cp_schema.py columns IM_PRC_RUL   # Show columns for a table
    python explore_cp_schema.py sample AR_CUST 5    # Sample 5 rows from a table
"""

import sys
from database import run_query

# Key CounterPoint tables for integration
KEY_TABLES = [
    # Customers
    "AR_CUST",
    # Items & Pricing
    "IM_ITEM", "IM_PRC", "IM_PRC_RUL", "IM_PRC_RUL_BRK",
    # Inventory
    "IM_INV", "IM_LOC",
    # Orders/Documents
    "PS_DOC_HDR", "PS_DOC_LIN", "PS_DOC_PMT",
    # Categories
    "IM_CATEG_COD",
    # Views
    "VI_IM_ITEM_WITH_INV",
]


def list_all_tables():
    """List all tables in the database."""
    sql = """
    SELECT TABLE_NAME, TABLE_TYPE
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_TYPE IN ('BASE TABLE', 'VIEW')
    ORDER BY TABLE_TYPE, TABLE_NAME
    """
    rows = run_query(sql)
    
    tables = [r for r in rows if r['TABLE_TYPE'] == 'BASE TABLE']
    views = [r for r in rows if r['TABLE_TYPE'] == 'VIEW']
    
    print(f"\n{'='*60}")
    print(f"DATABASE SCHEMA OVERVIEW")
    print(f"{'='*60}")
    print(f"Tables: {len(tables)}")
    print(f"Views:  {len(views)}")
    print(f"Total:  {len(rows)}")
    
    return tables, views


def show_key_tables():
    """Show status of key integration tables."""
    print(f"\n{'='*60}")
    print("KEY COUNTERPOINT TABLES FOR INTEGRATION")
    print(f"{'='*60}\n")
    
    for table in KEY_TABLES:
        try:
            # Check if table exists and get row count
            sql = f"SELECT COUNT(*) as cnt FROM dbo.[{table}]"
            result = run_query(sql, suppress_errors=True)
            if result:
                count = result[0]['cnt']
                print(f"  ✓ {table:<25} {count:>8,} rows")
            else:
                print(f"  ✗ {table:<25} (not found)")
        except Exception as e:
            print(f"  ✗ {table:<25} (not found)")


def show_columns(table_name):
    """Show column details for a specific table."""
    sql = """
    SELECT 
        COLUMN_NAME,
        DATA_TYPE,
        CHARACTER_MAXIMUM_LENGTH,
        IS_NULLABLE,
        COLUMN_DEFAULT
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = ?
    ORDER BY ORDINAL_POSITION
    """
    rows = run_query(sql, (table_name,))
    
    if not rows:
        print(f"Table '{table_name}' not found.")
        return
    
    print(f"\n{'='*60}")
    print(f"COLUMNS FOR: {table_name}")
    print(f"{'='*60}\n")
    print(f"{'COLUMN':<30} {'TYPE':<15} {'NULL?':<6} {'DEFAULT'}")
    print("-" * 70)
    
    for r in rows:
        dtype = r['DATA_TYPE']
        if r['CHARACTER_MAXIMUM_LENGTH']:
            dtype += f"({r['CHARACTER_MAXIMUM_LENGTH']})"
        nullable = "YES" if r['IS_NULLABLE'] == 'YES' else "NO"
        default = r['COLUMN_DEFAULT'] or ""
        print(f"{r['COLUMN_NAME']:<30} {dtype:<15} {nullable:<6} {default}")
    
    print(f"\nTotal: {len(rows)} columns")


def sample_table(table_name, limit=5):
    """Show sample rows from a table."""
    try:
        sql = f"SELECT TOP {limit} * FROM dbo.[{table_name}]"
        rows = run_query(sql)
        
        if not rows:
            print(f"No data in '{table_name}'")
            return
        
        print(f"\n{'='*60}")
        print(f"SAMPLE DATA FROM: {table_name} (first {limit} rows)")
        print(f"{'='*60}\n")
        
        # Get columns
        cols = list(rows[0].keys())
        
        # Print header
        for col in cols[:10]:  # Limit to first 10 columns for readability
            print(f"{col:<20}", end="")
        if len(cols) > 10:
            print(f" ... +{len(cols)-10} more cols", end="")
        print()
        print("-" * min(200, len(cols) * 20))
        
        # Print rows
        for row in rows:
            for col in cols[:10]:
                val = str(row[col] or "")[:18]
                print(f"{val:<20}", end="")
            print()
            
    except Exception as e:
        print(f"Error: {e}")


def search_tables(keyword):
    """Search for tables/columns containing a keyword."""
    print(f"\n{'='*60}")
    print(f"SEARCHING FOR: '{keyword}'")
    print(f"{'='*60}\n")
    
    # Search table names
    sql = """
    SELECT DISTINCT TABLE_NAME 
    FROM INFORMATION_SCHEMA.TABLES 
    WHERE TABLE_NAME LIKE ?
    ORDER BY TABLE_NAME
    """
    tables = run_query(sql, (f"%{keyword}%",))
    
    if tables:
        print(f"Tables matching '{keyword}':")
        for t in tables[:20]:
            print(f"  - {t['TABLE_NAME']}")
        if len(tables) > 20:
            print(f"  ... and {len(tables)-20} more")
    
    # Search column names
    sql = """
    SELECT DISTINCT TABLE_NAME, COLUMN_NAME
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE COLUMN_NAME LIKE ?
    ORDER BY TABLE_NAME, COLUMN_NAME
    """
    cols = run_query(sql, (f"%{keyword}%",))
    
    if cols:
        print(f"\nColumns matching '{keyword}':")
        for c in cols[:20]:
            print(f"  - {c['TABLE_NAME']}.{c['COLUMN_NAME']}")
        if len(cols) > 20:
            print(f"  ... and {len(cols)-20} more")


def show_pricing_rules_schema():
    """Show the complete pricing rules structure."""
    print(f"\n{'='*60}")
    print("PRICING RULES SCHEMA (IM_PRC_RUL + IM_PRC_RUL_BRK)")
    print(f"{'='*60}\n")
    
    show_columns("IM_PRC_RUL")
    print()
    show_columns("IM_PRC_RUL_BRK")


def show_order_schema():
    """Show order/document structure."""
    print(f"\n{'='*60}")
    print("ORDER/DOCUMENT SCHEMA")
    print(f"{'='*60}\n")
    
    for table in ["PS_DOC_HDR", "PS_DOC_LIN", "PS_DOC_PMT"]:
        show_columns(table)
        print()


def main():
    args = sys.argv[1:]
    
    if not args:
        # Default: show key tables overview
        list_all_tables()
        show_key_tables()
        print(f"\n{'='*60}")
        print("NEXT STEPS")
        print(f"{'='*60}")
        print("  python explore_cp_schema.py columns IM_PRC_RUL    # See pricing rule columns")
        print("  python explore_cp_schema.py columns PS_DOC_HDR    # See order header columns")
        print("  python explore_cp_schema.py sample AR_CUST 3      # Sample customer data")
        print("  python explore_cp_schema.py search ECOMM          # Find e-commerce columns")
        print("  python explore_cp_schema.py pricing               # Full pricing schema")
        print("  python explore_cp_schema.py orders                # Full order schema")
        return
    
    cmd = args[0].lower()
    
    if cmd == "columns" and len(args) > 1:
        show_columns(args[1])
    
    elif cmd == "sample" and len(args) > 1:
        limit = int(args[2]) if len(args) > 2 else 5
        sample_table(args[1], limit)
    
    elif cmd == "search" and len(args) > 1:
        search_tables(args[1])
    
    elif cmd == "pricing":
        show_pricing_rules_schema()
    
    elif cmd == "orders":
        show_order_schema()
    
    elif cmd == "tables":
        tables, views = list_all_tables()
        print("\nAll tables:")
        for t in tables:
            print(f"  {t['TABLE_NAME']}")
    
    elif cmd == "views":
        tables, views = list_all_tables()
        print("\nAll views:")
        for v in views:
            print(f"  {v['TABLE_NAME']}")
    
    else:
        print(f"Unknown command: {cmd}")
        print("Usage:")
        print("  python explore_cp_schema.py              # Overview")
        print("  python explore_cp_schema.py columns <table>")
        print("  python explore_cp_schema.py sample <table> [limit]")
        print("  python explore_cp_schema.py search <keyword>")
        print("  python explore_cp_schema.py pricing")
        print("  python explore_cp_schema.py orders")


if __name__ == "__main__":
    main()

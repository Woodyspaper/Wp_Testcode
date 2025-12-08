"""
csv_tools.py - CSV Import/Export for CounterPoint Integration

Export data from CounterPoint to CSV, edit in Excel, import back.

Usage:
    python csv_tools.py export pricing     # Export pricing rules to CSV
    python csv_tools.py export customers   # Export customers to CSV
    python csv_tools.py import pricing pricing_rules.csv  # Import pricing from CSV
    python csv_tools.py import customers customers.csv    # Import customers from CSV
"""

import csv
import sys
import os
from datetime import datetime
from database import run_query
from config import load_integration_config

# Get database name for filenames
def get_db_name():
    try:
        cfg = load_integration_config()
        return cfg.database.database
    except:
        return "export"


# ─────────────────────────────────────────────────────────────────────────────
# EXPORT FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────

def export_pricing_rules(filename=None):
    """Export current pricing rules to CSV."""
    if not filename:
        filename = f"pricing_rules_{get_db_name()}_{datetime.now().strftime('%Y%m%d')}.csv"
    
    sql = """
    SELECT 
        r.RUL_SEQ_NO,
        r.DESCR,
        r.GRP_TYP,
        r.GRP_COD,
        r.CUST_NO,
        r.ITEM_NO,
        b.PRC_METH,
        b.PRC_BASIS,
        b.AMT_OR_PCT,
        b.MIN_QTY
    FROM dbo.IM_PRC_RUL r
    LEFT JOIN dbo.IM_PRC_RUL_BRK b ON r.GRP_TYP = b.GRP_TYP 
        AND r.GRP_COD = b.GRP_COD AND r.RUL_SEQ_NO = b.RUL_SEQ_NO
    ORDER BY r.RUL_SEQ_NO
    """
    
    rows = run_query(sql)
    if not rows:
        print("No pricing rules found.")
        return
    
    with open(filename, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    
    print(f"✓ Exported {len(rows)} pricing rules to: {filename}")
    return filename


def export_customers(filename=None):
    """Export e-commerce customers to CSV."""
    if not filename:
        filename = f"customers_{get_db_name()}_{datetime.now().strftime('%Y%m%d')}.csv"
    
    sql = """
    SELECT 
        CUST_NO,
        NAM,
        FST_NAM,
        LST_NAM,
        EMAIL_ADRS_1,
        PHONE_1,
        ADRS_1,
        ADRS_2,
        CITY,
        STATE,
        ZIP_COD,
        CNTRY,
        CUST_TYP,
        CATEG_COD,
        TERMS_COD,
        TAX_COD
    FROM dbo.AR_CUST
    WHERE IS_ECOMM_CUST = 'Y'
    ORDER BY CUST_NO
    """
    
    rows = run_query(sql)
    if not rows:
        print("No e-commerce customers found.")
        return
    
    with open(filename, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    
    print(f"✓ Exported {len(rows)} customers to: {filename}")
    return filename


def export_contract_master(filename=None):
    """Export our contract pricing master table to CSV."""
    if not filename:
        filename = f"contract_master_{get_db_name()}_{datetime.now().strftime('%Y%m%d')}.csv"
    
    sql = """
    SELECT 
        CONTRACT_ID,
        CUST_NO,
        CUST_GRP_COD,
        PRC_COD,
        ITEM_NO,
        ITEM_CATEG_COD,
        DESCR,
        PRC_METH,
        PRC_BASIS,
        PRC_AMT,
        MIN_QTY,
        MAX_QTY,
        EFFECTIVE_FROM,
        EFFECTIVE_TO,
        PRIORITY,
        IS_ACTIVE,
        OWNER_SYSTEM
    FROM dbo.USER_CONTRACT_PRICE_MASTER
    WHERE IS_ACTIVE = 1
    ORDER BY PRIORITY, CONTRACT_ID
    """
    
    rows = run_query(sql)
    if not rows:
        print("No contract pricing rules in master table.")
        print("(This is normal if you haven't imported any yet)")
        return
    
    with open(filename, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    
    print(f"✓ Exported {len(rows)} contract rules to: {filename}")
    return filename


# ─────────────────────────────────────────────────────────────────────────────
# IMPORT FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────

def import_pricing_to_staging(filename, batch_id=None):
    """
    Import pricing rules from CSV into USER_CONTRACT_PRICE_STAGING.
    
    Expected CSV columns:
        CUST_NO, ITEM_NO, ITEM_CATEG_COD, DESCR, PRC_METH, PRC_AMT, 
        MIN_QTY, MAX_QTY, EFFECTIVE_FROM, EFFECTIVE_TO, PRIORITY
    """
    if not os.path.exists(filename):
        print(f"✗ File not found: {filename}")
        return None
    
    if not batch_id:
        batch_id = f"IMPORT_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    
    # Read CSV
    with open(filename, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        rows = list(reader)
    
    if not rows:
        print("✗ CSV file is empty")
        return None
    
    print(f"Read {len(rows)} rows from {filename}")
    print(f"Batch ID: {batch_id}")
    
    # Insert into staging table
    insert_sql = """
    INSERT INTO dbo.USER_CONTRACT_PRICE_STAGING (
        BATCH_ID, CUST_NO, CUST_GRP_COD, PRC_COD, ITEM_NO, ITEM_CATEG_COD,
        DESCR, PRC_METH, PRC_BASIS, PRC_AMT, MIN_QTY, MAX_QTY,
        EFFECTIVE_FROM, EFFECTIVE_TO, PRIORITY, SOURCE_FILE
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """
    
    from database import get_connection
    conn = get_connection()
    cursor = conn.cursor()
    
    inserted = 0
    errors = []
    
    for i, row in enumerate(rows, 1):
        try:
            # Parse values with defaults
            cust_no = row.get('CUST_NO', '').strip() or None
            cust_grp = row.get('CUST_GRP_COD', '').strip() or None
            prc_cod = row.get('PRC_COD', '').strip() or None
            item_no = row.get('ITEM_NO', '').strip() or None
            item_categ = row.get('ITEM_CATEG_COD', '').strip() or row.get('CATEG_COD', '').strip() or None
            descr = row.get('DESCR', '').strip() or 'Imported Rule'
            prc_meth = row.get('PRC_METH', 'D').strip().upper()[:1]
            prc_basis = row.get('PRC_BASIS', '1').strip()[:1]
            prc_amt = float(row.get('PRC_AMT', 0) or row.get('AMT_OR_PCT', 0) or 0)
            min_qty = float(row.get('MIN_QTY', 0) or 0)
            max_qty = row.get('MAX_QTY', '').strip()
            max_qty = float(max_qty) if max_qty else None
            eff_from = row.get('EFFECTIVE_FROM', '').strip() or None
            eff_to = row.get('EFFECTIVE_TO', '').strip() or None
            priority = int(row.get('PRIORITY', 100) or 100)
            
            cursor.execute(insert_sql, (
                batch_id, cust_no, cust_grp, prc_cod, item_no, item_categ,
                descr, prc_meth, prc_basis, prc_amt, min_qty, max_qty,
                eff_from, eff_to, priority, filename
            ))
            inserted += 1
            
        except Exception as e:
            errors.append(f"Row {i}: {e}")
    
    conn.commit()
    cursor.close()
    conn.close()
    
    print(f"\n✓ Inserted {inserted} rows into USER_CONTRACT_PRICE_STAGING")
    if errors:
        print(f"✗ {len(errors)} errors:")
        for e in errors[:10]:
            print(f"  {e}")
        if len(errors) > 10:
            print(f"  ... and {len(errors) - 10} more")
    
    print(f"\nNext steps:")
    print(f"  1. Run validation:  EXEC usp_Validate_ContractPricing_Staging '{batch_id}'")
    print(f"  2. Review errors in SQL Server Management Studio")
    print(f"  3. Merge to master: EXEC usp_Merge_ContractPricing_StagingToMaster '{batch_id}'")
    
    return batch_id


def import_customers_to_staging(filename, batch_id=None):
    """
    Import customers from CSV into USER_CUSTOMER_STAGING.
    """
    if not os.path.exists(filename):
        print(f"✗ File not found: {filename}")
        return None
    
    if not batch_id:
        batch_id = f"CUST_IMPORT_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    
    with open(filename, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        rows = list(reader)
    
    if not rows:
        print("✗ CSV file is empty")
        return None
    
    print(f"Read {len(rows)} rows from {filename}")
    print(f"Batch ID: {batch_id}")
    
    insert_sql = """
    INSERT INTO dbo.USER_CUSTOMER_STAGING (
        BATCH_ID, CUST_NO, EMAIL_ADRS_1, NAM, FST_NAM, LST_NAM,
        PHONE_1, ADRS_1, ADRS_2, CITY, STATE, ZIP_COD, CNTRY,
        CUST_TYP, CATEG_COD, TERMS_COD, TAX_COD
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """
    
    from database import get_connection
    conn = get_connection()
    cursor = conn.cursor()
    
    inserted = 0
    for row in rows:
        try:
            cursor.execute(insert_sql, (
                batch_id,
                row.get('CUST_NO', '').strip() or None,
                row.get('EMAIL_ADRS_1', '').strip() or None,
                row.get('NAM', '').strip() or None,
                row.get('FST_NAM', '').strip() or None,
                row.get('LST_NAM', '').strip() or None,
                row.get('PHONE_1', '').strip() or None,
                row.get('ADRS_1', '').strip() or None,
                row.get('ADRS_2', '').strip() or None,
                row.get('CITY', '').strip() or None,
                row.get('STATE', '').strip() or None,
                row.get('ZIP_COD', '').strip() or None,
                row.get('CNTRY', 'US').strip() or 'US',
                row.get('CUST_TYP', '').strip() or None,
                row.get('CATEG_COD', '').strip() or None,
                row.get('TERMS_COD', '').strip() or None,
                row.get('TAX_COD', '').strip() or None,
            ))
            inserted += 1
        except Exception as e:
            print(f"Error on row: {e}")
    
    conn.commit()
    cursor.close()
    conn.close()
    
    print(f"\n✓ Inserted {inserted} rows into USER_CUSTOMER_STAGING")
    print(f"Batch ID: {batch_id}")
    
    return batch_id


# ─────────────────────────────────────────────────────────────────────────────
# VALIDATION & APPLY (calls SQL stored procedures)
# ─────────────────────────────────────────────────────────────────────────────

def validate_staging(batch_id):
    """Call the validation stored procedure."""
    from database import get_connection
    
    sql = """
    DECLARE @ValidCount INT, @InvalidCount INT;
    EXEC dbo.usp_Validate_ContractPricing_Staging 
        @BatchID = ?, 
        @ValidCount = @ValidCount OUTPUT, 
        @InvalidCount = @InvalidCount OUTPUT;
    SELECT @ValidCount AS ValidCount, @InvalidCount AS InvalidCount;
    """
    
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(sql, (batch_id,))
    
    # Get the counts
    row = cursor.fetchone()
    valid_count = row[0] if row else 0
    invalid_count = row[1] if row else 0
    
    print(f"\nValidation Results for batch: {batch_id}")
    print(f"  ✓ Valid:   {valid_count}")
    print(f"  ✗ Invalid: {invalid_count}")
    
    # If there are errors, show them
    if invalid_count > 0:
        cursor.nextset()  # Move to error results
        print("\nValidation Errors:")
        for err_row in cursor.fetchall():
            print(f"  - {err_row}")
    
    cursor.close()
    conn.close()
    
    return valid_count, invalid_count


def apply_staging_to_master(batch_id):
    """Merge validated staging records to master table."""
    from database import get_connection
    
    sql = """
    DECLARE @InsertCount INT, @UpdateCount INT;
    EXEC dbo.usp_Merge_ContractPricing_StagingToMaster 
        @BatchID = ?, 
        @InsertCount = @InsertCount OUTPUT, 
        @UpdateCount = @UpdateCount OUTPUT;
    SELECT @InsertCount AS Inserted, @UpdateCount AS Updated;
    """
    
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(sql, (batch_id,))
    
    row = cursor.fetchone()
    insert_count = row[0] if row else 0
    update_count = row[1] if row else 0
    
    print(f"\nMerge Results for batch: {batch_id}")
    print(f"  ✓ Inserted: {insert_count}")
    print(f"  ✓ Updated:  {update_count}")
    
    cursor.close()
    conn.close()
    
    return insert_count, update_count


# ─────────────────────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────────────────────

def print_help():
    print("""
csv_tools.py - CSV Import/Export for CounterPoint

EXPORT COMMANDS:
  python csv_tools.py export pricing      Export pricing rules to CSV
  python csv_tools.py export customers    Export e-commerce customers to CSV
  python csv_tools.py export master       Export contract master table to CSV

IMPORT COMMANDS:
  python csv_tools.py import pricing <file.csv>    Import pricing rules
  python csv_tools.py import customers <file.csv>  Import customers

VALIDATE & APPLY:
  python csv_tools.py validate <batch_id>   Validate a staging batch
  python csv_tools.py apply <batch_id>      Apply staging to master table

WORKFLOW:
  1. Export:   python csv_tools.py export pricing
  2. Edit:     Open CSV in Excel, make changes
  3. Import:   python csv_tools.py import pricing my_changes.csv
  4. Validate: python csv_tools.py validate IMPORT_20251205_120000
  5. Apply:    python csv_tools.py apply IMPORT_20251205_120000
""")


def main():
    args = sys.argv[1:]
    
    if not args or args[0] in ['help', '-h', '--help']:
        print_help()
        return
    
    cmd = args[0].lower()
    
    if cmd == 'export':
        if len(args) < 2:
            print("Usage: python csv_tools.py export [pricing|customers|master]")
            return
        what = args[1].lower()
        filename = args[2] if len(args) > 2 else None
        
        if what == 'pricing':
            export_pricing_rules(filename)
        elif what == 'customers':
            export_customers(filename)
        elif what == 'master':
            export_contract_master(filename)
        else:
            print(f"Unknown export type: {what}")
    
    elif cmd == 'import':
        if len(args) < 3:
            print("Usage: python csv_tools.py import [pricing|customers] <file.csv>")
            return
        what = args[1].lower()
        filename = args[2]
        
        if what == 'pricing':
            import_pricing_to_staging(filename)
        elif what == 'customers':
            import_customers_to_staging(filename)
        else:
            print(f"Unknown import type: {what}")
    
    elif cmd == 'validate':
        if len(args) < 2:
            print("Usage: python csv_tools.py validate <batch_id>")
            return
        validate_staging(args[1])
    
    elif cmd == 'apply':
        if len(args) < 2:
            print("Usage: python csv_tools.py apply <batch_id>")
            return
        apply_staging_to_master(args[1])
    
    else:
        print(f"Unknown command: {cmd}")
        print_help()


if __name__ == "__main__":
    main()



"""Deploy sp_CreateOrderLines directly"""
from database import get_connection
import re

# Read the procedure file
with open('01_Production/sp_CreateOrderLines.sql', 'r', encoding='utf-8') as f:
    sql = f.read()

# Extract just the CREATE PROCEDURE part (remove USE and GO statements)
# Find the CREATE PROCEDURE statement
proc_start = sql.upper().find('CREATE PROCEDURE')
if proc_start == -1:
    print("[ERROR] Could not find CREATE PROCEDURE in file")
    exit(1)

# Extract from CREATE PROCEDURE to the end (before final GO/PRINT)
proc_sql = sql[proc_start:]
# Remove trailing GO and PRINT statements
proc_sql = re.sub(r'\nGO\s*\n.*$', '', proc_sql, flags=re.DOTALL)
proc_sql = re.sub(r'\nPRINT.*$', '', proc_sql, flags=re.DOTALL)

# First drop if exists
drop_sql = "IF OBJECT_ID('dbo.sp_CreateOrderLines', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_CreateOrderLines;"

conn = get_connection()
cursor = conn.cursor()

try:
    # Drop existing
    cursor.execute(drop_sql)
    print("[OK] Dropped existing procedure (if any)")
    
    # Create new
    cursor.execute(proc_sql)
    conn.commit()
    print("[OK] Procedure created successfully")
    
    # Verify
    cursor.execute("SELECT name FROM sys.procedures WHERE name = 'sp_CreateOrderLines'")
    result = cursor.fetchone()
    if result:
        print(f"[OK] Verified: Procedure '{result[0]}' exists")
    else:
        print("[WARNING] Procedure not found after creation")
        
except Exception as e:
    conn.rollback()
    print(f"[ERROR] Error: {e}")
    import traceback
    traceback.print_exc()
finally:
    cursor.close()
    conn.close()

"""Deploy the fixed sp_CreateOrderLines procedure"""
from database import get_connection
import re

# Read the fixed procedure
with open('01_Production/sp_CreateOrderLines.sql', 'r', encoding='utf-8') as f:
    sql = f.read()

# Split by GO statements
batches = re.split(r'\nGO\s*\n', sql, flags=re.IGNORECASE)

conn = get_connection()
cursor = conn.cursor()

try:
    for batch in batches:
        batch = batch.strip()
        if batch and not batch.startswith('--'):
            # Skip USE statements and PRINT statements, but keep CREATE PROCEDURE
            if 'USE ' in batch.upper():
                continue
            if batch.startswith('PRINT'):
                continue
            # Execute the batch
            try:
                cursor.execute(batch)
            except Exception as e:
                # If it's a "must be first statement" error, try without GO handling
                if 'first statement' in str(e).lower():
                    # Extract just the CREATE PROCEDURE part
                    if 'CREATE PROCEDURE' in batch.upper():
                        # Remove IF EXISTS DROP if present
                        proc_start = batch.upper().find('CREATE PROCEDURE')
                        if proc_start > 0:
                            batch = batch[proc_start:]
                        cursor.execute(batch)
                else:
                    raise
    
    conn.commit()
    print("[OK] Procedure fixed and deployed successfully")
except Exception as e:
    conn.rollback()
    print(f"[ERROR] Error: {e}")
finally:
    cursor.close()
    conn.close()

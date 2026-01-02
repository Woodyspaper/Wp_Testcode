"""Set SQL Server max memory to 56GB and verify."""
import os
import sys

# Add project root to Python path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

from database import get_connection

conn = get_connection()
conn.autocommit = True  # Required for RECONFIGURE
cursor = conn.cursor()

print("Setting SQL Server max memory to 57344 MB (56 GB)...")

# Enable advanced options
cursor.execute("EXEC sys.sp_configure 'show advanced options', 1")
cursor.execute("RECONFIGURE")

# Set max memory
cursor.execute("EXEC sys.sp_configure 'max server memory (MB)', 57344")
cursor.execute("RECONFIGURE")

# Verify - cast to avoid data type issues
cursor.execute("SELECT CAST(value_in_use AS BIGINT) FROM sys.configurations WHERE name = 'max server memory (MB)'")
row = cursor.fetchone()
mem_mb = row[0]
print(f"\n✓ max server memory (MB): {mem_mb} MB ({mem_mb/1024:.0f} GB)")

# Show current usage
cursor.execute("SELECT physical_memory_in_use_kb/1024 FROM sys.dm_os_process_memory")
row = cursor.fetchone()
current_mb = row[0]
print(f"  Current SQL memory usage: {current_mb} MB ({current_mb/1024:.1f} GB)")

conn.close()
print("\n✓ Done! SQL Server will now stay within the 56 GB limit.")


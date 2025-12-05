"""
test_connection.py - Test SQL Server connection to WOODYS_CP.

Tests both Windows auth and SQL auth. Run this to verify your .env is correct.

Usage:
    python test_connection.py
"""

import pyodbc
from config import load_integration_config

def test_connection():
    """Test connection using settings from .env via config.py."""
    try:
        cfg = load_integration_config()
        db = cfg.database
        
        print(f"\n{'='*60}")
        print("Testing SQL Server Connection")
        print(f"{'='*60}")
        print(f"Server:   {db.server}")
        print(f"Database: {db.database}")
        print(f"Driver:   {db.driver}")
        print(f"Auth:     {'Windows (Trusted)' if db.trusted_connection else 'SQL Auth'}")
        print(f"{'='*60}\n")
        
        # Build connection string
        parts = [
            f"DRIVER={{{db.driver}}}",
            f"SERVER={db.server}",
            f"DATABASE={db.database}",
            "TrustServerCertificate=yes",
            f"Connection Timeout={db.timeout}",
        ]
        if db.trusted_connection:
            parts.append("Trusted_Connection=yes")
        else:
            parts.append(f"UID={db.username}")
            parts.append(f"PWD={db.password}")
        
        conn_str = ";".join(parts)
        
        print("Connecting...")
        conn = pyodbc.connect(conn_str, timeout=db.timeout)
        cursor = conn.cursor()
        
        # Test 1: Server version
        cursor.execute("SELECT @@VERSION")
        version = cursor.fetchone()[0]
        print(f"✓ Connected to: {version[:60]}...")
        
        # Test 2: Database exists
        cursor.execute(f"SELECT DB_NAME()")
        db_name = cursor.fetchone()[0]
        print(f"✓ Database: {db_name}")
        
        # Test 3: Count some tables
        cursor.execute("SELECT COUNT(*) FROM sys.tables")
        table_count = cursor.fetchone()[0]
        print(f"✓ Tables found: {table_count}")
        
        conn.close()
        
        print(f"\n{'='*60}")
        print("✓ CONNECTION SUCCESSFUL")
        print(f"{'='*60}\n")
        return True
        
    except pyodbc.Error as e:
        print(f"\n✗ Connection failed: {e}")
        print("\nTroubleshooting:")
        print("  1. Check .env file exists and has correct values")
        print("  2. Verify SQL Server is running")
        print("  3. Check firewall allows SQL Server port (1433)")
        return False
    except Exception as e:
        print(f"\n✗ Error: {e}")
        return False


if __name__ == "__main__":
    test_connection()


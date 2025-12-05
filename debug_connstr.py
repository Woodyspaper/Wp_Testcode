"""Debug connection string."""
from config import load_integration_config
from database import _build_connection_string

cfg = load_integration_config().database
conn_str = _build_connection_string(cfg)

print("\n=== DATABASE CONFIG ===")
print(f"Server: {cfg.server}")
print(f"Database: {cfg.database}")
print(f"Driver: {cfg.driver}")
print(f"Trusted: {cfg.trusted_connection}")
print(f"Username: {cfg.username}")
print(f"Timeout: {cfg.timeout}")

print("\n=== CONNECTION STRING ===")
print(conn_str)

print("\n=== PARTS ===")
parts = conn_str.split(";")
for i, part in enumerate(parts):
    print(f"{i}: {part}")

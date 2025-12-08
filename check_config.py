"""Quick check of current configuration."""
from config import load_integration_config

cfg = load_integration_config()
print("="*50)
print("CURRENT CONFIGURATION")
print("="*50)
print(f"SQL Server:  {cfg.database.server}")
print(f"Database:    {cfg.database.database}")
print(f"WooCommerce: {cfg.woo.base_url}")
print("="*50)

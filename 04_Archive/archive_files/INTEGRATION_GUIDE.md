# CounterPoint ↔ WooCommerce Integration Guide

## Overview

This integration syncs data between **CounterPoint** (SQL Server) and **WooCommerce** (WordPress).

```
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│   COUNTERPOINT  │      │     PYTHON      │      │   WOOCOMMERCE   │
│   (SQL Server)  │◄────►│    SCRIPTS      │◄────►│   (REST API)    │
└─────────────────┘      └─────────────────┘      └─────────────────┘
        │                        │                        
        ▼                        ▼                        
┌─────────────────┐      ┌─────────────────┐
│     EXCEL       │◄────►│   CSV FILES     │
│   (Manual Edit) │      │                 │
└─────────────────┘      └─────────────────┘
```

## Quick Start

```powershell
# 1. Test connections
python test_connection.py      # Test SQL Server
python -c "from woo_client import WooClient; WooClient().test_connection()"

# 2. Sync products (CP → Woo)
python sync.py --limit 10      # Dry-run first
python sync.py --live          # Live sync

# 3. Sync customers (CP → Woo)
python woo_customers.py push   # Dry-run
python woo_customers.py push --apply

# 4. Pull orders (Woo → CP)
python woo_orders.py pull --days 7
python woo_orders.py pull --days 7 --apply
```

---

## Data Flows

### 1. Products & Inventory (CP → Woo)

| Script | Purpose |
|--------|---------|
| `sync.py` | Main sync orchestrator |
| `feed_builder.py` | Transforms CP items to Woo format |
| `woo_client.py` | WooCommerce API calls |

```powershell
# Dry-run (preview only)
python sync.py --limit 100

# Live sync
python sync.py --live

# Inventory only
python sync.py --inventory-only --live
```

### 2. Customers (Bidirectional)

| Script | Purpose |
|--------|---------|
| `woo_customers.py` | Customer sync both directions |
| `cp_tools.py` | Read CP customers |

```powershell
# Push CP customers to Woo
python woo_customers.py push --apply

# Pull new Woo customers to CP staging
python woo_customers.py pull --apply

# List customer mappings
python woo_customers.py list
```

### 3. Orders (Woo → CP)

| Script | Purpose |
|--------|---------|
| `woo_orders.py` | Pull orders to staging |

```powershell
# List recent Woo orders
python woo_orders.py list --days 7

# Pull to staging
python woo_orders.py pull --days 7 --apply

# Check order status
python woo_orders.py status 12345
```

### 4. Customer Discounts (Two Approaches)

#### Simple Approach: AR_CUST.DISC_PCT
For "Customer X gets Y% off everything":

```powershell
# View current discounts
python cp_discounts.py list

# Set discount
python cp_discounts.py set SMITH 15 --apply

# Bulk update from CSV
python cp_discounts.py bulk discounts.csv --apply
```

#### Advanced Approach: Pricing Rules
For item-specific or quantity-based pricing, use `staging_tables_v2.sql` procedures.

### 5. Excel Workflow

```powershell
# Export from CP to CSV
python csv_tools.py export pricing
python csv_tools.py export customers

# Edit in Excel...

# Import back to staging
python csv_tools.py import pricing edited_rules.csv
python csv_tools.py validate IMPORT_20251208_120000
python csv_tools.py apply IMPORT_20251208_120000
```

---

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `sync.py` | Main product/inventory sync |
| `woo_client.py` | WooCommerce API wrapper |
| `woo_customers.py` | Customer sync (both directions) |
| `woo_orders.py` | Order pull (Woo → CP staging) |
| `cp_tools.py` | CounterPoint utilities |
| `cp_discounts.py` | Simple customer discounts |
| `csv_tools.py` | CSV import/export |
| `feed_builder.py` | Product data transformer |
| `database.py` | SQL Server connection |
| `config.py` | Configuration loader |
| `test_connection.py` | Connection tester |
| `explore_cp_schema.py` | Schema explorer |
| `show_schema.py` | Quick schema dump |

---

## SQL Files

| File | Purpose |
|------|---------|
| `staging_tables_v2.sql` | **USE THIS** - Corrected staging tables and procedures |
| `staging_tables.sql` | Original (has schema issues) |

---

## Configuration (.env file)

```env
# CounterPoint SQL Server
CP_SQL_SERVER=ADWPC-MAIN
CP_SQL_DATABASE=CPPractice
CP_SQL_DRIVER=ODBC Driver 17 for SQL Server
CP_SQL_TRUSTED_CONN=true

# WooCommerce
WOO_BASE_URL=https://your-store.com
WOO_CONSUMER_KEY=ck_xxxxxxxx
WOO_CONSUMER_SECRET=cs_xxxxxxxx

# Optional
DEFAULT_LOC_ID=01
IMAGE_BASE_URL=https://your-store.com/images
```

---

## Staging Tables

All imports go through staging tables for safety:

| Table | Purpose |
|-------|---------|
| `USER_SYNC_LOG` | Audit trail for all operations |
| `USER_CUSTOMER_MAP` | CP ↔ Woo customer mapping |
| `USER_CUSTOMER_STAGING` | Customer imports |
| `USER_ORDER_STAGING` | Order imports from Woo |
| `USER_CONTRACT_PRICE_MASTER` | Contract pricing rules |
| `USER_CONTRACT_PRICE_STAGING` | Pricing rule imports |

---

## Customer Pricing in WooCommerce

⚠️ **WooCommerce doesn't have native per-customer pricing!**

Options:
1. **Simple discounts**: Use `AR_CUST.DISC_PCT` + display in Woo customer meta
2. **Role-based**: Assign customers to wholesale roles
3. **Plugin**: Use "WooCommerce Dynamic Pricing" or "B2B Market"
4. **Custom**: Build custom pricing logic

The `cp_cust_no` and `cp_disc_pct` are stored in WooCommerce customer meta_data when pushed.

---

## Typical Daily Workflow

```powershell
# Morning: Sync products and inventory
python sync.py --live

# Afternoon: Pull new web orders
python woo_orders.py pull --days 1 --apply

# Review staged orders
python woo_orders.py staged

# Weekly: Pull new web customers
python woo_customers.py pull --apply
```

---

## Troubleshooting

### Test Connections
```powershell
python test_connection.py                    # SQL Server
python -m woo_client                         # WooCommerce
```

### Explore Schema
```powershell
python show_schema.py                        # Key tables
python explore_cp_schema.py columns AR_CUST  # Specific table
python explore_cp_schema.py search ECOMM     # Search columns
```

### Check Logs
```sql
SELECT TOP 20 * FROM USER_SYNC_LOG ORDER BY CREATED_DT DESC;
```

---

## Safety Features

1. **Dry-run by default** - All write operations preview first
2. **Staging tables** - Data goes to USER_* tables before production
3. **Ownership markers** - Automation-created records tagged with `[AUTO]`
4. **Transaction rollback** - Errors roll back partial changes
5. **Audit logging** - All syncs logged to USER_SYNC_LOG

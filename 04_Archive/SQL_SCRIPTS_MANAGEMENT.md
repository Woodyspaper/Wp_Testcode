# SQL Scripts Management Guide

## ✅ **YES - You Should Save SQL Scripts!**

Saving SQL scripts is important for:
- **Reproducibility**: Recreate views/procedures on other servers
- **Version Control**: Track changes over time
- **Documentation**: Know what's deployed in production
- **Troubleshooting**: Reference when issues arise
- **Team Collaboration**: Others can see what's been done

---

## 🧪 **How to Test the Product Export View**

### Option 1: Use the Test File I Created
Run `test_product_export_view.sql` - it includes 5 test queries:
1. Verify view exists
2. Sample 10 products
3. Count totals and stats
4. Check for NULL SKUs
5. Show active products with stock

### Option 2: Quick Manual Test
```sql
USE WOODYS_CP;
GO

-- Simple test - see first 10 products
SELECT TOP 10 * 
FROM dbo.VI_EXPORT_PRODUCTS
ORDER BY SKU;
```

### Option 3: Test from Python
If you have a Python script that connects to the database, you can query the view:
```python
from database import run_query

results = run_query("SELECT TOP 10 * FROM dbo.VI_EXPORT_PRODUCTS")
print(results)
```

---

## 📁 **Which SQL Files to Save**

### ✅ **MUST SAVE - Production Scripts** (Keep Forever)

These create/modify production database objects:

1. **`product_export_view.sql`** ✅ **SAVE THIS**
   - Creates the `VI_EXPORT_PRODUCTS` view
   - Needed to recreate on other servers
   - **Status**: ✅ Already saved

2. **`staging_tables.sql`**
   - Creates staging tables and procedures
   - Critical for customer sync pipeline

3. **`product_mapping_tables.sql`**
   - Product mapping tables if you have them

4. **`create_scheduled_sync_job.sql`**
   - SQL Agent jobs for automation

5. **`backup_database.sql`**
   - Backup procedures

### ✅ **SAVE - Reference/Utility Scripts**

6. **`QUICK_REFERENCE_QUERIES.sql`** ✅ Already exists
   - Common queries for daily use
   - Keep updated as you add new queries

7. **`test_product_export_view.sql`** ✅ **Just created**
   - Test queries for the product view
   - Useful for validation

8. **`preflight_validation.sql`**
   - Validation procedures

9. **`MASTER_TEST_SCRIPT.sql`**
   - Comprehensive test suite

### ⚠️ **ARCHIVE - Debug/One-Time Scripts**

These are useful for reference but not needed in production:

- Files in `archive_files/` folder ✅ Already archived
- Debug scripts (e.g., `diagnose_*.sql`)
- One-time fixes that are already applied

### ❌ **DON'T SAVE - Temporary Test Queries**

- Ad-hoc queries run once in SSMS
- Quick tests that don't create objects
- Queries you'll never need again

---

## 📋 **Best Practices**

### 1. **File Naming Convention**
- ✅ `create_*.sql` - Creates new objects
- ✅ `alter_*.sql` - Modifies existing objects
- ✅ `test_*.sql` - Test queries
- ✅ `drop_*.sql` - Cleanup scripts

### 2. **File Headers**
Always include:
```sql
-- ============================================
-- Script Name: product_export_view.sql
-- Purpose: Creates VI_EXPORT_PRODUCTS view for WooCommerce sync
-- Created: 2025-12-23
-- Modified: 2025-12-23 (Fixed text/ntext casting issue)
-- ============================================
```

### 3. **Version Control**
- Commit SQL scripts to Git
- Use meaningful commit messages
- Tag releases (e.g., `v1.0`, `v2.0`)

### 4. **Documentation**
- Add comments explaining complex logic
- Document any assumptions or dependencies
- Note any CounterPoint-specific quirks

---

## 🔍 **Current Status of Your SQL Files**

### ✅ **Production-Ready Scripts** (Keep These)
- `product_export_view.sql` - ✅ Fixed and tested
- `staging_tables.sql` - Core pipeline
- `QUICK_REFERENCE_QUERIES.sql` - Daily reference
- `test_product_export_view.sql` - Testing tool

### 📦 **Already Archived** (Good!)
- `archive_files/` folder contains old/debug scripts
- Keep for reference but not active use

---

## 🚀 **Next Steps**

1. **Test the view**: Run `test_product_export_view.sql`
2. **Verify results**: Check that products are showing correctly
3. **Integrate**: Use the view in your Python sync scripts
4. **Document**: Add notes about any schema assumptions

---

## 💡 **Quick Test Right Now**

Run this in SQL Server Management Studio:
```sql
USE WOODYS_CP;
GO

-- Quick test
SELECT TOP 5 
    SKU,
    NAME,
    ACTIVE,
    STOCK_QTY
FROM dbo.VI_EXPORT_PRODUCTS
ORDER BY SKU;
```

If you see results, the view is working! 🎉


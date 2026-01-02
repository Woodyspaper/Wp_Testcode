# Setup Order Sync - Task Scheduler (Similar to Customer Sync)

**Date:** December 30, 2025  
**Purpose:** Set up order sync using Task Scheduler (same approach as customer sync)

---

## ✅ **EXISTING SETUP (Customer Sync)**

You already have:
- ✅ **Task Scheduler job** - Runs daily at 11:49 PM
- ✅ **PowerShell script** - `Run-WooCustomerSync.ps1`
- ✅ **SQL driver script** - `01_Production/run_woo_customer_batch.sql`
- ✅ **Working and tested** - Verified December 23, 2025

---

## 📋 **SETUP ORDER SYNC (Similar Approach)**

### **Option 1: Use Task Scheduler (Recommended - Same as Customer Sync)**

**Create a similar PowerShell script for orders:**

1. **Create:** `Run-WooOrderSync.ps1` (similar to `Run-WooCustomerSync.ps1`)
2. **Create:** `01_Production/run_woo_order_batch.sql` (similar to `run_woo_customer_batch.sql`)
3. **Create:** Task Scheduler job (similar to customer sync job)
4. **Schedule:** Every 5 minutes (or your preferred frequency)

---

### **Option 2: Use SQL Server Agent (Alternative)**

**If you prefer SQL Server Agent:**
- Use the `create_sync_jobs_complete.sql` script we just created
- This creates SQL Server Agent jobs instead of Task Scheduler jobs

---

## 🔄 **COMPARISON**

| Aspect | Task Scheduler (Current) | SQL Server Agent (New) |
|--------|-------------------------|------------------------|
| **Customer Sync** | ✅ Already working | ⚠️ Would duplicate |
| **Order Sync** | ⚠️ Need to create | ✅ Script ready |
| **PowerShell Wrapper** | ✅ Has BatchID handling | ❌ Direct Python call |
| **SQL Driver Script** | ✅ Uses driver script | ⚠️ Direct SQL steps |
| **Management** | Windows Task Scheduler | SQL Server Management Studio |
| **Logging** | ✅ PowerShell logs | ✅ SQL Agent history |

---

## 💡 **RECOMMENDATION**

**Since customer sync already uses Task Scheduler:**

1. **Keep customer sync as-is** (Task Scheduler - working)
2. **Add order sync using Task Scheduler** (consistent approach)
3. **Skip SQL Server Agent** (unless you prefer it)

**Benefits:**
- ✅ Consistent approach (both use Task Scheduler)
- ✅ Same management interface
- ✅ Same logging pattern
- ✅ Already proven to work

---

## 📝 **NEXT STEPS**

**If using Task Scheduler (recommended):**

1. **Create order sync PowerShell script** (similar to `Run-WooCustomerSync.ps1`)
2. **Create order batch SQL script** (similar to `run_woo_customer_batch.sql`)
3. **Create Task Scheduler job** for order sync
4. **Schedule:** Every 5 minutes

**If using SQL Server Agent:**

1. **Run:** `01_Production/create_sync_jobs_complete.sql`
2. **Verify:** Jobs created in SQL Server Agent
3. **Test:** Run jobs manually

---

**Which approach would you prefer?**
- Task Scheduler (consistent with customer sync)
- SQL Server Agent (different approach)

---

**Last Updated:** December 30, 2025

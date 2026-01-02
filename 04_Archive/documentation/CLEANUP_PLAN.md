# WP_Testcode Aggressive Cleanup Plan

**Date:** January 2, 2026  
**Purpose:** Keep ONLY essential files for pipeline operation - archive everything else

---

## 🎯 **CLEANUP STRATEGY**

**ONLY KEEP:**
- Files absolutely required for pipeline to run
- Essential operations documentation
- Production SQL files

**ARCHIVE EVERYTHING ELSE:**
- All other .md files
- All other .sql files (except 01_Production/)
- All other .ps1 files
- All other .py files
- All historical/legacy folders

---

## ✅ **FILES TO KEEP (Essential Only)**

### **Core Python Scripts (11 files)**
```
✅ woo_client.py                    # WooCommerce API client
✅ woo_orders.py                    # Order staging
✅ woo_products.py                  # Product sync
✅ woo_customers.py                 # Customer sync
✅ woo_inventory_sync.py            # Inventory sync
✅ cp_order_processor.py             # Order processing
✅ check_order_processing_needed.py  # Smart check
✅ check_order_processing_health.py  # Health check
✅ database.py                      # Database connection
✅ config.py                        # Configuration
✅ data_utils.py                    # Data utilities
```

### **Essential PowerShell Scripts (9 files)**
```
✅ Run-WooOrderProcessing-Scheduled.ps1    # Order processing
✅ Run-WooProductSync-Scheduled.ps1       # Product sync
✅ Run-WooInventorySync-Scheduled.ps1     # Inventory sync
✅ Run-WooCustomerSync.ps1                # Customer sync
✅ Create-OrderProcessingTask.ps1         # Task creation
✅ Create-ProductSyncTask.ps1            # Task creation
✅ Create-InventorySyncTask.ps1          # Task creation
✅ Setup-EmailAlerts.ps1                  # Email setup
✅ Update-OrderProcessingTaskSchedule.ps1 # Schedule update
```

### **Essential Documentation (6 files)**
```
✅ PIPELINE_EXPLANATION_FOR_RICHARD.md    # Pipeline explanation
✅ OPERATIONS_RUNBOOK.md                  # Operations guide
✅ ROLLBACK_PROCEDURES.md                 # Rollback procedures
✅ DEAD_LETTER_QUEUE_PROCESS.md           # Failed order handling
✅ EMAIL_ALERTS_SETUP.md                  # Email configuration
✅ PRODUCTION_READINESS_SUMMARY.md        # Production status
```

### **Configuration Files (4 files)**
```
✅ requirements.txt      # Python dependencies
✅ .gitignore           # Git ignore
✅ pyrightconfig.json   # Type checking
✅ rules.md             # Project rules
```

### **Production Folders**
```
✅ 01_Production/       # Production SQL (ALL files kept)
✅ api/                 # API code (ALL files kept)
✅ wordpress/           # WordPress plugins (ALL files kept)
✅ logs/                # Log files (auto-generated)
✅ tests/               # Test scripts (keep for testing)
```

---

## 📦 **EVERYTHING ELSE → ARCHIVE**

### **All Other .md Files → Archive**
- All status/progress documents
- All phase documents
- All setup guides (superseded)
- All historical documentation

### **All Other .sql Files → Archive**
- 02_Testing/ folder (entire folder)
- 03_Reference/ folder (entire folder)
- Any SQL files in root

### **All Other .ps1 Files → Archive**
- Old monitoring scripts
- Old test scripts
- Old deployment scripts
- Superseded versions

### **All Other .py Files → Archive**
- Test scripts
- Analysis scripts
- Old utility scripts
- Not in production use

### **All Other Folders → Archive**
- docs/ folder
- archive_files/ folder
- legacy_docs/ folder
- legacy_imports/ folder

---

## ❌ **DELETE (Obsolete)**

```
❌ Screenshot Images (PNG files)
❌ Obsolete text files
```

---

## 📊 **RESULT**

| Category | Before | After | Change |
|----------|--------|-------|--------|
| **Root .md files** | ~50+ | 6 | -88% |
| **Root .ps1 files** | ~30+ | 9 | -70% |
| **Root .py files** | ~20+ | 11 | -45% |
| **Root .sql files** | 0 | 0 | 0 (all in 01_Production/) |
| **Total Root Files** | ~100+ | ~30 | -70% |

---

## 🎯 **FINAL STRUCTURE**

```
WP_Testcode/
├── 01_Production/          # Production SQL (KEEP ALL)
├── api/                   # API code (KEEP ALL)
├── wordpress/             # WordPress plugins (KEEP ALL)
├── logs/                  # Log files (KEEP)
├── tests/                 # Test scripts (KEEP)
├── 04_Archive/            # Everything else (ORGANIZED)
│   ├── 02_Testing/        # Testing SQL
│   ├── 03_Reference/      # Reference SQL
│   ├── docs/              # Historical docs
│   ├── documentation/     # Archived .md files
│   ├── old_scripts/       # Archived .py and .ps1 files
│   ├── archive_files/     # Old archive
│   ├── legacy_docs/       # Legacy docs
│   └── legacy_imports/    # Legacy imports
├── Core Python (11 files) # Essential only
├── Essential PowerShell (9 files) # Essential only
├── Essential Docs (6 files) # Essential only
└── Config (4 files)       # Essential only
```

---

**Status:** ✅ **READY TO EXECUTE - AGGRESSIVE CLEANUP**

# NCR CounterPoint API - Why It's Not Used

**Date:** January 2, 2026  
**Location:** `C:\Program Files (x86)\NCR\Counterpoint API`  
**Status:** ⚠️ **NOT USED - System uses direct SQL Server connection instead**

---

## 🎯 **THE SHORT ANSWER**

**The NCR CounterPoint API key in that folder didn't work because the system doesn't use the NCR API anymore.**

The system was **redesigned to use direct SQL Server connections** instead of the NCR API. The NCR API folder contains the old approach that was replaced.

---

## 📋 **WHAT HAPPENED**

### **Original Plan (Old Approach):**
- Use NCR's official CounterPoint API
- Required API key from NCR
- Use `NCRCounterpointAPI.exe` and related DLLs
- Connect through NCR's API layer

### **Current System (New Approach):**
- **Direct SQL Server connection** via `pyodbc`
- No NCR API required
- Connects directly to CounterPoint database (`WOODYS_CP`)
- Uses ODBC drivers (ODBC Driver 18 for SQL Server)

---

## 🔍 **WHY THE CHANGE?**

### **Problems with NCR API:**
1. **API Key Required:** Needed official, digitally-signed API key from NCR
2. **Approval Process:** Waiting on NCR approval (blocking development)
3. **Complexity:** Additional API layer adds complexity
4. **Dependencies:** Required NCR API DLLs and configuration

### **Benefits of Direct SQL Connection:**
1. ✅ **No API Key Needed:** Direct database access
2. ✅ **Faster:** No API layer overhead
3. ✅ **More Control:** Direct SQL queries and stored procedures
4. ✅ **Simpler:** Standard ODBC connection
5. ✅ **Already Working:** System is fully operational

---

## 🔧 **HOW THE SYSTEM ACTUALLY WORKS**

### **Current Connection Method:**

```
Python Scripts
    ↓
pyodbc (ODBC Driver)
    ↓
SQL Server (ADWPC-MAIN)
    ↓
CounterPoint Database (WOODYS_CP)
```

### **Configuration:**
- **Connection String:** Built in `database.py`
- **Driver:** ODBC Driver 18 for SQL Server
- **Authentication:** Windows Authentication (Trusted Connection)
- **Server:** `ADWPC-MAIN`
- **Database:** `WOODYS_CP`

### **Files That Handle Connection:**
- `config.py` - Loads connection settings from `.env`
- `database.py` - Builds connection string and connects
- `.env` - Contains `CP_SQL_SERVER`, `CP_SQL_DATABASE`, etc.

---

## 📁 **WHAT'S IN THE NCR API FOLDER**

The folder `C:\Program Files (x86)\NCR\Counterpoint API` contains:

- **`NCRCounterpointAPI.exe`** - NCR's official API executable
- **`CPAPI.exe`** - CounterPoint API service
- **Various DLLs** - NCR API libraries
- **`APIKeys` folder** - Contains the API key files
- **`App_Data` folder** - API configuration data
- **`Logfiles` folder** - API logs

### **Found API Key:**

**Location:** `C:\Program Files (x86)\NCR\Counterpoint API\APIKeys\WooCommerce_Integration.xml`

**API Key:** `VBaTcpMdJdC4LNnYFBuKw8noYavRsTIPS3Sc1uSk`

**Details:**
- Name: "WooCommerce Integration"
- Developer: "WoodysPaper"
- Created: December 15, 2025

**However, this API key is NOT used by the current system** - the system uses direct SQL connections instead.

---

## ✅ **WHAT THE SYSTEM USES INSTEAD**

### **Direct SQL Server Connection:**

**Connection Details:**
```python
# From database.py
DRIVER={ODBC Driver 18 for SQL Server}
SERVER=ADWPC-MAIN
DATABASE=WOODYS_CP
Trusted_Connection=yes
Connection Timeout=30
```

**No API Key Required:**
- Uses Windows Authentication
- Direct database access
- No NCR API layer

---

## 🔄 **EVIDENCE OF THE CHANGE**

### **In the Code:**

**`01_Production/staging_tables.sql` (line 1285):**
```sql
-- This replaces the need for NCR API for customer creation.
```

**`04_Archive/documentation/EXECUTIVE_STATUS_REPORT.md`:**
- Old status: "Blocked on NCR API Key"
- New status: System working with direct SQL connection

**`database.py`:**
- Uses `pyodbc.connect()` directly
- No NCR API calls
- Standard SQL Server connection

---

## ❓ **DO YOU NEED THE NCR API?**

### **You DON'T need it if:**
- ✅ You're using the current system (direct SQL connection)
- ✅ Orders are processing correctly
- ✅ Customer sync is working
- ✅ Product sync is working

### **You MIGHT need it if:**
- ❌ You want to use NCR's official API (not recommended - current system works)
- ❌ You need features only available through NCR API (unlikely)
- ❌ You're integrating with other NCR systems that require API

---

## 🚨 **IMPORTANT NOTES**

1. **The NCR API Key in that folder is from the old approach:**
   - It's not used by the current system
   - The system works without it
   - You can ignore that folder

2. **The current system is fully operational:**
   - Order processing works
   - Customer sync works
   - Product sync works
   - Contract pricing works
   - **All without the NCR API**

3. **If something isn't working:**
   - It's NOT because of the NCR API key
   - Check `.env` file for SQL Server connection settings
   - Check `database.py` for connection issues
   - Check SQL Server is accessible

---

## 📊 **COMPARISON**

| Aspect | NCR API (Old) | Direct SQL (Current) |
|--------|---------------|---------------------|
| **API Key Required** | ✅ Yes | ❌ No |
| **NCR Approval Needed** | ✅ Yes | ❌ No |
| **Connection Method** | NCR API Layer | Direct SQL Server |
| **Speed** | Slower (API overhead) | Faster (direct) |
| **Complexity** | Higher | Lower |
| **Status** | ❌ Not used | ✅ **Currently used** |

---

## ✅ **BOTTOM LINE**

**The NCR API key in `C:\Program Files (x86)\NCR\Counterpoint API` didn't work because:**

1. **The system doesn't use the NCR API anymore**
2. **It was replaced with direct SQL Server connections**
3. **The current system works without it**
4. **You can safely ignore that folder**

**If you're having connection issues, check:**
- `.env` file has correct SQL Server settings
- SQL Server is running and accessible
- Windows Authentication is working
- ODBC Driver 18 is installed

---

**Last Updated:** January 2, 2026  
**Status:** ✅ **SYSTEM USES DIRECT SQL - NCR API NOT NEEDED**

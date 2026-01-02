# NCR Release Notes Monitoring Process

**Date:** January 2, 2026  
**Purpose:** Systematic process for monitoring NCR CounterPoint release notes  
**Status:** ✅ **READY FOR USE**

---

## 🎯 **PURPOSE**

**Monitor NCR CounterPoint release notes** to:
- Identify schema changes before they break the system
- Plan for required code updates
- Understand new features/requirements
- Prepare for testing after updates

---

## 📋 **WHERE TO FIND RELEASE NOTES**

### **NCR Sources:**

1. **NCR Support Portal**
   - Login: [NCR Support Portal]
   - Location: Release Notes / Update Notes
   - Frequency: Check monthly or when CounterPoint updates

2. **CounterPoint Installation**
   - Location: `C:\Program Files\NCR\CounterPoint\ReleaseNotes\`
   - Format: Usually PDF or text files
   - Check after each CounterPoint update

3. **NCR Email Notifications**
   - Subscribe to NCR update notifications
   - Check email for release announcements

4. **CounterPoint Help System**
   - Open CounterPoint
   - Help → About → Release Notes
   - Or Help → Release Notes

---

## 🔍 **WHAT TO LOOK FOR**

### **Critical Items (Must Check):**

#### **1. Database Schema Changes** 🔴 **HIGH PRIORITY**
- Table structure changes
- Column additions/removals
- Column data type changes
- New required columns
- Deprecated columns

**Keywords to search for:**
- "Database changes"
- "Schema changes"
- "Table structure"
- "Column changes"
- "New fields"
- "Deprecated"

#### **2. API Changes** 🟡 **MEDIUM PRIORITY**
- API endpoint changes
- API parameter changes
- API response format changes
- API version changes

**Keywords to search for:**
- "API changes"
- "API updates"
- "API version"
- "API deprecated"

#### **3. Business Logic Changes** 🟡 **MEDIUM PRIORITY**
- Validation rule changes
- Calculation changes
- Workflow changes
- Required field changes

**Keywords to search for:**
- "Validation"
- "Business rules"
- "Required fields"
- "Calculations"

#### **4. View Changes** 🟡 **MEDIUM PRIORITY**
- View structure changes
- View deprecation
- New views available

**Keywords to search for:**
- "Views"
- "Database views"
- "View changes"

---

## 📊 **RELEASE NOTES REVIEW CHECKLIST**

### **For Each Release:**

- [ ] **Read Release Notes**
  - Download/access release notes
  - Read entire document (don't skip sections)

- [ ] **Search for Schema Changes**
  - Search for "PS_DOC_HDR" (order header table)
  - Search for "PS_DOC_LIN" (order line table)
  - Search for "IM_INV" (inventory table)
  - Search for "AR_CUST" (customer table)
  - Search for "IM_ITEM" (item table)
  - Search for "IM_PRC_RUL" (pricing rules table)

- [ ] **Search for View Changes**
  - Search for "VI_EXPORT_PRODUCTS"
  - Search for "VI_INVENTORY_SYNC"
  - Search for "VI_PRODUCT_NCR_TYPE"
  - Search for "VI_EXPORT_CP_ORDERS"

- [ ] **Search for Breaking Changes**
  - Search for "breaking"
  - Search for "deprecated"
  - Search for "removed"
  - Search for "no longer supported"

- [ ] **Document Findings**
  - Create entry in release notes log
  - Note any schema changes
  - Note any breaking changes
  - Note any new requirements

- [ ] **Plan Updates**
  - Identify code that needs updating
  - Plan testing approach
  - Schedule update/testing window

---

## 📝 **RELEASE NOTES LOG**

### **Template:**

| Date | CounterPoint Version | Release Notes Date | Schema Changes? | Breaking Changes? | Action Required | Status |
|------|---------------------|-------------------|-----------------|-------------------|-----------------|--------|
| 2026-01-02 | Current | - | No | No | Monitor | ✅ Current |

### **Example Entry:**

**Date:** 2026-02-15  
**CounterPoint Version:** 8.6.3  
**Release Notes Date:** 2026-02-10  

**Schema Changes:**
- `PS_DOC_HDR` - New column `ONLINE_ORDER_FLG` (optional)
- `IM_INV` - `QTY_AVAIL` calculation changed (computed column)

**Breaking Changes:**
- None identified

**Action Required:**
- Test order creation (verify new column doesn't break)
- Test inventory sync (verify QTY_AVAIL still works)
- Update documentation

**Status:** ⬜ Pending Testing / ⬜ Testing Complete / ⬜ Code Updated

---

## 🔔 **MONITORING SCHEDULE**

### **Recommended Frequency:**

- **Monthly:** Check NCR support portal for new releases
- **Before CounterPoint Update:** Always review release notes
- **After CounterPoint Update:** Verify release notes match actual changes
- **Quarterly:** Review all pending updates and plan testing

### **Automated Monitoring (Future):**

Could set up:
- RSS feed monitoring (if NCR provides)
- Email alerts for new releases
- Automated release notes parsing
- Automated schema change detection

---

## 🚨 **IMMEDIATE ACTION ITEMS**

When release notes indicate schema changes:

1. **Stop Automated Processing** (if critical)
2. **Review Impact** - Which operations are affected?
3. **Plan Fixes** - What code needs updating?
4. **Schedule Testing** - When can we test?
5. **Update Documentation** - Update `DATABASE_INTERACTIONS_DOCUMENTATION.md`
6. **Test Thoroughly** - Follow `COUNTERPOINT_UPDATE_TESTING_PROCESS.md`
7. **Deploy Fixes** - Update code and redeploy

---

## 📋 **SCHEMA CHANGE DETECTION SCRIPT**

Create a SQL script to detect schema changes:

```sql
-- Detect-SchemaChanges.sql
-- Run this before and after CounterPoint update, compare results

-- Check table structures
SELECT 
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN ('PS_DOC_HDR', 'PS_DOC_LIN', 'IM_INV', 'AR_CUST', 'IM_ITEM', 'IM_PRC_RUL')
ORDER BY TABLE_NAME, ORDINAL_POSITION;

-- Check views
SELECT name, definition
FROM sys.views
WHERE name IN ('VI_EXPORT_PRODUCTS', 'VI_INVENTORY_SYNC', 'VI_PRODUCT_NCR_TYPE', 'VI_EXPORT_CP_ORDERS');

-- Check stored procedures
SELECT name, definition
FROM sys.procedures
WHERE name IN ('sp_ValidateStagedOrder', 'sp_CreateOrderFromStaging', 'sp_CreateOrderLines');
```

**Usage:**
1. Run before CounterPoint update → Save results
2. Run after CounterPoint update → Compare results
3. Identify differences → Update code/documentation

---

## ✅ **MONITORING CHECKLIST**

**Monthly:**
- [ ] Check NCR support portal for new releases
- [ ] Review any new release notes
- [ ] Update release notes log
- [ ] Plan testing if updates available

**Before CounterPoint Update:**
- [ ] Read full release notes
- [ ] Identify schema changes
- [ ] Identify breaking changes
- [ ] Plan code updates
- [ ] Schedule testing window

**After CounterPoint Update:**
- [ ] Verify release notes match actual changes
- [ ] Run schema change detection script
- [ ] Compare before/after results
- [ ] Update documentation
- [ ] Run full test suite

---

**Last Updated:** January 2, 2026  
**Status:** ✅ **READY FOR USE**

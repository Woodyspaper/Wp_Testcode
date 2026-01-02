# NCR API Migration Plan (Future Consideration)

**Date:** January 2, 2026  
**Purpose:** Plan for potential migration to NCR API for critical operations  
**Status:** 📋 **FUTURE CONSIDERATION - Not Immediate Priority**

---

## 🎯 **PURPOSE**

**If NCR API key becomes available**, this document outlines:
- Which operations should migrate to NCR API
- Which operations should stay on direct SQL
- Migration approach and timeline
- Testing strategy
- Rollback plan

---

## 📊 **MIGRATION CANDIDATES**

### **Operations to Consider Migrating to NCR API:**

#### **1. Customer Creation** ⭐⭐⭐ **HIGH PRIORITY**
- **Current:** Direct SQL to `AR_CUST`, `AR_SHP_TO`
- **Why Migrate:**
  - Customer creation is critical business function
  - NCR API handles validation and business rules
  - Official support for customer management
  - Reduces risk of data integrity issues
- **Complexity:** Medium
- **Risk if Direct SQL:** Medium (customer data integrity)

#### **2. Order Status Updates** ⭐⭐ **MEDIUM PRIORITY**
- **Current:** Direct SQL updates to `PS_DOC_HDR`
- **Why Migrate:**
  - Order status is critical
  - NCR API ensures proper workflow
  - Official support for order management
- **Complexity:** Low
- **Risk if Direct SQL:** Low (read-only mostly)

#### **3. Inventory Queries** ⭐ **LOW PRIORITY**
- **Current:** Direct SQL SELECT from `IM_INV`
- **Why Migrate:**
  - Read-only operation (low risk)
  - NCR API may provide better performance
  - Official support
- **Complexity:** Low
- **Risk if Direct SQL:** Low (read-only)

---

### **Operations to KEEP on Direct SQL:**

#### **1. Order Creation** ⭐⭐⭐ **KEEP DIRECT SQL**
- **Current:** Direct SQL via stored procedures
- **Why Keep:**
  - ✅ **Performance critical** - Orders need to be created fast
  - ✅ **Custom logic** - We have custom business logic
  - ✅ **Working well** - Current system is proven
  - ✅ **Complex operations** - Batch line items, inventory updates
- **Risk:** Medium (but mitigated by stored procedures)

#### **2. Contract Pricing** ⭐⭐ **KEEP DIRECT SQL**
- **Current:** Direct SQL queries to pricing rules
- **Why Keep:**
  - ✅ **Performance critical** - Real-time pricing needs speed
  - ✅ **Complex queries** - Custom NCR type matching logic
  - ✅ **Working well** - Current system is proven
- **Risk:** Low (read-only)

#### **3. Product Sync** ⭐ **KEEP DIRECT SQL**
- **Current:** Direct SQL via views
- **Why Keep:**
  - ✅ **Performance** - Large batch operations
  - ✅ **Custom views** - We control the view structure
  - ✅ **Working well** - Current system is proven
- **Risk:** Low (read-only)

---

## 🔄 **HYBRID APPROACH (RECOMMENDED)**

### **Use Both Methods:**

```
┌─────────────────────────────────────┐
│  Direct SQL (Keep)                  │
│  - Order creation (performance)     │
│  - Contract pricing (performance)   │
│  - Product sync (performance)       │
│  - Inventory sync (performance)    │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  NCR API (Migrate)                  │
│  - Customer creation (support)      │
│  - Order status updates (support)  │
│  - Critical validations (support) │
└─────────────────────────────────────┘
```

**Benefits:**
- Best of both worlds
- Performance where needed
- Official support where needed
- Gradual migration path

---

## 📋 **MIGRATION PLAN**

### **Phase 1: Customer Creation** (If API Key Available)

#### **Step 1: Research NCR API Customer Endpoints**
- [ ] Review NCR API documentation
- [ ] Identify customer creation endpoint
- [ ] Understand required parameters
- [ ] Understand response format
- [ ] Test with API key

#### **Step 2: Implement NCR API Customer Creation**
- [ ] Create `woo_customers_api.py` (NCR API version)
- [ ] Implement customer creation via API
- [ ] Implement ship-to creation via API
- [ ] Handle API errors
- [ ] Add logging

#### **Step 3: Testing**
- [ ] Test customer creation via API
- [ ] Test error handling
- [ ] Test duplicate handling
- [ ] Compare with direct SQL results
- [ ] Performance testing

#### **Step 4: Gradual Rollout**
- [ ] Deploy alongside direct SQL version
- [ ] Feature flag to switch between methods
- [ ] Monitor for issues
- [ ] Gradually migrate customers
- [ ] Full migration when stable

#### **Step 5: Cleanup**
- [ ] Remove direct SQL customer creation code
- [ ] Update documentation
- [ ] Update monitoring

**Timeline:** 2-4 weeks (if API key available)

---

### **Phase 2: Order Status Updates** (If API Key Available)

Similar process for order status updates.

**Timeline:** 1-2 weeks (if API key available)

---

## 🧪 **TESTING STRATEGY**

### **For Each Migration:**

1. **Parallel Testing:**
   - Run both methods (API and direct SQL)
   - Compare results
   - Verify data integrity

2. **Performance Testing:**
   - Compare API vs direct SQL performance
   - Measure latency
   - Measure throughput

3. **Error Handling Testing:**
   - Test API error scenarios
   - Test network failures
   - Test invalid data
   - Test rate limiting

4. **Rollback Testing:**
   - Test switching back to direct SQL
   - Verify no data loss
   - Verify system stability

---

## 🔄 **ROLLBACK PLAN**

### **If Migration Fails:**

1. **Immediate Rollback:**
   - Switch feature flag back to direct SQL
   - Disable NCR API code
   - Verify system works with direct SQL

2. **Investigation:**
   - Document what failed
   - Identify root cause
   - Plan fixes

3. **Re-attempt:**
   - Fix issues
   - Re-test
   - Re-deploy

---

## 📊 **MIGRATION DECISION MATRIX**

| Operation | Current Method | Migrate to API? | Priority | Complexity | Risk if Stay Direct SQL |
|-----------|---------------|-----------------|----------|------------|------------------------|
| **Order Creation** | Direct SQL | ❌ **NO** | - | - | Medium (mitigated) |
| **Customer Creation** | Direct SQL | ✅ **YES** | High | Medium | Medium |
| **Order Status** | Direct SQL | ✅ **YES** | Medium | Low | Low |
| **Contract Pricing** | Direct SQL | ❌ **NO** | - | - | Low |
| **Product Sync** | Direct SQL | ❌ **NO** | - | - | Low |
| **Inventory Sync** | Direct SQL | ❌ **NO** | - | - | Low |

---

## ✅ **MIGRATION CHECKLIST**

### **Before Starting Migration:**

- [ ] NCR API key obtained and tested
- [ ] NCR API documentation reviewed
- [ ] NCR API endpoints tested
- [ ] Migration plan approved
- [ ] Testing environment ready
- [ ] Rollback plan ready
- [ ] Team trained on NCR API

### **During Migration:**

- [ ] Implement API version alongside direct SQL
- [ ] Test thoroughly
- [ ] Monitor for issues
- [ ] Gradual rollout
- [ ] Document changes

### **After Migration:**

- [ ] All tests passing
- [ ] Performance acceptable
- [ ] No data integrity issues
- [ ] Documentation updated
- [ ] Direct SQL code removed (if applicable)
- [ ] Team notified

---

## 🚨 **IMPORTANT NOTES**

1. **Don't Migrate Everything:**
   - Keep direct SQL for performance-critical operations
   - Only migrate operations that benefit from official support
   - Hybrid approach is recommended

2. **Test Thoroughly:**
   - NCR API may behave differently than direct SQL
   - Test all edge cases
   - Test error scenarios

3. **Gradual Migration:**
   - Don't migrate everything at once
   - Start with low-risk operations
   - Monitor and adjust

4. **Keep Direct SQL as Backup:**
   - Maintain direct SQL code as fallback
   - Can switch back if API has issues
   - Provides redundancy

---

## 📅 **TIMELINE (If API Key Available)**

- **Month 1:** Research and planning
- **Month 2:** Customer creation migration
- **Month 3:** Order status migration
- **Month 4:** Testing and optimization
- **Ongoing:** Monitor and maintain

**Note:** This is a future consideration. Current direct SQL system is working well.

---

**Last Updated:** January 2, 2026  
**Status:** 📋 **FUTURE CONSIDERATION - Not Immediate Priority**

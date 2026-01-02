# CounterPoint ↔ WooCommerce Integration Roadmap

**Date:** December 18, 2024  
**Status:** Phase 1 Complete, Phase 2-5 Planned  
**Based on:** Legacy assets + Current implementation

---

## 🎯 Current Status

### ✅ Phase 1: Customer & Order Sync (COMPLETE)

**Implemented:**
- ✅ Customer sync (WooCommerce → CP staging)
- ✅ Order staging (WooCommerce → CP staging)
- ✅ Customer mapping (`USER_CUSTOMER_MAP`)
- ✅ Edge case handling
- ✅ Data validation and sanitization
- ✅ Comprehensive customer fetching (handles WooCommerce quirks)

**Files:**
- `woo_customers.py` - Customer sync
- `woo_orders.py` - Order staging
- `manage_woo_customers.py` - Customer management
- `staging_tables.sql` - Database schema
- `data_utils.py` - Data sanitization

**Next Steps:**
- ⏳ Order creation in CP (from staging)
- ⏳ Order status sync (CP → WooCommerce)

---

## 📋 Phase 2: Product Sync (NEXT)

### Goals
- Sync products from CounterPoint to WooCommerce
- Handle categories, descriptions, images
- Implement catalog sync (6-hour schedule)

### Required Assets
- `ITEM_IMPORT_TEST.csv` - Product format reference
- `ECOM_DESCRIPTION_IMPORT.csv` - E-commerce descriptions
- `CATEGORY_IMPORT.csv` - Category mapping
- `wc-product-export-19-8-2025-1755614763998_Edited for import.csv` - WooCommerce format

### Implementation Plan

1. **Create `woo_products.py`**
   ```python
   # Functions needed:
   - fetch_cp_products() - Get products from IM_ITEM
   - map_to_woocommerce() - Transform CP → WooCommerce format
   - sync_products() - Push to WooCommerce
   - handle_categories() - Category mapping
   - handle_images() - Product image sync
   ```

2. **Category Mapping**
   - Review `CATEGORY_IMPORT.csv`
   - Create category mapping table
   - Map CP categories to WooCommerce categories

3. **Product Descriptions**
   - Use `ECOM_DESCRIPTION_IMPORT.csv` format
   - Handle short/long descriptions
   - Sync product attributes

4. **Sync Schedule**
   - Implement 6-hour catalog sync
   - Use cron or scheduled task
   - Handle incremental updates

### Estimated Time: 2-3 weeks

---

## 📋 Phase 3: Inventory Sync

### Goals
- Sync inventory levels from CP to WooCommerce
- Real-time stock updates (5-minute sync)
- Handle location codes (MAIN, WEB)

### Required Assets
- `Current_INV_3.28.25.xlsx` - Inventory baseline
- `IM_INV` table structure
- Inventory sync patterns

### Implementation Plan

1. **Create `woo_inventory.py`**
   ```python
   # Functions needed:
   - fetch_cp_inventory() - Get inventory from IM_INV
   - calculate_available_stock() - Handle location codes
   - update_woocommerce_stock() - Update WooCommerce stock
   - handle_backorders() - Backorder logic
   ```

2. **Location Handling**
   - Use `MAIN` and `WEB` location codes
   - Calculate available stock per location
   - Handle multi-location inventory

3. **Sync Schedule**
   - Implement 5-minute inventory sync
   - Use efficient delta updates
   - Handle high-frequency updates

### Estimated Time: 1-2 weeks

---

## 📋 Phase 4: Pricing Sync

### Goals
- Sync pricing from CP to WooCommerce
- Handle tier-based pricing
- Customer-specific pricing
- Use `WEB_PRICE` price level

### Required Assets
- `TIER_LEVEL_IMPORT.csv` - Tier structure
- `IM_PRC` table structure
- `WEB_PRICE` price level configuration

### Implementation Plan

1. **Create `woo_pricing.py`**
   ```python
   # Functions needed:
   - fetch_cp_pricing() - Get pricing from IM_PRC
   - calculate_web_price() - Use WEB_PRICE level
   - apply_tier_pricing() - Tier-based discounts
   - update_woocommerce_prices() - Update WooCommerce
   ```

2. **Tier Pricing**
   - Review `TIER_LEVEL_IMPORT.csv`
   - Map `CATEG_COD` to pricing tiers
   - Apply customer-specific pricing

3. **Price Level**
   - Use `WEB_PRICE` from configuration
   - Handle price breaks
   - Sync regular and sale prices

### Estimated Time: 1-2 weeks

---

## 📋 Phase 5: Order Push

### Goals
- Create orders in CounterPoint from WooCommerce
- Sync order status (CP → WooCommerce)
- Handle payment processing
- Implement 2-minute push schedule

### Required Assets
- `PS_DOC_HDR` / `PS_DOC_LIN` structure
- Order import patterns
- Payment gateway integration

### Implementation Plan

1. **Enhance `woo_orders.py`**
   ```python
   # Functions needed:
   - create_cp_order() - Create order in PS_DOC_HDR
   - add_order_lines() - Add lines to PS_DOC_LIN
   - sync_order_status() - Update WooCommerce status
   - handle_payments() - Payment processing
   ```

2. **Order Creation**
   - Use staging table → CP order creation
   - Handle order validation
   - Map WooCommerce → CP fields

3. **Status Sync**
   - Sync CP order status to WooCommerce
   - Handle status transitions
   - Update order notes

4. **Sync Schedule**
   - Implement 2-minute order push
   - Handle high-frequency updates
   - Queue management

### Estimated Time: 2-3 weeks

---

## 🔄 Sync Schedule Summary

| Sync Type | Frequency | Phase | Status |
|-----------|-----------|-------|--------|
| **Catalog** | Every 6 hours | Phase 2 | ⏳ Planned |
| **Inventory** | Every 5 minutes | Phase 3 | ⏳ Planned |
| **Orders** | Every 2 minutes | Phase 5 | ⏳ Planned |
| **Customers** | On-demand | Phase 1 | ✅ Complete |
| **Pricing** | On-demand | Phase 4 | ⏳ Planned |

---

## 📁 File Structure (Future)

```
WP_Testcode/
├── woo_customers.py          ✅ Complete
├── woo_orders.py             ✅ Complete (staging)
├── woo_products.py           ⏳ Phase 2
├── woo_inventory.py          ⏳ Phase 3
├── woo_pricing.py            ⏳ Phase 4
├── sync.py                   ⏳ All phases (scheduler)
├── staging_tables.sql        ✅ Complete
├── data_utils.py             ✅ Complete
└── config/
    ├── appsettings.json      ⏳ Phase 2 (from legacy)
    └── category_mapping.csv  ⏳ Phase 2
```

---

## 🎯 Success Criteria

### Phase 1 ✅
- [x] Customers sync from WooCommerce to CP
- [x] Orders stage from WooCommerce to CP
- [x] Customer mapping works
- [x] Edge cases handled

### Phase 2 (Next)
- [ ] Products sync from CP to WooCommerce
- [ ] Categories mapped correctly
- [ ] Descriptions sync properly
- [ ] 6-hour catalog sync works

### Phase 3
- [ ] Inventory syncs every 5 minutes
- [ ] Stock levels accurate
- [ ] Location codes handled
- [ ] Backorders handled

### Phase 4
- [ ] Pricing syncs correctly
- [ ] Tier pricing works
- [ ] Customer-specific pricing works
- [ ] WEB_PRICE level used

### Phase 5
- [ ] Orders create in CP
- [ ] Order status syncs
- [ ] 2-minute push works
- [ ] Payment processing works

---

## 📝 Notes

- **Legacy Assets:** Use existing import templates and formats
- **Sync Frequency:** Follow `appsettings.json` schedules
- **Error Handling:** Learn from `.ERR` and `.LOG` files
- **Validation:** Use staging tables before production
- **Testing:** Test each phase before moving to next

---

**Last Updated:** December 18, 2024  
**Next Milestone:** Phase 2 - Product Sync  
**Estimated Completion:** Q1 2025

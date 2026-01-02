# CounterPoint Product & Inventory Summary

**Date:** December 23, 2025  
**Source:** `VI_EXPORT_PRODUCTS` view testing

---

## 📊 **Product Counts**

### **Total Products:**
- **1,528 products** total in CounterPoint (`IM_ITEM` table)

### **E-Commerce Products:**
- **1,189 e-commerce items** (`IS_ECOMM_ITEM = 'Y'`)
- **339 non-e-commerce items** (not flagged for web)

---

## 📦 **Inventory Information**

### **Stock Data Available:**
- **Source Table:** `IM_INV` (Inventory table)
- **Field:** `QTY_ON_HND` (Quantity on Hand)
- **Aggregation:** Sums stock across all locations
- **Current View:** `VI_EXPORT_PRODUCTS` includes `STOCK_QTY` field

### **Stock Examples (from testing):**
- Product `01-10100`: **527 units** in stock
- Product `01-10105`: **264 units** in stock
- Product `01-10108`: **598 units** in stock
- Product `01-10109`: **175 units** in stock
- Some products show **0 stock** or **negative stock** (backorders)

---

## 📋 **Product Data Available**

### **From `VI_EXPORT_PRODUCTS` View:**

| Field | Source | Description |
|-------|--------|-------------|
| **SKU** | `IM_ITEM.ITEM_NO` | Product SKU (unique identifier) |
| **NAME** | `IM_ITEM.DESCR` or `SHORT_DESCR` | Product name |
| **SHORT_DESC** | `IM_ITEM.SHORT_DESCR` or `DESCR` | Short description |
| **LONG_DESC** | `EC_ITEM_DESCR.HTML_DESCR` or `LONG_DESCR` | Full HTML description |
| **ACTIVE** | `IM_ITEM.IS_ECOMM_ITEM` | 1 if 'Y', 0 otherwise |
| **STOCK_QTY** | `IM_INV.QTY_ON_HND` (summed) | Total stock across locations |
| **CATEGORY_CODE** | `IM_ITEM.CATEG_COD` | Category code |

---

## 🏷️ **Category Information**

### **Categories Found:**
- **PRINT AND** - Print & Paper products
- **ENVELOPES** - Envelope products
- **DELI & HOS** - Deli & Hospitality products
- And more...

### **Category Examples:**
- `01-10100` → Category: `PRINT AND`
- `01-30034` → Category: `ENVELOPES`
- `01-11691` → Category: `DELI & HOS`

---

## 📈 **Sales History Data**

### **From Sales Analysis Queries:**

- **Sales Records:** 10,193 total sales transactions
- **Last 12 Months:** 8,660 transactions
- **Unique Items Sold:** 868 items sold in last 12 months
- **Date Range:** November 4, 2024 to December 22, 2025

### **Sales Activity:**
- Some products sold recently (last 1-5 days)
- Some products haven't sold in 6+ months (slow-moving)
- Most active products: Regularly sold items

---

## 🔍 **Product Details Available**

### **Description Fields:**
- **DESCR** (varchar 250) - Main product description
- **SHORT_DESCR** (varchar 15) - Short description
- **LONG_DESCR** (varchar 50) - Long description
- **HTML_DESCR** (text) - Full HTML description from `EC_ITEM_DESCR` table

### **E-Commerce Flags:**
- **IS_ECOMM_ITEM** (varchar 1) - 'Y' = e-commerce enabled, 'N' = not enabled
- **ECOMM_PUB_STAT** (tinyint) - Publication status (currently NULL for most items)

---

## 📍 **Inventory Locations**

- Stock is tracked by location (`LOC_ID`)
- View sums stock across **all locations**
- Can filter by specific location if needed (e.g., '01' = Main warehouse)

---

## ⚠️ **Important Notes**

1. **Stock Quantities:**
   - Phase 2 product sync will NOT update stock until Phase 3 (Inventory Sync) is enabled
   - View includes stock data, but product sync won't push it yet

2. **Negative Stock:**
   - Some products show negative stock (backorders)
   - Example: `01-10112` shows `-51` units

3. **Missing Descriptions:**
   - Some products may have NULL descriptions
   - View uses fallback logic (DESCR → SHORT_DESCR → LONG_DESCR)

---

## 🎯 **Next Steps for Product Sync**

1. **Create `USER_PRODUCT_MAP`** - Map CP SKU ↔ WooCommerce product ID
2. **Category Mapping** - Map CP categories to WooCommerce categories
3. **Image Handling** - Determine source of truth for product images
4. **End-to-End Test** - Sync 10 products and verify
5. **Inventory Sync** (Phase 3) - Enable stock quantity updates

---

**Last Updated:** December 23, 2025


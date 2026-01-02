# CP Orders WordPress Plugin - Explanation

**Date:** January 2, 2026  
**File:** `wordpress/woocommerce-cp-orders.php`  
**Status:** ✅ **READY FOR USE** (if needed)

---

## 🎯 **WHAT IS THIS PLUGIN?**

The `woocommerce-cp-orders.php` plugin is a **WordPress plugin** that displays **CounterPoint orders** on your retail website. It's a **display/read-only** feature - it does NOT create orders or process anything.

**Key Point:** This is **separate** from the main order processing pipeline. It's for **showing existing CounterPoint orders** on the website, not for creating orders.

---

## 📍 **WHERE IT'S USED**

### **Location:**
- **WordPress Plugin:** Upload to `/wp-content/plugins/` directory
- **Activate:** Via WordPress Admin → Plugins
- **Configure:** WordPress Admin → Settings → CP Orders

### **When to Use:**
- ✅ **Display orders on public pages** (e.g., "Recent Orders" page)
- ✅ **Show order history** to customers
- ✅ **Display orders by unit type** (Each, Pack, Box, Carton, Pallet, Ton)
- ✅ **Filter orders** by date, customer, status
- ✅ **Show order details** with proper unit names

### **When NOT to Use:**
- ❌ **NOT for creating orders** (that's what `woo_orders.py` does)
- ❌ **NOT for processing orders** (that's what `cp_order_processor.py` does)
- ❌ **NOT part of the order processing pipeline**

---

## 🔧 **HOW IT WORKS**

### **Architecture:**

```
WordPress Website
    ↓
[cp_orders] shortcode on page/post
    ↓
woocommerce-cp-orders.php plugin
    ↓
Calls API: http://your-server:5001/api/cp-orders
    ↓
api/cp_orders_api_enhanced.py (Flask API)
    ↓
Queries CounterPoint database
    ↓
Returns order data
    ↓
Plugin displays on WordPress page
```

### **Components:**

1. **WordPress Plugin** (`woocommerce-cp-orders.php`)
   - Provides shortcode: `[cp_orders]`
   - Caches API responses (10 minutes default)
   - Formats orders for display
   - Admin settings page

2. **Flask API** (`api/cp_orders_api_enhanced.py`)
   - REST API endpoint: `/api/cp-orders`
   - Queries CounterPoint database
   - Returns JSON with order data
   - Requires API key authentication

3. **Database View** (`01_Production/counterpoint_orders_export_view_corrected.sql`)
   - Creates `VI_EXPORT_CP_ORDERS` view
   - Exposes order data for API to query

---

## 📋 **SETUP INSTRUCTIONS**

### **Step 1: Deploy the API**

The API must be running before the plugin can work:

```powershell
# Start the CP Orders API
cd api
python cp_orders_api_enhanced.py

# Or in production with gunicorn:
gunicorn -w 4 -b 0.0.0.0:5001 cp_orders_api_enhanced:app
```

**Default Port:** `5001`  
**Default Endpoint:** `http://localhost:5001/api/cp-orders`

### **Step 2: Configure API Key**

Set in `.env` file:
```env
CP_ORDERS_API_KEY=your_api_key_here
REQUIRE_API_KEY=true
```

### **Step 3: Create Database View**

Run the SQL script to create the view:
```sql
-- Run this in CounterPoint database
01_Production/counterpoint_orders_export_view_corrected.sql
```

This creates `VI_EXPORT_CP_ORDERS` view that the API queries.

### **Step 4: Upload WordPress Plugin**

1. **Upload plugin file:**
   - Copy `wordpress/woocommerce-cp-orders.php` to WordPress
   - Upload to: `/wp-content/plugins/woocommerce-cp-orders/woocommerce-cp-orders.php`

2. **Activate plugin:**
   - WordPress Admin → Plugins
   - Find "WooCommerce CounterPoint Orders Display"
   - Click "Activate"

### **Step 5: Configure Plugin Settings**

1. **Go to:** WordPress Admin → Settings → CP Orders

2. **Configure:**
   - **API URL:** `http://your-server:5001/api/cp-orders`
   - **API Key:** (same as `CP_ORDERS_API_KEY` in `.env`)
   - **Cache TTL:** `600` (10 minutes, default)

3. **Save Settings**

---

## 💻 **USAGE EXAMPLES**

### **Basic Usage:**

Add shortcode to any WordPress page or post:

```
[cp_orders]
```

This displays all recent orders (default: last 50 orders).

### **Filter by Unit Type:**

```
[cp_orders unit="PL"]
```

Shows only Pallet orders.

**Available Units:**
- `EA` - Each
- `PK` - Pack
- `BX` - Box
- `CT` - Carton
- `PL` - Pallet
- `TON` - Ton

### **Filter by Date Range:**

```
[cp_orders date_from="2025-01-01" date_to="2025-12-31"]
```

### **Filter by Customer:**

```
[cp_orders customer_no="CUST001"]
```

### **Group by Unit Type:**

```
[cp_orders group_by_unit="true"]
```

Groups orders by unit type (Each, Pack, Box, etc.)

### **Combined Filters:**

```
[cp_orders unit="PL" date_from="2025-01-01" limit="20"]
```

Shows up to 20 Pallet orders from 2025.

---

## 🎨 **DISPLAY FORMAT**

The plugin displays orders with:
- **Order Number** and **Date**
- **Customer Name** (if available)
- **SKU** and **Item Description**
- **Quantity** with **Unit Display Name** (e.g., "50 Pallets")
- **Price** and **Line Total** (if available)

**Example Output:**
```
Order #101-000123 - 2025-01-02 - ABC Company
  01-10100 - Paper Roll 24"
  Quantity: 50 Pallets
  Price: $125.00 | Total: $6,250.00
```

---

## ⚙️ **CONFIGURATION OPTIONS**

### **Shortcode Attributes:**

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `unit` | string | `""` | Filter by unit (EA, PK, BX, CT, PL, TON) |
| `date_from` | date | `""` | Start date (YYYY-MM-DD) |
| `date_to` | date | `""` | End date (YYYY-MM-DD) |
| `customer_no` | string | `""` | Customer number filter |
| `status` | string | `""` | Order status filter |
| `limit` | number | `50` | Max orders to display |
| `group_by_unit` | boolean | `false` | Group orders by unit type |

### **WordPress Settings:**

- **API URL:** Full URL to CP Orders API
- **API Key:** Authentication key (must match `.env` file)
- **Cache TTL:** How long to cache responses (seconds)

---

## 🔄 **HOW IT RELATES TO THE PIPELINE**

### **Order Processing Pipeline (Main System):**
```
WooCommerce Order → woo_orders.py → USER_ORDER_STAGING → cp_order_processor.py → CounterPoint
```
**Purpose:** Create orders in CounterPoint from WooCommerce

### **CP Orders Display Plugin (This Plugin):**
```
CounterPoint Orders → API → WordPress Plugin → Display on Website
```
**Purpose:** Show existing CounterPoint orders on the website

**They are SEPARATE systems:**
- ✅ Order processing: WooCommerce → CounterPoint (creates orders)
- ✅ Orders display: CounterPoint → WordPress (shows orders)

---

## ❓ **DO YOU NEED THIS PLUGIN?**

### **You NEED it if:**
- ✅ You want to display CounterPoint orders on your website
- ✅ Customers should see order history
- ✅ You want to show orders by unit type on public pages
- ✅ You need to display order information on WordPress pages

### **You DON'T need it if:**
- ❌ You only need to create orders (main pipeline handles that)
- ❌ You don't need to display orders on the website
- ❌ Orders are only viewed in CounterPoint, not on website

---

## 🚨 **IMPORTANT NOTES**

1. **API Must Be Running:**
   - The plugin requires `api/cp_orders_api_enhanced.py` to be running
   - Default port: `5001`
   - Must be accessible from WordPress server

2. **Database View Required:**
   - Must run `counterpoint_orders_export_view_corrected.sql` first
   - Creates `VI_EXPORT_CP_ORDERS` view

3. **API Key Security:**
   - API key must match between `.env` and WordPress plugin settings
   - Keep API key secure (don't commit to git)

4. **Caching:**
   - Plugin caches responses for 10 minutes (default)
   - Reduces API calls and improves performance
   - Cache TTL configurable in plugin settings

---

## 📊 **API ENDPOINTS USED**

The plugin calls these API endpoints:

1. **`GET /api/cp-orders`**
   - General orders query
   - Supports filters: date, customer, status, unit, limit

2. **`GET /api/cp-orders/by-unit/<unit_code>`**
   - Orders filtered by specific unit type
   - Example: `/api/cp-orders/by-unit/PL?days=30`

---

## ✅ **STATUS**

**Current Status:** ✅ **READY FOR USE** (if you need to display orders)

**If you don't need to display orders on the website, you can ignore this plugin.**

**If you do need it:**
1. Deploy the API (`api/cp_orders_api_enhanced.py`)
2. Create the database view
3. Upload and activate the WordPress plugin
4. Configure settings
5. Use `[cp_orders]` shortcode on pages

---

**Last Updated:** January 2, 2026  
**Status:** ✅ **DOCUMENTED - READY IF NEEDED**

"""
woo_products.py - Sync products from CounterPoint to WooCommerce

Handles:
  - CP → Woo: Export products from VI_EXPORT_PRODUCTS view to WooCommerce
  - Product mapping (USER_PRODUCT_MAP)
  - Category mapping (USER_CATEGORY_MAP)
  - HTML sanitization for descriptions
  - Stock quantity sync (Phase 2 - will not update stock until Phase 3)

Usage:
    python woo_products.py sync             # Sync products (dry-run)
    python woo_products.py sync --apply     # Sync products (live)
    python woo_products.py sync --max 10    # Sync first 10 products
    python woo_products.py sync --sku SKU123 # Sync specific SKU
"""

import sys
import argparse
import datetime as dt
import uuid
import html
import re
from typing import List, Dict, Optional, Set
from html.parser import HTMLParser

from database import get_connection, connection_ctx
from config import load_integration_config, IntegrationConfig
from woo_client import WooClient
from data_utils import sanitize_string


# ---------- HTML Sanitization ----------

class HTMLSanitizer(HTMLParser):
    """Simple HTML sanitizer that allows safe tags and strips dangerous ones."""
    
    ALLOWED_TAGS = {
        'p', 'br', 'strong', 'b', 'em', 'i', 'u', 'ul', 'ol', 'li',
        'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'a', 'img', 'div', 'span',
        'table', 'tr', 'td', 'th', 'thead', 'tbody', 'tfoot'
    }
    
    ALLOWED_ATTRS = {
        'href', 'src', 'alt', 'title', 'class', 'style', 'width', 'height'
    }
    
    def __init__(self):
        super().__init__()
        self.result = []
        self.tag_stack = []
    
    def handle_starttag(self, tag, attrs):
        tag_lower = tag.lower()
        if tag_lower in self.ALLOWED_TAGS:
            self.tag_stack.append(tag_lower)
            attrs_dict = dict(attrs)
            # Filter allowed attributes
            safe_attrs = {k: v for k, v in attrs_dict.items() 
                         if k.lower() in self.ALLOWED_ATTRS}
            # Build tag string
            attr_str = ' '.join(f'{k}="{html.escape(v)}"' for k, v in safe_attrs.items())
            if attr_str:
                self.result.append(f'<{tag_lower} {attr_str}>')
            else:
                self.result.append(f'<{tag_lower}>')
        # Self-closing tags
        elif tag_lower in ('br', 'img', 'hr'):
            attrs_dict = dict(attrs)
            safe_attrs = {k: v for k, v in attrs_dict.items() 
                         if k.lower() in self.ALLOWED_ATTRS}
            attr_str = ' '.join(f'{k}="{html.escape(v)}"' for k, v in safe_attrs.items())
            if attr_str:
                self.result.append(f'<{tag_lower} {attr_str} />')
            else:
                self.result.append(f'<{tag_lower} />')
    
    def handle_endtag(self, tag):
        tag_lower = tag.lower()
        if tag_lower in self.ALLOWED_TAGS and self.tag_stack and self.tag_stack[-1] == tag_lower:
            self.tag_stack.pop()
            self.result.append(f'</{tag_lower}>')
    
    def handle_data(self, data):
        self.result.append(html.escape(data))
    
    def sanitize(self, html_content: str) -> str:
        """Sanitize HTML content and return safe HTML string."""
        if not html_content:
            return ''
        
        # Reset state
        self.result = []
        self.tag_stack = []
        
        # Parse and sanitize
        self.feed(html_content)
        self.close()
        
        # Clean up any unclosed tags
        while self.tag_stack:
            tag = self.tag_stack.pop()
            self.result.append(f'</{tag}>')
        
        return ''.join(self.result)


def sanitize_html(html_content: str) -> str:
    """
    Sanitize HTML content for safe display in WooCommerce.
    
    Allows safe HTML tags (p, br, strong, etc.) and strips dangerous ones.
    Escapes text content to prevent XSS.
    """
    if not html_content:
        return ''
    
    # If content doesn't look like HTML, just sanitize as plain text
    if not re.search(r'<[a-z]+[^>]*>', html_content, re.IGNORECASE):
        return sanitize_string(html_content)
    
    sanitizer = HTMLSanitizer()
    return sanitizer.sanitize(html_content)


# ---------- Data access ----------

def parse_updated_since(value: str, last_sync: Optional[dt.datetime] = None) -> Optional[dt.datetime]:
    """
    Parse --updated-since parameter.
    
    Supports:
    - ISO format: '2025-12-23T10:00:00'
    - Relative hours: '24h' (24 hours ago)
    - Relative days: '7d' (7 days ago)
    - 'last' (use last successful sync time)
    """
    if not value:
        return None
    
    value = value.strip().lower()
    
    if value == 'last':
        return last_sync
    
    # Relative time: Xh or Xd
    if value.endswith('h'):
        hours = int(value[:-1])
        return dt.datetime.now() - dt.timedelta(hours=hours)
    elif value.endswith('d'):
        days = int(value[:-1])
        return dt.datetime.now() - dt.timedelta(days=days)
    
    # ISO format
    try:
        return dt.datetime.fromisoformat(value.replace('Z', '+00:00'))
    except ValueError:
        raise ValueError(f"Invalid --updated-since format: {value}. Use ISO format, 'Xh', 'Xd', or 'last'")


def fetch_products(conn, max_records: int = None, sku_filter: str = None, updated_since: Optional[dt.datetime] = None) -> List[Dict]:
    """
    Fetch products from VI_EXPORT_PRODUCTS view.
    
    Args:
        conn: Database connection
        max_records: Maximum number of records to fetch (None = all)
        sku_filter: Optional SKU to filter by
        updated_since: Optional timestamp to filter by (only products updated since this time)
        
    Returns:
        List of product dictionaries
    """
    cur = conn.cursor()
    
    # Build WHERE clause
    where_clauses = []
    params = []
    
    if sku_filter:
        where_clauses.append("SKU = ?")
        params.append(sku_filter)
    
    # Check if LST_MAINT_DT column exists in the view (for incremental sync)
    # If not available, we'll skip incremental filtering
    has_lst_maint_dt = False
    try:
        test_cur = conn.cursor()
        test_cur.execute("SELECT TOP 1 LST_MAINT_DT FROM dbo.VI_EXPORT_PRODUCTS")
        has_lst_maint_dt = True
        test_cur.close()
    except Exception as e:
        # Column doesn't exist, skip incremental sync
        has_lst_maint_dt = False
        if updated_since:
            print(f"  WARNING: LST_MAINT_DT column not found in view. Skipping incremental sync filter.")
            updated_since = None
    
    if updated_since and has_lst_maint_dt:
        where_clauses.append("LST_MAINT_DT >= ?")
        params.append(updated_since)
    
    where_sql = "WHERE " + " AND ".join(where_clauses) if where_clauses else ""
    
    # Order by clause - use LST_MAINT_DT if available, otherwise just SKU
    order_by = "ORDER BY LST_MAINT_DT DESC, SKU" if has_lst_maint_dt else "ORDER BY SKU"
    
    if sku_filter:
        sql = f"""
            SELECT SKU, NAME, SHORT_DESC, LONG_DESC, ACTIVE, STOCK_QTY, CATEGORY_CODE
            FROM dbo.VI_EXPORT_PRODUCTS
            {where_sql}
            {order_by};
        """
        cur.execute(sql, tuple(params))
    elif max_records:
        sql = f"""
            SELECT TOP ({max_records})
                SKU, NAME, SHORT_DESC, LONG_DESC, ACTIVE, STOCK_QTY, CATEGORY_CODE
            FROM dbo.VI_EXPORT_PRODUCTS
            {where_sql}
            {order_by};
        """
        cur.execute(sql, tuple(params))
    else:
        sql = f"""
            SELECT SKU, NAME, SHORT_DESC, LONG_DESC, ACTIVE, STOCK_QTY, CATEGORY_CODE
            FROM dbo.VI_EXPORT_PRODUCTS
            {where_sql}
            {order_by};
        """
        cur.execute(sql, tuple(params))
    
    cols = [c[0] for c in cur.description]
    rows = [dict(zip(cols, r)) for r in cur.fetchall()]
    return rows


def get_category_mapping(conn, category_code: str) -> Optional[int]:
    """
    Get WooCommerce category ID for a CP category code.
    
    Returns:
        WooCommerce category ID or None if not mapped
    """
    if not category_code:
        return None
    
    sql = """
        SELECT WOO_CATEGORY_ID
        FROM dbo.USER_CATEGORY_MAP
        WHERE CP_CATEGORY_CODE = ? AND IS_ACTIVE = 1;
    """
    cur = conn.cursor()
    cur.execute(sql, (category_code,))
    row = cur.fetchone()
    if row:
        return row[0]
    return None


def prepare_product_payload(product: Dict, category_id: Optional[int] = None, config: Optional[IntegrationConfig] = None) -> Dict:
    """
    Prepare a comprehensive product payload for WooCommerce API.
    Includes all available CounterPoint data: pricing, images, weight, dimensions, etc.
    
    Args:
        product: Product dict from VI_EXPORT_PRODUCTS (comprehensive view)
        category_id: WooCommerce category ID (optional)
        config: IntegrationConfig for image_base_url (optional)
        
    Returns:
        WooCommerce product payload dictionary with all available fields
    """
    # Sanitize and prepare data
    name = sanitize_string(product.get("NAME") or "", max_length=200)
    short_desc = sanitize_html(product.get("SHORT_DESC") or "")
    long_desc = sanitize_html(product.get("LONG_DESC") or "")
    
    # Get stock quantity from view (STOCK_QTY field)
    stock_qty = product.get("STOCK_QTY", 0)
    try:
        stock_qty = int(float(stock_qty)) if stock_qty is not None else 0
    except (ValueError, TypeError):
        stock_qty = 0
    
    # Determine stock status based on quantity
    if stock_qty > 0:
        stock_status = "instock"
    elif stock_qty < 0:
        stock_status = "onbackorder"  # Negative stock = on order (WooCommerce API uses "onbackorder")
        stock_qty = 0  # Display as 0, but status shows "On Order"
    else:
        stock_status = "outofstock"
    
    # Determine WooCommerce publish status based on ACTIVE flag
    # ACTIVE = 1 means IS_ECOMM_ITEM = 'Y' (e-commerce active)
    woo_status = "publish" if product.get("ACTIVE", 1) == 1 else "draft"
    
    # Build base payload
    payload = {
        "sku": product["SKU"],
        "name": name,
        "status": woo_status,
        "short_description": short_desc,
        "description": long_desc,
        "manage_stock": True,
        "stock_quantity": stock_qty,
        "stock_status": stock_status,
    }
    
    # ============================================
    # PRICING
    # ============================================
    price = product.get("PRICE")  # PRC_1 (WPC PRICE)
    msrp = product.get("MSRP")    # REG_PRC
    if price is not None:
        try:
            payload["regular_price"] = str(float(price))
        except (ValueError, TypeError):
            pass
    
    # Sale price logic (if on special)
    if product.get("ECOMM_ON_SPECIAL") == 'Y' and price:
        # Could implement sale price logic here if needed
        pass
    
    # ============================================
    # IMAGES
    # ============================================
    # Handle images - only add if image file exists and base URL is configured
    # Products without images will sync successfully (images array will be empty or omitted)
    image_file = product.get("IMAGE_FILE")  # ECOMM_IMG_FILE from CounterPoint
    if image_file and str(image_file).strip() and config and config.image_base_url:
        # Build full image URL: base_url + filename
        image_url = f"{config.image_base_url}/{image_file.strip()}"
        payload["images"] = [{"src": image_url, "alt": name}]
    # Note: If image_file is None, empty, or IMAGE_BASE_URL not configured,
    # product will sync without images (no error - this is expected behavior)
    
    # ============================================
    # WEIGHT & DIMENSIONS
    # ============================================
    weight = product.get("WEIGHT")
    if weight is not None:
        try:
            payload["weight"] = str(float(weight))
        except (ValueError, TypeError):
            pass
    
    # Dimensions (if available - may need custom field mapping)
    # Note: PKG_LENGTH, PKG_WIDTH, PKG_HEIGHT may be in custom fields
    # These would need to be added to the view if available
    
    # ============================================
    # TAX SETTINGS
    # ============================================
    taxable = product.get("TAXABLE")
    if taxable:
        payload["tax_status"] = "taxable" if taxable == 'Y' else "none"
    
    tax_code = product.get("TAX_CODE")
    if tax_code:
        payload["tax_class"] = str(tax_code)
    
    # ============================================
    # E-COMMERCE FLAGS
    # ============================================
    if product.get("ECOMM_NEW") == 'Y':
        payload["featured"] = True
    
    if product.get("ECOMM_ON_SPECIAL") == 'Y':
        payload["on_sale"] = True
        # Sale end date
        special_until = product.get("ECOMM_SPECIAL_UNTIL")
        if special_until:
            try:
                # Convert date to ISO format
                if isinstance(special_until, str):
                    payload["date_on_sale_to"] = special_until
                # Add date parsing if needed
            except Exception as e:
                # Silently skip date parsing errors - not critical
                pass
    
    # ============================================
    # CATEGORY
    # ============================================
    if category_id:
        payload["categories"] = [{"id": category_id}]
    
    # ============================================
    # META DATA (Additional CP fields)
    # ============================================
    meta_data = []
    
    # MSRP (if different from regular price)
    if msrp and msrp != price:
        meta_data.append({"key": "_msrp", "value": str(msrp)})
    
    # Cost (internal)
    cost = product.get("COST")
    if cost:
        meta_data.append({"key": "_cp_cost", "value": str(cost)})
    
    # Barcode
    barcode = product.get("BARCODE")
    if barcode:
        meta_data.append({"key": "_barcode", "value": str(barcode)})
    
    # Vendor information
    vendor_no = product.get("VENDOR_NO")
    if vendor_no:
        meta_data.append({"key": "_vendor_no", "value": str(vendor_no)})
    
    vendor_item_no = product.get("VENDOR_ITEM_NO")
    if vendor_item_no:
        meta_data.append({"key": "_vendor_item_no", "value": str(vendor_item_no)})
    
    # CP Status
    cp_status = product.get("CP_STATUS")
    if cp_status:
        meta_data.append({"key": "_cp_status", "value": str(cp_status)})
    
    # Sub-category
    sub_category = product.get("SUB_CATEGORY_CODE")
    if sub_category:
        meta_data.append({"key": "_sub_category", "value": str(sub_category)})
    
    # Stocking unit
    stocking_unit = product.get("STOCKING_UNIT")
    if stocking_unit:
        meta_data.append({"key": "_stocking_unit", "value": str(stocking_unit)})
    
    # Discountable flag
    discountable = product.get("DISCOUNTABLE")
    if discountable:
        meta_data.append({"key": "_discountable", "value": str(discountable)})
    
    # Add meta_data if we have any
    if meta_data:
        payload["meta_data"] = meta_data
    
    # ============================================
    # URL/SLUG (if available)
    # ============================================
    url = product.get("URL")
    if url:
        # WooCommerce uses 'slug' field, but URL from CP might be full path
        # Extract slug from URL if it's a path
        if '/' in url:
            slug = url.split('/')[-1]
        else:
            slug = url
        payload["slug"] = slug
    
    return payload


# ---------- Mapping & logging ----------

def get_product_map(conn) -> Dict[str, int]:
    """Get existing product mappings (SKU -> WooCommerce product ID)."""
    sql = "SELECT SKU, WOO_PRODUCT_ID FROM dbo.USER_PRODUCT_MAP WHERE IS_ACTIVE = 1;"
    cur = conn.cursor()
    cur.execute(sql)
    return {row[0]: row[1] for row in cur.fetchall()}


def upsert_product_map(conn, sku: str, woo_id: int, user: str = "SYSTEM"):
    """Update or insert product mapping."""
    sql = """
        MERGE dbo.USER_PRODUCT_MAP AS t
        USING (SELECT ? AS SKU, ? AS WOO_PRODUCT_ID) AS s
        ON t.SKU = s.SKU
        WHEN MATCHED THEN
            UPDATE SET WOO_PRODUCT_ID = s.WOO_PRODUCT_ID, UPDATED_DT = SYSDATETIME(), UPDATED_BY = ?
        WHEN NOT MATCHED THEN
            INSERT (SKU, WOO_PRODUCT_ID, IS_ACTIVE, CREATED_DT, CREATED_BY)
            VALUES (s.SKU, s.WOO_PRODUCT_ID, 1, SYSDATETIME(), ?);
    """
    cur = conn.cursor()
    cur.execute(sql, (sku, woo_id, user, user))
    conn.commit()


def log_sync(conn, batch_id: str, op_type: str, dry_run: bool, started: dt.datetime,
             records_input: int, records_created: int, records_updated: int, 
             records_failed: int, error_message: Optional[str] = None):
    """Log sync operation to USER_SYNC_LOG."""
    sql = """
        INSERT INTO dbo.USER_SYNC_LOG
        (SYNC_ID, OPERATION_TYPE, DIRECTION, DRY_RUN, START_TIME, END_TIME, DURATION_SECONDS,
         RECORDS_INPUT, RECORDS_CREATED, RECORDS_UPDATED, RECORDS_FAILED, SUCCESS, ERROR_MESSAGE, CREATED_DT, CREATED_BY)
        VALUES (?, ?, 'CP_TO_WOO', ?, ?, SYSDATETIME(),
                DATEDIFF(SECOND, ?, SYSDATETIME()),
                ?, ?, ?, ?, ?, ?, SYSDATETIME(), SYSTEM_USER);
    """
    cur = conn.cursor()
    cur.execute(sql, (
        batch_id, op_type, dry_run,
        started, started,
        records_input, records_created, records_updated, records_failed,
        1 if not error_message else 0,
        error_message
    ))
    conn.commit()


# ---------- Runner ----------

def get_last_sync_time(conn) -> Optional[dt.datetime]:
    """Get the timestamp of the last successful product sync."""
    sql = """
        SELECT TOP 1 END_TIME
        FROM dbo.USER_SYNC_LOG
        WHERE OPERATION_TYPE = 'product_sync'
          AND SUCCESS = 1
          AND DRY_RUN = 0
        ORDER BY END_TIME DESC;
    """
    cur = conn.cursor()
    cur.execute(sql)
    row = cur.fetchone()
    return row[0] if row else None


def main():
    parser = argparse.ArgumentParser(description="Sync products from CounterPoint to WooCommerce")
    parser.add_argument("sync", nargs="?", const=True, help="Sync products")
    parser.add_argument("--apply", action="store_true", help="Actually sync (default is dry-run)")
    parser.add_argument("--max", type=int, default=None, help="Maximum number of products to sync")
    parser.add_argument("--sku", type=str, default=None, help="Sync specific SKU only")
    parser.add_argument("--batch-id", type=str, default=None, help="Optional batch ID")
    parser.add_argument("--updated-since", type=str, default=None, 
                       help="Only sync products updated since this time (ISO format or 'Xh'/'Xd' for hours/days ago, or 'last' for last sync)")
    parser.add_argument("--full", action="store_true", help="Force full sync (ignore incremental)")
    args = parser.parse_args()

    dry_run = not args.apply
    config = load_integration_config()
    woo_client = WooClient(config)
    
    batch_id = args.batch_id or f"PROD_SYNC_{dt.datetime.now().strftime('%Y%m%d_%H%M%S')}"
    started = dt.datetime.now()
    
    print("=" * 60)
    print(f"{'DRY RUN - ' if dry_run else ''}Product Sync: CounterPoint -> WooCommerce")
    print("=" * 60)
    print(f"Batch ID: {batch_id}")
    print(f"Started: {started.strftime('%Y-%m-%d %H:%M:%S')}")
    print()

    try:
        with connection_ctx() as conn:
            # Determine incremental sync time
            updated_since = None
            if not args.full:
                if args.updated_since:
                    last_sync = get_last_sync_time(conn)
                    updated_since = parse_updated_since(args.updated_since, last_sync)
                    if updated_since:
                        print(f"Incremental sync: Only products updated since {updated_since.strftime('%Y-%m-%d %H:%M:%S')}")
                elif args.sku is None and args.max is None:
                    # Auto-incremental: use last sync time if available
                    last_sync = get_last_sync_time(conn)
                    if last_sync:
                        updated_since = last_sync
                        print(f"Auto-incremental sync: Using last sync time ({updated_since.strftime('%Y-%m-%d %H:%M:%S')})")
                        print("  (Use --full to force full sync)")
            
            # Fetch products
            products = fetch_products(conn, max_records=args.max, sku_filter=args.sku, updated_since=updated_since)
            print(f"Found {len(products)} product(s) to sync")
            
            if not products:
                print("No products found. Exiting.")
                return
            
            # Get existing mappings
            product_map = get_product_map(conn)
            print(f"Found {len(product_map)} existing product mapping(s)")
            print()
            
            # Prepare products for WooCommerce
            woo_products = []
            for cp_product in products:
                sku = cp_product['SKU']
                existing_woo_id = product_map.get(sku)
                
                # Get category mapping
                category_id = get_category_mapping(conn, cp_product.get('CATEGORY_CODE'))
                
                # Prepare payload (pass config for image_base_url)
                payload = prepare_product_payload(cp_product, category_id, config)
                
                # Add ID if updating
                if existing_woo_id:
                    payload['id'] = existing_woo_id
                
                woo_products.append(payload)
            
            # Sync using WooClient batch API
            if dry_run:
                print("DRY RUN - Would sync the following products:")
                for p in woo_products[:10]:  # Show first 10
                    action = "UPDATE" if 'id' in p else "CREATE"
                    print(f"  {action}: {p['sku']} - {p['name'][:50]}")
                if len(woo_products) > 10:
                    print(f"  ... and {len(woo_products) - 10} more")
                print()
                created = sum(1 for p in woo_products if 'id' not in p)
                updated = sum(1 for p in woo_products if 'id' in p)
                failed = 0
            else:
                print("Syncing products to WooCommerce...")
                print(f"  Products to sync: {len(woo_products)}")
                # Use WooClient batch sync
                try:
                    created, updated, errors = woo_client.sync_products(woo_products, dry_run=False)
                    failed = len(errors)
                    print(f"  Sync complete: {created} created, {updated} updated, {failed} failed")
                    
                    if errors:
                        print(f"\nErrors occurred: {len(errors)}")
                        for error in errors[:5]:  # Show first 5 errors
                            print(f"  - {error}")
                        
                        # Check for 503 errors specifically
                        if any("503" in str(e) for e in errors):
                            print("\nWARNING: WooCommerce site returned 503 Service Unavailable")
                            print("   This is a server-side issue. Please:")
                            print("   1. Check if https://woodyspaper.com is accessible")
                            print("   2. Wait a few minutes and retry")
                            print("   3. Check WooCommerce server status")
                except Exception as e:
                    print(f"\nERROR: Fatal error during sync: {e}")
                    created = updated = 0
                    failed = len(woo_products)
                    errors = [str(e)]
                
                # Update product mappings for ALL synced products
                # Fetch product IDs from WooCommerce for all synced SKUs
                if created > 0 or updated > 0:
                    all_skus = [cp_product['SKU'] for cp_product in products]
                    print(f"  Fetching product IDs from WooCommerce for {len(all_skus)} product(s)...")
                    
                    # Retry logic for fetching product IDs (site can be slow)
                    woo_product_ids = {}
                    max_retries = 3
                    for attempt in range(1, max_retries + 1):
                        try:
                            woo_product_ids = woo_client._get_existing_products(all_skus)
                            break  # Success, exit retry loop
                        except Exception as e:
                            if attempt < max_retries:
                                wait_time = attempt * 2  # 2, 4, 6 seconds
                                print(f"  Attempt {attempt} failed, retrying in {wait_time} seconds... ({e})")
                                import time
                                time.sleep(wait_time)
                            else:
                                print(f"  WARNING: Could not fetch product IDs after {max_retries} attempts: {e}")
                                print("  Product sync completed, but mappings may be missing.")
                    
                    # Update mappings for all products found
                    if woo_product_ids:
                        for sku, woo_id in woo_product_ids.items():
                            upsert_product_map(conn, sku, woo_id, "woo_products.py")
                            print(f"  Mapped {sku} -> WooCommerce product ID {woo_id}")
                        
                        if len(woo_product_ids) < len(all_skus):
                            missing = set(all_skus) - set(woo_product_ids.keys())
                            print(f"  WARNING: Could not find WooCommerce IDs for: {', '.join(missing)}")
                    
                    # Fallback: Use existing mappings if available
                    if not woo_product_ids:
                        for cp_product in products:
                            sku = cp_product['SKU']
                            if sku in product_map:
                                upsert_product_map(conn, sku, product_map[sku], "woo_products.py")
                                print(f"  Used existing mapping for {sku}")
            
            # Log sync
            log_sync(conn, batch_id, "product_sync", dry_run, started, 
                    len(products), created, updated, failed,
                    None if failed == 0 else f"{failed} products failed")
            
            print()
            print("=" * 60)
            print("Sync Summary:")
            print(f"  Input: {len(products)}")
            print(f"  Created: {created}")
            print(f"  Updated: {updated}")
            print(f"  Failed: {failed}")
            print(f"  Batch ID: {batch_id}")
            print("=" * 60)
            
    except Exception as ex:
        print(f"ERROR: {ex}")
        import traceback
        traceback.print_exc()
        try:
            with connection_ctx() as conn:
                log_sync(conn, batch_id, "product_sync", dry_run, started, 
                        0, 0, 0, 0, str(ex))
        except Exception as log_error:
            # If logging fails, at least print to console
            print(f"WARNING: Failed to log sync error: {log_error}")
        sys.exit(1)


if __name__ == "__main__":
    main()


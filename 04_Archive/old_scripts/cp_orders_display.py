"""
cp_orders_display.py - Display CounterPoint orders on retail site

Handles:
  - Query CounterPoint orders for display
  - Format orders with proper units of measurement
  - Filter by date, customer, status, unit type
  - Group orders by unit type if needed

Usage:
    from cp_orders_display import get_cp_orders, get_orders_by_unit
    
    orders = get_cp_orders(date_from='2025-01-01', date_to='2025-12-31')
    pallet_orders = get_orders_by_unit('PL')
"""

import logging
from typing import List, Dict, Optional
from datetime import datetime, timedelta
from database import get_connection, connection_ctx

logger = logging.getLogger(__name__)


def get_cp_orders(
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    customer_no: Optional[str] = None,
    status: Optional[str] = None,
    unit_code: Optional[str] = None,
    limit: int = 100
) -> List[Dict]:
    """
    Get CounterPoint orders for display on retail site.
    
    Args:
        date_from: Start date (YYYY-MM-DD), defaults to 30 days ago
        date_to: End date (YYYY-MM-DD), defaults to today
        customer_no: Filter by customer number (optional)
        status: Filter by order status (A=Active, C=Closed, etc.) (optional)
        unit_code: Filter by unit code (EA, PK, BX, CT, PL, etc.) (optional)
        limit: Maximum number of orders to return (default: 100)
    
    Returns:
        List of order dictionaries with line items and units
    """
    # Default date range: last 30 days
    if not date_from:
        date_from = (datetime.now() - timedelta(days=30)).strftime('%Y-%m-%d')
    if not date_to:
        date_to = datetime.now().strftime('%Y-%m-%d')
    
    try:
        with connection_ctx() as conn:
            cur = conn.cursor()
            
            query = """
                SELECT 
                    ORDER_NUMBER,
                    ORDER_TYPE,
                    ORDER_DATE,
                    ORDER_TIME,
                    CUSTOMER_NUMBER,
                    CUSTOMER_NAME,
                    ORDER_STATUS,
                    SHIP_NAME,
                    SHIP_ADDRESS_1,
                    SHIP_ADDRESS_2,
                    SHIP_CITY,
                    SHIP_STATE,
                    SHIP_ZIP,
                    SHIP_COUNTRY,
                    SHIP_VIA,
                    LINE_SEQUENCE,
                    SKU,
                    ITEM_DESCRIPTION,
                    ITEM_SHORT_DESCRIPTION,
                    QUANTITY_ORDERED,
                    SELLING_UNIT,
                    UNIT_DISPLAY_NAME,
                    STOCKING_UNIT,
                    STOCKING_UNIT_DISPLAY,
                    UNIT_PRICE,
                    LINE_TOTAL,
                    LINE_DISCOUNT,
                    ORDER_SUBTOTAL,
                    ORDER_DISCOUNT,
                    ORDER_TAX,
                    ORDER_SHIPPING,
                    ORDER_TOTAL,
                    PAYMENT_CODE,
                    PAYMENT_METHOD,
                    PAYMENT_AMOUNT,
                    TRACKING_NUMBER,
                    ORDER_NOTE,
                    CUSTOMER_PO_NUMBER,
                    SALES_REP,
                    CREATED_BY_USER,
                    LAST_MODIFIED_DATE,
                    POSTED_DATE
                FROM dbo.VI_EXPORT_CP_ORDERS
                WHERE ORDER_DATE >= ? AND ORDER_DATE <= ?
            """
            
            params = [date_from, date_to]
            
            if customer_no:
                query += " AND CUSTOMER_NUMBER = ?"
                params.append(customer_no)
            
            if status:
                query += " AND ORDER_STATUS = ?"
                params.append(status)
            
            if unit_code:
                query += " AND SELLING_UNIT = ?"
                params.append(unit_code)
            
            query += " ORDER BY ORDER_DATE DESC, ORDER_NUMBER, LINE_SEQUENCE"
            query += f" OFFSET 0 ROWS FETCH NEXT {limit} ROWS ONLY"
            
            cur.execute(query, params)
            rows = cur.fetchall()
            
            # Group line items by order
            orders = {}
            for row in rows:
                order_num = row[0]
                
                if order_num not in orders:
                    orders[order_num] = {
                        'order_number': order_num,
                        'order_type': row[1],
                        'order_date': row[2].strftime('%Y-%m-%d') if row[2] else None,
                        'order_time': str(row[3]) if row[3] else None,
                        'customer_number': row[4],
                        'customer_name': row[5],
                        'order_status': row[6],
                        'shipping': {
                            'name': row[7],
                            'address_1': row[8],
                            'address_2': row[9],
                            'city': row[10],
                            'state': row[11],
                            'zip': row[12],
                            'country': row[13],
                            'ship_via': row[14]
                        },
                        'totals': {
                            'subtotal': float(row[27]) if row[27] else 0,
                            'discount': float(row[28]) if row[28] else 0,
                            'tax': float(row[29]) if row[29] else 0,
                            'shipping': float(row[30]) if row[30] else 0,
                            'total': float(row[31]) if row[31] else 0
                        },
                        'payment': {
                            'code': row[32],
                            'method': row[33],
                            'amount': float(row[34]) if row[34] else 0
                        },
                        'tracking_number': row[35],
                        'order_note': row[36],
                        'customer_po_number': row[37],
                        'sales_rep': row[38],
                        'line_items': []
                    }
                
                # Add line item
                orders[order_num]['line_items'].append({
                    'line_sequence': row[15],
                    'sku': row[16],
                    'item_description': row[17],
                    'item_short_description': row[18],
                    'quantity': float(row[19]) if row[19] else 0,
                    'selling_unit': row[20],
                    'unit_display_name': row[21],
                    'stocking_unit': row[22],
                    'stocking_unit_display': row[23],
                    'unit_price': float(row[24]) if row[24] else 0,
                    'line_total': float(row[25]) if row[25] else 0,
                    'line_discount': float(row[26]) if row[26] else 0
                })
            
            return list(orders.values())
            
    except Exception as e:
        logger.error(f"Error getting CP orders: {e}", exc_info=True)
        return []


def get_orders_by_unit(unit_code: str, days: int = 30) -> List[Dict]:
    """
    Get orders filtered by unit code.
    
    Args:
        unit_code: Unit code (EA, PK, BX, CT, PL, etc.)
        days: Number of days to look back (default: 30)
    
    Returns:
        List of orders with line items matching the unit
    """
    date_from = (datetime.now() - timedelta(days=days)).strftime('%Y-%m-%d')
    date_to = datetime.now().strftime('%Y-%m-%d')
    
    return get_cp_orders(
        date_from=date_from,
        date_to=date_to,
        unit_code=unit_code
    )


def get_orders_summary_by_unit(days: int = 30) -> List[Dict]:
    """
    Get summary of orders grouped by unit type.
    
    Args:
        days: Number of days to look back (default: 30)
    
    Returns:
        List of summaries: unit, order_count, total_quantity, total_amount
    """
    date_from = (datetime.now() - timedelta(days=days)).strftime('%Y-%m-%d')
    date_to = datetime.now().strftime('%Y-%m-%d')
    
    try:
        with connection_ctx() as conn:
            cur = conn.cursor()
            
            query = """
                SELECT 
                    UNIT_DISPLAY_NAME,
                    SELLING_UNIT,
                    COUNT(DISTINCT ORDER_NUMBER) AS ORDER_COUNT,
                    SUM(QUANTITY_ORDERED) AS TOTAL_QUANTITY,
                    SUM(LINE_TOTAL) AS TOTAL_AMOUNT,
                    COUNT(*) AS LINE_ITEM_COUNT
                FROM dbo.VI_EXPORT_CP_ORDERS
                WHERE ORDER_DATE >= ? AND ORDER_DATE <= ?
                GROUP BY UNIT_DISPLAY_NAME, SELLING_UNIT
                ORDER BY 
                    CASE UNIT_DISPLAY_NAME
                        WHEN 'Each' THEN 1
                        WHEN 'Pack' THEN 2
                        WHEN 'Box' THEN 3
                        WHEN 'Carton' THEN 4
                        WHEN 'Case' THEN 5
                        WHEN 'Pallet' THEN 6
                        ELSE 99
                    END,
                    UNIT_DISPLAY_NAME
            """
            
            cur.execute(query, (date_from, date_to))
            rows = cur.fetchall()
            
            return [
                {
                    'unit_display_name': row[0],
                    'unit_code': row[1],
                    'order_count': row[2],
                    'total_quantity': float(row[3]) if row[3] else 0,
                    'total_amount': float(row[4]) if row[4] else 0,
                    'line_item_count': row[5]
                }
                for row in rows
            ]
            
    except Exception as e:
        logger.error(f"Error getting orders summary by unit: {e}", exc_info=True)
        return []


def format_order_for_display(order: Dict) -> str:
    """
    Format order data for display on website.
    
    Args:
        order: Order dictionary from get_cp_orders()
    
    Returns:
        Formatted HTML string
    """
    lines = []
    lines.append(f"<div class='cp-order'>")
    lines.append(f"<h3>Order #{order['order_number']}</h3>")
    lines.append(f"<p><strong>Date:</strong> {order['order_date']}</p>")
    lines.append(f"<p><strong>Customer:</strong> {order['customer_name']}</p>")
    
    lines.append("<table class='cp-order-items'>")
    lines.append("<thead><tr><th>Item</th><th>Quantity</th><th>Unit</th><th>Price</th><th>Total</th></tr></thead>")
    lines.append("<tbody>")
    
    for item in order['line_items']:
        lines.append(f"<tr>")
        lines.append(f"<td>{item['item_description']} ({item['sku']})</td>")
        lines.append(f"<td>{item['quantity']}</td>")
        lines.append(f"<td>{item['unit_display_name']}</td>")
        lines.append(f"<td>${item['unit_price']:.2f}</td>")
        lines.append(f"<td>${item['line_total']:.2f}</td>")
        lines.append(f"</tr>")
    
    lines.append("</tbody>")
    lines.append("</table>")
    
    lines.append(f"<p><strong>Order Total:</strong> ${order['totals']['total']:.2f}</p>")
    lines.append("</div>")
    
    return "\n".join(lines)


if __name__ == '__main__':
    # Test the functions
    print("Testing CP Orders Display...")
    
    # Get recent orders
    orders = get_cp_orders(limit=10)
    print(f"\nFound {len(orders)} orders")
    
    # Get orders by unit
    pallet_orders = get_orders_by_unit('PL', days=30)
    print(f"\nFound {len(pallet_orders)} orders with Pallet units")
    
    # Get summary by unit
    summary = get_orders_summary_by_unit(days=30)
    print(f"\nOrders Summary by Unit:")
    for s in summary:
        print(f"  {s['unit_display_name']}: {s['order_count']} orders, {s['total_quantity']} units, ${s['total_amount']:.2f}")


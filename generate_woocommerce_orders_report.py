"""Generate detailed report for WooCommerce orders in CounterPoint
Shows all the detail that appears in WooCommerce for unpicked/open orders
"""
from database import run_query
from datetime import datetime
import sys

def generate_orders_report(ticket_numbers=None):
    """
    Generate comprehensive report for WooCommerce orders.
    
    Args:
        ticket_numbers: List of ticket numbers to filter (e.g., ['101-000004', '101-000005'])
                        If None, shows all WooCommerce orders
    """
    print("="*100)
    print("WOOCOMMERCE ORDERS DETAILED REPORT - COUNTERPOINT")
    print("="*100)
    print(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    # Build query
    if ticket_numbers:
        ticket_filter = "AND h.TKT_NO IN (" + ",".join([f"'{t}'" for t in ticket_numbers]) + ")"
    else:
        ticket_filter = ""
    
    # Get order headers with all detail
    sql = f"""
    SELECT 
        -- Order Identification
        h.TKT_NO AS TicketNumber,
        s.WOO_ORDER_ID AS WooCommerceOrderID,
        s.WOO_ORDER_NO AS WooCommerceOrderNumber,
        
        -- Order Dates
        h.TKT_DT AS OrderDate,
        h.SHIP_DAT AS ShipDate,
        
        -- Order Status
        CASE 
            WHEN h.SHIP_DAT IS NOT NULL THEN 'Shipped'
            WHEN h.RS_STAT = 0 THEN 'Open'
            WHEN h.RS_STAT = 1 THEN 'Closed'
            ELSE 'Unknown'
        END AS OrderStatus,
        
        -- Customer Information
        h.CUST_NO AS CustomerNumber,
        c.NAM AS CustomerName,
        c.EMAIL_ADRS_1 AS CustomerEmail,
        c.PHONE_1 AS CustomerPhone,
        
        -- Shipping Information
        ship.NAM AS ShipToName,
        ship.ADRS_1 AS ShipToAddress1,
        ship.ADRS_2 AS ShipToAddress2,
        ship.CITY AS ShipToCity,
        ship.STATE AS ShipToState,
        ship.ZIP_COD AS ShipToZip,
        ship.PHONE_1 AS ShipToPhone,
        
        -- Shipping Method
        h.SHIP_VIA_COD AS ShippingMethod,
        
        -- Financial Totals (from PS_DOC_HDR_TOT)
        t.SUB_TOT AS Subtotal,
        t.TAX_AMT AS TaxAmount,
        t.TOT AS TotalAmount,
        t.TOT_HDR_DISC AS HeaderDiscount,
        t.TOT_LIN_DISC AS LineDiscount,
        t.TOT_MISC AS ShippingAmount,
        t.AMT_DUE AS AmountDue,
        
        -- Payment Information (from staging)
        s.PMT_METH AS PaymentMethod,
        s.ORD_STATUS AS WooCommerceStatus
        
    FROM dbo.PS_DOC_HDR h
    INNER JOIN dbo.USER_ORDER_STAGING s ON CAST(s.CP_DOC_ID AS BIGINT) = h.DOC_ID
    LEFT JOIN dbo.AR_CUST c ON h.CUST_NO = c.CUST_NO
    LEFT JOIN dbo.PS_DOC_HDR_TOT t ON h.DOC_ID = t.DOC_ID AND t.TOT_TYP = 'S'
    LEFT JOIN dbo.AR_SHIP_ADRS ship ON ship.CUST_NO = h.CUST_NO 
        AND ship.SHIP_ADRS_ID = CAST(h.SHIP_TO_CONTACT_ID AS VARCHAR(10))
    WHERE s.SOURCE_SYSTEM = 'WOOCOMMERCE'
      {ticket_filter}
    ORDER BY h.TKT_DT DESC, h.TKT_NO
    """
    
    orders = run_query(sql)
    
    if not orders:
        print("[INFO] No WooCommerce orders found")
        return
    
    print(f"Found {len(orders)} WooCommerce order(s)\n")
    
    for order in orders:
        print("="*100)
        print(f"ORDER: {order['TicketNumber']} | WooCommerce: #{order['WooCommerceOrderID']}")
        print("="*100)
        
        # Order Information
        print(f"\nORDER INFORMATION:")
        print(f"  Ticket Number: {order['TicketNumber']}")
        print(f"  WooCommerce Order: #{order['WooCommerceOrderID']} ({order['WooCommerceOrderNumber'] or 'N/A'})")
        print(f"  Order Date: {order['OrderDate']}")
        print(f"  Ship Date: {order['ShipDate'] or 'Not Shipped Yet'}")
        print(f"  Order Status: {order['OrderStatus']}")
        print(f"  WooCommerce Status: {order['WooCommerceStatus']}")
        
        # Customer Information
        print(f"\nCUSTOMER INFORMATION:")
        print(f"  Customer Number: {order['CustomerNumber']}")
        print(f"  Customer Name: {order['CustomerName']}")
        print(f"  Email: {order['CustomerEmail'] or 'N/A'}")
        print(f"  Phone: {order['CustomerPhone'] or 'N/A'}")
        
        # Shipping Information
        print(f"\nSHIPPING INFORMATION:")
        if order['ShipToName']:
            print(f"  Ship To: {order['ShipToName']}")
            print(f"  Address: {order['ShipToAddress1'] or ''}")
            if order['ShipToAddress2']:
                print(f"            {order['ShipToAddress2']}")
            print(f"  City, State ZIP: {order['ShipToCity'] or ''}, {order['ShipToState'] or ''} {order['ShipToZip'] or ''}")
            if order['ShipToPhone']:
                print(f"  Phone: {order['ShipToPhone']}")
        else:
            print(f"  [No shipping address linked]")
        print(f"  Shipping Method: {order['ShippingMethod'] or 'N/A'}")
        
        # Financial Information
        print(f"\nFINANCIAL INFORMATION:")
        print(f"  Subtotal: ${order['Subtotal']:.2f}" if order['Subtotal'] else "  Subtotal: $0.00")
        print(f"  Tax Amount: ${order['TaxAmount']:.2f}" if order['TaxAmount'] else "  Tax Amount: $0.00")
        print(f"  Shipping: ${order['ShippingAmount']:.2f}" if order['ShippingAmount'] else "  Shipping: $0.00")
        if order['HeaderDiscount'] and order['HeaderDiscount'] > 0:
            print(f"  Header Discount: ${order['HeaderDiscount']:.2f}")
        if order['LineDiscount'] and order['LineDiscount'] > 0:
            print(f"  Line Discount: ${order['LineDiscount']:.2f}")
        print(f"  TOTAL: ${order['TotalAmount']:.2f}" if order['TotalAmount'] else "  TOTAL: $0.00")
        print(f"  Amount Due: ${order['AmountDue']:.2f}" if order['AmountDue'] else "  Amount Due: $0.00")
        
        # Payment Information
        print(f"\nPAYMENT INFORMATION:")
        print(f"  Payment Method: {order['PaymentMethod'] or 'N/A'}")
        print(f"  Payment Status: {'Paid' if order['WooCommerceStatus'] in ('processing', 'completed') else 'Unknown'}")
        print(f"  Note: Payment processed on WooCommerce side (not shown in CounterPoint)")
        
        # Line Items
        print(f"\nLINE ITEMS:")
        line_sql = """
        SELECT 
            l.LIN_SEQ_NO,
            l.ITEM_NO,
            l.DESCR,
            l.QTY_SOLD,
            l.PRC,
            l.EXT_PRC
        FROM dbo.PS_DOC_HDR h
        INNER JOIN dbo.PS_DOC_LIN l ON h.DOC_ID = l.DOC_ID
        WHERE h.TKT_NO = ?
        ORDER BY l.LIN_SEQ_NO
        """
        lines = run_query(line_sql, (order['TicketNumber'],))
        
        if lines:
            for line in lines:
                print(f"  Line {line['LIN_SEQ_NO']}: {line['ITEM_NO']}")
                print(f"    Description: {line['DESCR'][:60]}")
                print(f"    Quantity: {line['QTY_SOLD']} @ ${line['PRC']:.2f} = ${line['EXT_PRC']:.2f}")
        else:
            print(f"  [No line items found]")
        
        print()
    
    print("="*100)
    print("REPORT COMPLETE")
    print("="*100)

if __name__ == "__main__":
    # Check for command line arguments
    if len(sys.argv) > 1:
        # Filter by ticket numbers
        ticket_numbers = sys.argv[1:]
        generate_orders_report(ticket_numbers)
    else:
        # Show all WooCommerce orders
        generate_orders_report()

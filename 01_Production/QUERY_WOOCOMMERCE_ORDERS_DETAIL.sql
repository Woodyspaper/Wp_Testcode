-- ============================================
-- Query WooCommerce Orders with Complete Detail
-- ============================================
-- Use this query to see all detail for WordPress/WooCommerce orders
-- Shows the same level of detail as WooCommerce for unpicked/open orders
-- ============================================

-- Option 1: Use the view (if created)
SELECT * 
FROM dbo.VI_WOOCOMMERCE_ORDERS_DETAIL
WHERE TicketNumber IN ('101-000004', '101-000005')
ORDER BY OrderDate DESC
GO

-- Option 2: Direct query with all fields
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
  AND h.TKT_NO IN ('101-000004', '101-000005')
ORDER BY h.TKT_DT DESC, h.TKT_NO
GO

-- Option 3: Get line items detail
SELECT 
    h.TKT_NO AS TicketNumber,
    s.WOO_ORDER_ID AS WooCommerceOrderID,
    l.LIN_SEQ_NO AS LineSequence,
    l.ITEM_NO AS ItemNumber,
    l.DESCR AS ItemDescription,
    l.QTY_SOLD AS Quantity,
    l.PRC AS UnitPrice,
    l.EXT_PRC AS ExtendedPrice
FROM dbo.PS_DOC_HDR h
INNER JOIN dbo.USER_ORDER_STAGING s ON CAST(s.CP_DOC_ID AS BIGINT) = h.DOC_ID
INNER JOIN dbo.PS_DOC_LIN l ON h.DOC_ID = l.DOC_ID
WHERE s.SOURCE_SYSTEM = 'WOOCOMMERCE'
  AND h.TKT_NO IN ('101-000004', '101-000005')
ORDER BY h.TKT_NO, l.LIN_SEQ_NO
GO

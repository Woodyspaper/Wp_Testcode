-- ============================================
-- WooCommerce Orders Detail View
-- ============================================
-- Purpose: Show complete detail for WordPress/WooCommerce orders in CounterPoint
-- Includes all financial totals, line items, customer info, and shipping info
-- This view provides the same level of detail as WooCommerce for unpicked orders
-- ============================================

IF EXISTS (SELECT * FROM sys.views WHERE name = 'VI_WOOCOMMERCE_ORDERS_DETAIL')
    DROP VIEW dbo.VI_WOOCOMMERCE_ORDERS_DETAIL;
GO

CREATE VIEW dbo.VI_WOOCOMMERCE_ORDERS_DETAIL
AS
SELECT 
    -- Order Identification
    h.DOC_ID,
    h.TKT_NO AS TicketNumber,
    s.WOO_ORDER_ID AS WooCommerceOrderID,
    s.WOO_ORDER_NO AS WooCommerceOrderNumber,
    
    -- Order Dates
    h.TKT_DT AS OrderDate,
    h.SHIP_DAT AS ShipDate,
    h.LST_MAINT_DT AS LastModifiedDate,
    
    -- Order Status
    CASE 
        WHEN h.SHIP_DAT IS NOT NULL THEN 'Shipped'
        WHEN h.RS_STAT = 0 THEN 'Open'
        WHEN h.RS_STAT = 1 THEN 'Closed'
        ELSE 'Unknown'
    END AS OrderStatus,
    h.RS_STAT AS DocumentStatus,
    
    -- Customer Information
    h.CUST_NO AS CustomerNumber,
    c.NAM AS CustomerName,
    c.EMAIL_ADRS_1 AS CustomerEmail,
    c.PHONE_1 AS CustomerPhone,
    c.ADRS_1 AS BillingAddress1,
    c.ADRS_2 AS BillingAddress2,
    c.CITY AS BillingCity,
    c.STATE AS BillingState,
    c.ZIP_COD AS BillingZip,
    c.CNTRY AS BillingCountry,
    
    -- Shipping Information
    h.SHIP_TO_CONTACT_ID AS ShipToContactID,
    ship.NAM AS ShipToName,
    ship.ADRS_1 AS ShipToAddress1,
    ship.ADRS_2 AS ShipToAddress2,
    ship.CITY AS ShipToCity,
    ship.STATE AS ShipToState,
    ship.ZIP_COD AS ShipToZip,
    ship.CNTRY AS ShipToCountry,
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
    t.INITIAL_MIN_DUE AS InitialMinDue,
    
    -- Order Summary
    h.ORD_LINS AS OrderLinesCount,
    h.SAL_LINS AS SalesLinesCount,
    h.SAL_LIN_TOT AS SalesLineTotal,
    
    -- Payment Information (from staging - for reference)
    s.PMT_METH AS PaymentMethod,
    s.ORD_STATUS AS WooCommerceStatus,
    
    -- Line Items Summary (aggregated)
    (
        SELECT COUNT(*)
        FROM dbo.PS_DOC_LIN l
        WHERE l.DOC_ID = h.DOC_ID
    ) AS LineItemCount,
    
    (
        SELECT SUM(l.EXT_PRC)
        FROM dbo.PS_DOC_LIN l
        WHERE l.DOC_ID = h.DOC_ID
    ) AS LineItemsTotal,
    
    -- Source System
    s.SOURCE_SYSTEM AS SourceSystem,
    s.CREATED_DT AS StagingCreatedDate,
    s.APPLIED_DT AS AppliedToCounterPointDate
    
FROM dbo.PS_DOC_HDR h
INNER JOIN dbo.USER_ORDER_STAGING s ON CAST(s.CP_DOC_ID AS BIGINT) = h.DOC_ID
LEFT JOIN dbo.AR_CUST c ON h.CUST_NO = c.CUST_NO
LEFT JOIN dbo.PS_DOC_HDR_TOT t ON h.DOC_ID = t.DOC_ID AND t.TOT_TYP = 'S'
LEFT JOIN dbo.AR_SHIP_ADRS ship ON ship.CUST_NO = h.CUST_NO 
    AND ship.SHIP_ADRS_ID = CAST(h.SHIP_TO_CONTACT_ID AS VARCHAR(10))
WHERE s.SOURCE_SYSTEM = 'WOOCOMMERCE'
GO

PRINT 'Created VI_WOOCOMMERCE_ORDERS_DETAIL view';
PRINT 'This view shows complete detail for WordPress/WooCommerce orders';
PRINT 'Use this view in reports to see all financial totals and customer information';
GO

-- ============================================
-- WooCommerce Orders Line Items Detail View
-- ============================================
-- Purpose: Show detailed line items for WooCommerce orders
-- ============================================

IF EXISTS (SELECT * FROM sys.views WHERE name = 'VI_WOOCOMMERCE_ORDERS_LINES')
    DROP VIEW dbo.VI_WOOCOMMERCE_ORDERS_LINES;
GO

CREATE VIEW dbo.VI_WOOCOMMERCE_ORDERS_LINES
AS
SELECT 
    -- Order Identification
    h.DOC_ID,
    h.TKT_NO AS TicketNumber,
    s.WOO_ORDER_ID AS WooCommerceOrderID,
    
    -- Line Item Information
    l.LIN_SEQ_NO AS LineSequence,
    l.ITEM_NO AS ItemNumber,
    l.DESCR AS ItemDescription,
    l.QTY_SOLD AS Quantity,
    l.PRC AS UnitPrice,
    l.EXT_PRC AS ExtendedPrice,
    
    -- Item Details
    i.SHORT_DESCR AS ShortDescription,
    i.STK_UNIT AS StockingUnit,
    l.SELL_UNIT AS SellingUnit,
    
    -- Order Header Info (for grouping)
    h.TKT_DT AS OrderDate,
    h.CUST_NO AS CustomerNumber,
    c.NAM AS CustomerName,
    
    -- Totals (for reference)
    t.SUB_TOT AS OrderSubtotal,
    t.TAX_AMT AS OrderTax,
    t.TOT AS OrderTotal
    
FROM dbo.PS_DOC_HDR h
INNER JOIN dbo.USER_ORDER_STAGING s ON CAST(s.CP_DOC_ID AS BIGINT) = h.DOC_ID
INNER JOIN dbo.PS_DOC_LIN l ON h.DOC_ID = l.DOC_ID
LEFT JOIN dbo.IM_ITEM i ON l.ITEM_NO = i.ITEM_NO
LEFT JOIN dbo.AR_CUST c ON h.CUST_NO = c.CUST_NO
LEFT JOIN dbo.PS_DOC_HDR_TOT t ON h.DOC_ID = t.DOC_ID AND t.TOT_TYP = 'S'
WHERE s.SOURCE_SYSTEM = 'WOOCOMMERCE'
GO

PRINT 'Created VI_WOOCOMMERCE_ORDERS_LINES view';
PRINT 'This view shows detailed line items for WordPress/WooCommerce orders';
GO

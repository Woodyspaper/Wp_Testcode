-- ============================================
-- CounterPoint Orders Export View (CORRECTED)
-- ============================================
-- Based on actual column names discovered from database
-- Purpose: Export orders from CounterPoint for display on retail site
-- Includes units of measurement: each, pack, box, carton, pallet

IF EXISTS (SELECT * FROM sys.views WHERE name = 'VI_EXPORT_CP_ORDERS')
    DROP VIEW dbo.VI_EXPORT_CP_ORDERS;
GO

CREATE VIEW dbo.VI_EXPORT_CP_ORDERS
AS
WITH OrderLinesWithUnits AS (
    SELECT 
        -- Header columns
        h.DOC_ID,
        h.DOC_TYP,
        h.TKT_DT,
        h.CUST_NO,
        h.RS_STAT,
        h.SHIP_VIA_COD,
        h.SHIP_DAT,
        h.SAL_LIN_TOT,
        h.CUST_PO_NO,
        h.SLS_REP,
        h.USR_ID,
        h.LST_MAINT_DT,
        -- Line columns
        l.LIN_SEQ_NO,
        l.ITEM_NO,
        l.QTY_SOLD,
        l.SELL_UNIT,
        l.PRC,
        l.EXT_PRC,
        l.GROSS_EXT_PRC,
        l.DISP_EXT_PRC,
        -- Item columns
        i.DESCR,
        i.SHORT_DESCR,
        i.STK_UNIT,
        i.ALT_1_UNIT,
        i.ALT_2_UNIT,
        i.ALT_3_UNIT,
        i.ALT_4_UNIT,
        i.ALT_5_UNIT,
        -- Customer name
        c.NAM AS CUSTOMER_NAME,
        -- SELL_UNIT is a varchar(1) index ('0'-'5') that maps to unit columns:
        -- '0' = STK_UNIT (stocking unit)
        -- '1' = ALT_1_UNIT
        -- '2' = ALT_2_UNIT
        -- '3' = ALT_3_UNIT
        -- '4' = ALT_4_UNIT
        -- '5' = ALT_5_UNIT
        -- Handle both varchar and numeric, and handle NULLs
        -- Convert SELL_UNIT to INT first, then use it for mapping
        CASE 
            WHEN TRY_CAST(l.SELL_UNIT AS INT) = 0 OR l.SELL_UNIT = '0' THEN COALESCE(NULLIF(i.STK_UNIT, ''), 'EA')
            WHEN TRY_CAST(l.SELL_UNIT AS INT) = 1 OR l.SELL_UNIT = '1' THEN COALESCE(NULLIF(i.ALT_1_UNIT, ''), NULLIF(i.STK_UNIT, ''), 'EA')
            WHEN TRY_CAST(l.SELL_UNIT AS INT) = 2 OR l.SELL_UNIT = '2' THEN COALESCE(NULLIF(i.ALT_2_UNIT, ''), NULLIF(i.STK_UNIT, ''), 'EA')
            WHEN TRY_CAST(l.SELL_UNIT AS INT) = 3 OR l.SELL_UNIT = '3' THEN COALESCE(NULLIF(i.ALT_3_UNIT, ''), NULLIF(i.STK_UNIT, ''), 'EA')
            WHEN TRY_CAST(l.SELL_UNIT AS INT) = 4 OR l.SELL_UNIT = '4' THEN COALESCE(NULLIF(i.ALT_4_UNIT, ''), NULLIF(i.STK_UNIT, ''), 'EA')
            WHEN TRY_CAST(l.SELL_UNIT AS INT) = 5 OR l.SELL_UNIT = '5' THEN COALESCE(NULLIF(i.ALT_5_UNIT, ''), NULLIF(i.STK_UNIT, ''), 'EA')
            WHEN l.SELL_UNIT IS NULL THEN COALESCE(NULLIF(i.STK_UNIT, ''), 'EA')
            ELSE COALESCE(NULLIF(i.STK_UNIT, ''), 'EA')  -- Fallback to stocking unit
        END AS ACTUAL_UNIT_CODE,
        -- Also keep the original SELL_UNIT for debugging
        l.SELL_UNIT AS SELL_UNIT_ORIGINAL
    FROM dbo.PS_DOC_HDR h
    INNER JOIN dbo.PS_DOC_LIN l ON l.DOC_ID = h.DOC_ID
    LEFT JOIN dbo.IM_ITEM i ON i.ITEM_NO = l.ITEM_NO
    LEFT JOIN dbo.AR_CUST c ON c.CUST_NO = h.CUST_NO
    WHERE h.DOC_TYP IN ('T', 'O', 'I', 'Q')  -- Ticket, Order, Invoice, Quote
      AND h.RS_STAT != 2  -- Exclude voided orders (assuming 2 = voided, adjust if needed)
)
SELECT 
    -- Order Header (using actual column names)
    o.DOC_ID AS ORDER_NUMBER,
    o.DOC_TYP AS ORDER_TYPE,
    CAST(o.TKT_DT AS DATE) AS ORDER_DATE,  -- Actual column: TKT_DT
    CAST(o.TKT_DT AS TIME) AS ORDER_TIME,  -- Extract time from TKT_DT
    o.CUST_NO AS CUSTOMER_NUMBER,
    o.CUSTOMER_NAME,
    o.RS_STAT AS ORDER_STATUS,  -- Actual column: RS_STAT (tinyint: 0=Active, 1=Closed, etc.)
    
    -- Shipping Address
    -- Note: Shipping address may be in a contact table (SHIP_TO_CONTACT_ID)
    -- For now, use customer address as fallback
    o.CUSTOMER_NAME AS SHIP_NAME,
    NULL AS SHIP_ADDRESS_1,  -- Need to get from contact table
    NULL AS SHIP_ADDRESS_2,
    NULL AS SHIP_CITY,
    NULL AS SHIP_STATE,
    NULL AS SHIP_ZIP,
    NULL AS SHIP_COUNTRY,
    o.SHIP_VIA_COD AS SHIP_VIA,
    
    -- Line Items
    o.LIN_SEQ_NO AS LINE_SEQUENCE,
    o.ITEM_NO AS SKU,
    o.DESCR AS ITEM_DESCRIPTION,
    o.SHORT_DESCR AS ITEM_SHORT_DESCRIPTION,
    
    -- QUANTITY AND UNITS (CRITICAL - this is what we need!)
    o.QTY_SOLD AS QUANTITY_ORDERED,  -- Actual column: QTY_SOLD
    o.ACTUAL_UNIT_CODE AS SELLING_UNIT,  -- Actual unit code (EA, PK, BX, CT, PL, etc.)
    
    -- Unit mapping: Use IM_UNIT_COD for descriptions, fallback to hardcoded
    COALESCE(u.DESCR, 
        CASE 
            WHEN o.ACTUAL_UNIT_CODE = 'EA' THEN 'Each'
            WHEN o.ACTUAL_UNIT_CODE = 'PK' THEN 'Pack'
            WHEN o.ACTUAL_UNIT_CODE = 'BX' THEN 'Box'
            WHEN o.ACTUAL_UNIT_CODE = 'CT' THEN 'Carton'
            WHEN o.ACTUAL_UNIT_CODE = 'PL' THEN 'Pallet'
            WHEN o.ACTUAL_UNIT_CODE = 'CS' THEN 'Case'
            WHEN o.ACTUAL_UNIT_CODE = 'RL' THEN 'Roll'
            WHEN o.ACTUAL_UNIT_CODE = 'FTL' THEN 'Full Truck Load'
            WHEN o.ACTUAL_UNIT_CODE = 'LTL' THEN 'Less Than Truckload'
            WHEN o.ACTUAL_UNIT_CODE = 'LB' THEN 'Pound'
            WHEN o.ACTUAL_UNIT_CODE = 'TON' THEN 'Ton'
            WHEN o.ACTUAL_UNIT_CODE = 'M' THEN 'Thousand'
            WHEN o.ACTUAL_UNIT_CODE = 'C' THEN 'Hundred'
            ELSE o.ACTUAL_UNIT_CODE  -- Use actual unit code if not mapped
        END
    ) AS UNIT_DISPLAY_NAME,
    
    -- Stocking unit for reference
    o.STK_UNIT AS STOCKING_UNIT,
    COALESCE(u_stk.DESCR,
        CASE 
            WHEN o.STK_UNIT = 'EA' THEN 'Each'
            WHEN o.STK_UNIT = 'PK' THEN 'Pack'
            WHEN o.STK_UNIT = 'BX' THEN 'Box'
            WHEN o.STK_UNIT = 'CT' THEN 'Carton'
            WHEN o.STK_UNIT = 'PL' THEN 'Pallet'
            WHEN o.STK_UNIT = 'CS' THEN 'Case'
            WHEN o.STK_UNIT = 'RL' THEN 'Roll'
            ELSE o.STK_UNIT
        END
    ) AS STOCKING_UNIT_DISPLAY,
    
    -- Pricing (using actual column names)
    o.PRC AS UNIT_PRICE,  -- Actual column: PRC
    o.EXT_PRC AS LINE_TOTAL,  -- Actual column: EXT_PRC (extended price)
    -- Discount: GROSS_EXT_PRC - DISP_EXT_PRC (if available)
    COALESCE(o.GROSS_EXT_PRC - o.DISP_EXT_PRC, 0) AS LINE_DISCOUNT,
    
    -- Order Totals (using actual column names)
    -- Note: SAL_LIN_TOT is sale line total, but we may need to sum line items
    o.SAL_LIN_TOT AS ORDER_SUBTOTAL,  -- Actual column: SAL_LIN_TOT
    0 AS ORDER_DISCOUNT,  -- May need to calculate from line discounts
    0 AS ORDER_TAX,  -- Tax may be in separate table or calculated
    o.SHIP_DAT AS SHIP_DATE,  -- Actual column: SHIP_DAT (datetime)
    0 AS ORDER_SHIPPING,  -- Shipping amount may need to be calculated
    o.SAL_LIN_TOT AS ORDER_TOTAL,  -- Using SAL_LIN_TOT as total for now
    
    -- Payment/Tracking/Notes (tables don't exist)
    NULL AS PAYMENT_CODE,
    NULL AS PAYMENT_METHOD,
    NULL AS PAYMENT_AMOUNT,
    NULL AS TRACKING_NUMBER,
    NULL AS ORDER_NOTE,
    
    -- Metadata (using actual column names)
    o.CUST_PO_NO AS CUSTOMER_PO_NUMBER,  -- Actual column: CUST_PO_NO
    o.SLS_REP AS SALES_REP,  -- Actual column: SLS_REP
    o.USR_ID AS CREATED_BY_USER,  -- Actual column: USR_ID (not USER_ID)
    
    -- Audit (using actual column names)
    o.LST_MAINT_DT AS LAST_MODIFIED_DATE,  -- Actual column: LST_MAINT_DT
    NULL AS POSTED_DATE  -- No POST_DAT column found
    
FROM OrderLinesWithUnits o
LEFT JOIN dbo.IM_UNIT_COD u ON u.UNIT = o.ACTUAL_UNIT_CODE
LEFT JOIN dbo.IM_UNIT_COD u_stk ON u_stk.UNIT = o.STK_UNIT
GO

PRINT 'Created VI_EXPORT_CP_ORDERS view (corrected with actual column names)';
PRINT '';
PRINT 'Key columns used:';
PRINT '  - Date: TKT_DT';
PRINT '  - Quantity: QTY_SOLD';
PRINT '  - Unit: SELL_UNIT';
PRINT '  - Price: PRC';
PRINT '  - Line Total: EXT_PRC';
PRINT '  - Order Total: SAL_LIN_TOT';
GO

-- ============================================
-- Enhanced View with Unit Mapping Table
-- ============================================
-- Note: This view requires VI_EXPORT_CP_ORDERS to exist first
-- If USER_UNIT_MAPPING table doesn't exist, it will still work (LEFT JOIN returns NULL)

IF EXISTS (SELECT * FROM sys.views WHERE name = 'VI_EXPORT_CP_ORDERS_WITH_UNITS')
    DROP VIEW dbo.VI_EXPORT_CP_ORDERS_WITH_UNITS;
GO

CREATE VIEW dbo.VI_EXPORT_CP_ORDERS_WITH_UNITS
AS
SELECT 
    o.*,
    COALESCE(u.UNIT_DISPLAY_NAME, o.SELLING_UNIT) AS UNIT_DISPLAY_NAME_MAPPED,
    u.UNIT_DESCRIPTION AS UNIT_DESCRIPTION,
    u.UNIT_CATEGORY AS UNIT_CATEGORY,
    u.SORT_ORDER AS UNIT_SORT_ORDER
FROM dbo.VI_EXPORT_CP_ORDERS o
LEFT JOIN dbo.USER_UNIT_MAPPING u ON u.UNIT_CODE = o.SELLING_UNIT AND u.IS_ACTIVE = 1;
GO

PRINT 'Created VI_EXPORT_CP_ORDERS_WITH_UNITS view (uses mapping table)';
GO


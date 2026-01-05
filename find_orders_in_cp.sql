-- ============================================
-- FIND ORDERS IN COUNTERPOINT
-- ============================================
-- Use this query to find the orders we just created
-- ============================================

USE WOODYS_CP;
GO

-- Find both orders with correct column names
SELECT 
    h.DOC_ID,
    h.TKT_NO,
    h.CUST_NO,
    h.TKT_DT AS OrderDate,           -- Correct column name (NOT ORD_DAT)
    h.DOC_TYP,
    h.STR_ID,
    h.STA_ID,
    t.SUB_TOT AS Subtotal,           -- From totals table
    t.TAX_AMT AS TaxAmount,          -- From totals table
    t.TOT AS TotalAmount,            -- From totals table (NOT TOT_AMT)
    t.TOT_HDR_DISC AS HeaderDiscount,
    t.TOT_LIN_DISC AS LineDiscount,
    h.ORD_LINS AS OrderLines,
    h.SAL_LINS AS SalesLines
FROM dbo.PS_DOC_HDR h
LEFT JOIN dbo.PS_DOC_HDR_TOT t ON h.DOC_ID = t.DOC_ID AND t.TOT_TYP = 'S'
WHERE h.DOC_ID IN (103398648481, 103398648482)
ORDER BY h.DOC_ID;
GO

-- View line items for both orders
SELECT 
    h.DOC_ID,
    h.TKT_NO,
    h.CUST_NO,
    l.LIN_SEQ_NO AS LineNumber,
    l.ITEM_NO AS SKU,
    l.DESCR AS Description,
    l.QTY_SOLD AS Quantity,
    l.PRC AS UnitPrice,
    l.EXT_PRC AS ExtendedPrice
FROM dbo.PS_DOC_HDR h
JOIN dbo.PS_DOC_LIN l ON h.DOC_ID = l.DOC_ID
WHERE h.DOC_ID IN (103398648481, 103398648482)
ORDER BY h.DOC_ID, l.LIN_SEQ_NO;
GO

-- View customer information
SELECT 
    c.CUST_NO,
    c.NAM AS CustomerName,
    c.EMAIL_ADRS_1 AS Email,
    c.PHONE_1 AS Phone
FROM dbo.AR_CUST c
WHERE c.CUST_NO IN ('10057', '10022');
GO

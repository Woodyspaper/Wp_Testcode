USE WOODYS_CP;
GO

-- ============================================
-- Improved: All Items With Most Recent Sale and Inventory
-- ============================================
-- Purpose: Show all items with their most recent sale date, vendor, and current stock
-- 
-- Improvements:
--   1. Dynamic date filter (last 12 months instead of hardcoded)
--   2. Added inventory information
--   3. Added e-commerce filter option
--   4. Added days since last sale calculation
--   5. Better formatting and comments
-- ============================================

-- ============================================
-- OPTION 1: All Items (including non-e-commerce)
-- ============================================
SELECT
    IM_ITEM.ITEM_NO AS 'ITEM NUMBER',
    IM_ITEM.DESCR AS 'DESCRIPTION',
    IM_ITEM.IS_ECOMM_ITEM AS 'IS E-COMM',
    MAX(T2.BUS_DAT) AS 'LAST SALE DATE',
    DATEDIFF(DAY, MAX(T2.BUS_DAT), GETDATE()) AS 'DAYS SINCE LAST SALE',
    T3.NAM AS 'PRIMARY VENDOR',
    ISNULL(SUM(inv.QTY_ON_HND), 0) AS 'CURRENT STOCK'
FROM IM_ITEM
    LEFT JOIN PS_TKT_HIST_LIN T2 ON T2.ITEM_NO = IM_ITEM.ITEM_NO 
        AND BUS_DAT >= DATEADD(MONTH, -12, GETDATE())  -- Last 12 months (dynamic)
    LEFT JOIN PO_VEND T3 ON T3.VEND_NO = IM_ITEM.ITEM_VEND_NO
    LEFT JOIN IM_INV inv ON inv.ITEM_NO = IM_ITEM.ITEM_NO
GROUP BY IM_ITEM.ITEM_NO, IM_ITEM.DESCR, IM_ITEM.IS_ECOMM_ITEM, T3.NAM 
ORDER BY IM_ITEM.ITEM_NO;
GO

-- ============================================
-- OPTION 2: E-commerce Items Only
-- ============================================
SELECT
    IM_ITEM.ITEM_NO AS 'ITEM NUMBER',
    IM_ITEM.DESCR AS 'DESCRIPTION',
    MAX(T2.BUS_DAT) AS 'LAST SALE DATE',
    DATEDIFF(DAY, MAX(T2.BUS_DAT), GETDATE()) AS 'DAYS SINCE LAST SALE',
    T3.NAM AS 'PRIMARY VENDOR',
    ISNULL(SUM(inv.QTY_ON_HND), 0) AS 'CURRENT STOCK'
FROM IM_ITEM
    LEFT JOIN PS_TKT_HIST_LIN T2 ON T2.ITEM_NO = IM_ITEM.ITEM_NO 
        AND BUS_DAT >= DATEADD(MONTH, -12, GETDATE())
    LEFT JOIN PO_VEND T3 ON T3.VEND_NO = IM_ITEM.ITEM_VEND_NO
    LEFT JOIN IM_INV inv ON inv.ITEM_NO = IM_ITEM.ITEM_NO
WHERE IM_ITEM.IS_ECOMM_ITEM = 'Y'  -- Only e-commerce items
GROUP BY IM_ITEM.ITEM_NO, IM_ITEM.DESCR, T3.NAM 
ORDER BY IM_ITEM.ITEM_NO;
GO

-- ============================================
-- OPTION 3: Slow-Moving Items (No sales in 6+ months)
-- ============================================
SELECT
    IM_ITEM.ITEM_NO AS 'ITEM NUMBER',
    IM_ITEM.DESCR AS 'DESCRIPTION',
    MAX(T2.BUS_DAT) AS 'LAST SALE DATE',
    DATEDIFF(DAY, MAX(T2.BUS_DAT), GETDATE()) AS 'DAYS SINCE LAST SALE',
    T3.NAM AS 'PRIMARY VENDOR',
    ISNULL(SUM(inv.QTY_ON_HND), 0) AS 'CURRENT STOCK'
FROM IM_ITEM
    LEFT JOIN PS_TKT_HIST_LIN T2 ON T2.ITEM_NO = IM_ITEM.ITEM_NO 
        AND BUS_DAT >= DATEADD(MONTH, -24, GETDATE())  -- Look back 24 months
    LEFT JOIN PO_VEND T3 ON T3.VEND_NO = IM_ITEM.ITEM_VEND_NO
    LEFT JOIN IM_INV inv ON inv.ITEM_NO = IM_ITEM.ITEM_NO
WHERE IM_ITEM.IS_ECOMM_ITEM = 'Y'
GROUP BY IM_ITEM.ITEM_NO, IM_ITEM.DESCR, T3.NAM 
HAVING MAX(T2.BUS_DAT) < DATEADD(MONTH, -6, GETDATE())  -- No sales in 6 months
    OR MAX(T2.BUS_DAT) IS NULL  -- Never sold
ORDER BY ISNULL(MAX(T2.BUS_DAT), '1900-01-01') ASC, IM_ITEM.ITEM_NO;
GO

-- ============================================
-- OPTION 4: Recently Sold Items (Last 30 days)
-- ============================================
SELECT
    IM_ITEM.ITEM_NO AS 'ITEM NUMBER',
    IM_ITEM.DESCR AS 'DESCRIPTION',
    MAX(T2.BUS_DAT) AS 'LAST SALE DATE',
    COUNT(DISTINCT T2.TKT_NO) AS 'NUMBER OF SALES',
    T3.NAM AS 'PRIMARY VENDOR',
    ISNULL(SUM(inv.QTY_ON_HND), 0) AS 'CURRENT STOCK'
FROM IM_ITEM
    INNER JOIN PS_TKT_HIST_LIN T2 ON T2.ITEM_NO = IM_ITEM.ITEM_NO 
        AND BUS_DAT >= DATEADD(DAY, -30, GETDATE())  -- Last 30 days
    LEFT JOIN PO_VEND T3 ON T3.VEND_NO = IM_ITEM.ITEM_VEND_NO
    LEFT JOIN IM_INV inv ON inv.ITEM_NO = IM_ITEM.ITEM_NO
WHERE IM_ITEM.IS_ECOMM_ITEM = 'Y'
GROUP BY IM_ITEM.ITEM_NO, IM_ITEM.DESCR, T3.NAM 
ORDER BY MAX(T2.BUS_DAT) DESC, COUNT(DISTINCT T2.TKT_NO) DESC;
GO


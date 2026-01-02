-- Alternative: Test with GRP_COD (Contract Group Code)
-- This doesn't require NCR_BID_NO column
-- Date: December 30, 2025

-- Find customers in contract groups (using correct column names):
SELECT TOP 10
    c.CUST_NO,
    c.NAM AS CUST_NAM,  -- Correct column name
    c.GRP_COD,
    r.RUL_SEQ_NO,
    r.ITEM_FILT_TEXT AS PRODUCT_FILTER
FROM dbo.AR_CUST c
INNER JOIN dbo.IM_PRC_RUL r ON c.GRP_COD = r.GRP_COD
WHERE r.GRP_TYP = 'C'  -- Contract type
ORDER BY c.CUST_NO;

-- Find products that match contract pricing rules:
SELECT TOP 10
    i.ITEM_NO,
    i.DESCR,
    v.NCR_TYPE,
    r.GRP_COD,
    r.RUL_SEQ_NO
FROM dbo.IM_ITEM i
INNER JOIN dbo.VI_PRODUCT_NCR_TYPE v ON i.ITEM_NO = v.ITEM_NO
INNER JOIN dbo.IM_PRC_RUL r ON r.ITEM_FILT_TEXT LIKE '%' + v.NCR_TYPE + '%'
WHERE r.GRP_TYP = 'C'
ORDER BY i.ITEM_NO;

-- Get a test combination (using correct column names):
SELECT TOP 1
    c.CUST_NO,
    c.NAM AS CUST_NAM,  -- Correct column name
    c.GRP_COD AS NCR_BID_NO,  -- Use GRP_COD as NCR_BID_NO for testing
    i.ITEM_NO,
    i.DESCR,
    v.NCR_TYPE
FROM dbo.AR_CUST c
INNER JOIN dbo.IM_PRC_RUL r ON c.GRP_COD = r.GRP_COD
INNER JOIN dbo.VI_PRODUCT_NCR_TYPE v ON r.ITEM_FILT_TEXT LIKE '%' + v.NCR_TYPE + '%'
INNER JOIN dbo.IM_ITEM i ON i.ITEM_NO = v.ITEM_NO
WHERE r.GRP_TYP = 'C'
  AND v.NCR_TYPE != 'UNKNOWN'
ORDER BY c.CUST_NO;

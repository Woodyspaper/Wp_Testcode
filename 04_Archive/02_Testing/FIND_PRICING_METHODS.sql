-- Find test data for different pricing methods
-- Date: December 30, 2025
-- Purpose: Find products with Override (O), Markup (M), and Amount Off (A) pricing methods

-- Test 1: Find Discount % (D) - Already tested
SELECT TOP 5
    r.GRP_COD AS NCR_BID_NO,
    i.ITEM_NO,
    i.DESCR,
    b.PRC_METH,
    b.AMT_OR_PCT,
    b.MIN_QTY,
    'D - Discount %' AS PRICING_METHOD_DESCRIPTION
FROM dbo.IM_PRC_RUL r
INNER JOIN dbo.VI_PRODUCT_NCR_TYPE v ON CAST(r.ITEM_FILT_TEXT AS NVARCHAR(MAX)) LIKE '%' + v.NCR_TYPE + '%'
INNER JOIN dbo.IM_ITEM i ON i.ITEM_NO = v.ITEM_NO
INNER JOIN dbo.IM_PRC_RUL_BRK b ON b.GRP_COD = r.GRP_COD AND b.RUL_SEQ_NO = r.RUL_SEQ_NO
WHERE r.GRP_TYP = 'C'
  AND b.PRC_METH = 'D'
  AND v.NCR_TYPE != 'UNKNOWN'
ORDER BY r.GRP_COD, i.ITEM_NO;

-- Test 2: Find Override (O) pricing
SELECT TOP 5
    r.GRP_COD AS NCR_BID_NO,
    i.ITEM_NO,
    i.DESCR,
    b.PRC_METH,
    b.AMT_OR_PCT,
    b.MIN_QTY,
    'O - Override Price' AS PRICING_METHOD_DESCRIPTION
FROM dbo.IM_PRC_RUL r
INNER JOIN dbo.VI_PRODUCT_NCR_TYPE v ON CAST(r.ITEM_FILT_TEXT AS NVARCHAR(MAX)) LIKE '%' + v.NCR_TYPE + '%'
INNER JOIN dbo.IM_ITEM i ON i.ITEM_NO = v.ITEM_NO
INNER JOIN dbo.IM_PRC_RUL_BRK b ON b.GRP_COD = r.GRP_COD AND b.RUL_SEQ_NO = r.RUL_SEQ_NO
WHERE r.GRP_TYP = 'C'
  AND b.PRC_METH = 'O'
  AND v.NCR_TYPE != 'UNKNOWN'
ORDER BY r.GRP_COD, i.ITEM_NO;

-- Test 3: Find Markup % (M) pricing
SELECT TOP 5
    r.GRP_COD AS NCR_BID_NO,
    i.ITEM_NO,
    i.DESCR,
    b.PRC_METH,
    b.AMT_OR_PCT,
    b.MIN_QTY,
    'M - Markup %' AS PRICING_METHOD_DESCRIPTION
FROM dbo.IM_PRC_RUL r
INNER JOIN dbo.VI_PRODUCT_NCR_TYPE v ON CAST(r.ITEM_FILT_TEXT AS NVARCHAR(MAX)) LIKE '%' + v.NCR_TYPE + '%'
INNER JOIN dbo.IM_ITEM i ON i.ITEM_NO = v.ITEM_NO
INNER JOIN dbo.IM_PRC_RUL_BRK b ON b.GRP_COD = r.GRP_COD AND b.RUL_SEQ_NO = r.RUL_SEQ_NO
WHERE r.GRP_TYP = 'C'
  AND b.PRC_METH = 'M'
  AND v.NCR_TYPE != 'UNKNOWN'
ORDER BY r.GRP_COD, i.ITEM_NO;

-- Test 4: Find Amount Off (A) pricing
SELECT TOP 5
    r.GRP_COD AS NCR_BID_NO,
    i.ITEM_NO,
    i.DESCR,
    b.PRC_METH,
    b.AMT_OR_PCT,
    b.MIN_QTY,
    'A - Amount Off' AS PRICING_METHOD_DESCRIPTION
FROM dbo.IM_PRC_RUL r
INNER JOIN dbo.VI_PRODUCT_NCR_TYPE v ON CAST(r.ITEM_FILT_TEXT AS NVARCHAR(MAX)) LIKE '%' + v.NCR_TYPE + '%'
INNER JOIN dbo.IM_ITEM i ON i.ITEM_NO = v.ITEM_NO
INNER JOIN dbo.IM_PRC_RUL_BRK b ON b.GRP_COD = r.GRP_COD AND b.RUL_SEQ_NO = r.RUL_SEQ_NO
WHERE r.GRP_TYP = 'C'
  AND b.PRC_METH = 'A'
  AND v.NCR_TYPE != 'UNKNOWN'
ORDER BY r.GRP_COD, i.ITEM_NO;

-- Test 5: Find products with quantity breaks (for edge case testing)
SELECT TOP 10
    r.GRP_COD AS NCR_BID_NO,
    i.ITEM_NO,
    i.DESCR,
    b.MIN_QTY,
    b.AMT_OR_PCT,
    b.PRC_METH,
    'Quantity Break Test' AS TEST_TYPE
FROM dbo.IM_PRC_RUL r
INNER JOIN dbo.VI_PRODUCT_NCR_TYPE v ON CAST(r.ITEM_FILT_TEXT AS NVARCHAR(MAX)) LIKE '%' + v.NCR_TYPE + '%'
INNER JOIN dbo.IM_ITEM i ON i.ITEM_NO = v.ITEM_NO
INNER JOIN dbo.IM_PRC_RUL_BRK b ON b.GRP_COD = r.GRP_COD AND b.RUL_SEQ_NO = r.RUL_SEQ_NO
WHERE r.GRP_TYP = 'C'
  AND b.MIN_QTY > 0  -- Has quantity breaks
  AND v.NCR_TYPE != 'UNKNOWN'
ORDER BY r.GRP_COD, i.ITEM_NO, b.MIN_QTY;

-- Summary: Count pricing methods
SELECT 
    b.PRC_METH,
    CASE b.PRC_METH
        WHEN 'D' THEN 'Discount %'
        WHEN 'O' THEN 'Override Price'
        WHEN 'M' THEN 'Markup %'
        WHEN 'A' THEN 'Amount Off'
        ELSE 'Unknown'
    END AS PRICING_METHOD_NAME,
    COUNT(*) AS RULE_COUNT
FROM dbo.IM_PRC_RUL r
INNER JOIN dbo.IM_PRC_RUL_BRK b ON b.GRP_COD = r.GRP_COD AND b.RUL_SEQ_NO = r.RUL_SEQ_NO
WHERE r.GRP_TYP = 'C'
GROUP BY b.PRC_METH
ORDER BY RULE_COUNT DESC;

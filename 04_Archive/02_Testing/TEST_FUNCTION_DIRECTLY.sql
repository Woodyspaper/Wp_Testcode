-- Test the contract pricing function directly
-- Date: December 30, 2025
-- Use values from GET_TEST_DATA_SIMPLE.sql results

-- Test 1: Basic test with values from query results
SELECT * 
FROM dbo.fn_GetContractPrice('144319', '01-10100', 1.0, '01');

-- Test 2: Try different quantity (might have quantity breaks)
SELECT * 
FROM dbo.fn_GetContractPrice('144319', '01-10100', 10.0, '01');

-- Test 3: Try quantity 25 (common break point)
SELECT * 
FROM dbo.fn_GetContractPrice('144319', '01-10100', 25.0, '01');

-- Test 4: Try quantity 50
SELECT * 
FROM dbo.fn_GetContractPrice('144319', '01-10100', 50.0, '01');

-- Test 5: Check if rule exists for this combination
SELECT 
    r.GRP_COD,
    r.RUL_SEQ_NO,
    r.DESCR,
    CAST(r.ITEM_FILT_TEXT AS NVARCHAR(MAX)) AS ITEM_FILT_TEXT,
    v.NCR_TYPE,
    i.ITEM_NO
FROM dbo.IM_PRC_RUL r
INNER JOIN dbo.VI_PRODUCT_NCR_TYPE v ON CAST(r.ITEM_FILT_TEXT AS NVARCHAR(MAX)) LIKE '%' + v.NCR_TYPE + '%'
INNER JOIN dbo.IM_ITEM i ON i.ITEM_NO = v.ITEM_NO
WHERE r.GRP_COD = '144319'
  AND r.GRP_TYP = 'C'
  AND i.ITEM_NO = '01-10100';

-- Test 6: Check quantity breaks for this rule
SELECT 
    b.MIN_QTY,
    b.AMT_OR_PCT,
    b.PRC_METH,
    b.PRC_BASIS
FROM dbo.IM_PRC_RUL r
INNER JOIN dbo.IM_PRC_RUL_BRK b ON b.GRP_COD = r.GRP_COD AND b.RUL_SEQ_NO = r.RUL_SEQ_NO
WHERE r.GRP_COD = '144319'
  AND r.GRP_TYP = 'C'
  AND r.RUL_SEQ_NO = 1  -- From query results
ORDER BY b.MIN_QTY;

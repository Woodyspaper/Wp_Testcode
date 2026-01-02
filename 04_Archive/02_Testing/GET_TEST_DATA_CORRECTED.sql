-- Get test data for API testing (using correct column names)
-- Date: December 30, 2025
-- Column names discovered: NAM (not CUST_NAM), GRP_COD (not NCR_BID_NO)

-- Option 1: Get customers with contract groups
SELECT TOP 10
    c.CUST_NO,
    c.NAM AS CUST_NAM,  -- Correct column name
    c.GRP_COD,          -- Use this as "NCR_BID_NO" in API test
    r.RUL_SEQ_NO,
    r.ITEM_FILT_TEXT AS PRODUCT_FILTER
FROM dbo.AR_CUST c
INNER JOIN dbo.IM_PRC_RUL r ON c.GRP_COD = r.GRP_COD
WHERE r.GRP_TYP = 'C'  -- Contract type
ORDER BY c.CUST_NO;

-- Option 2: Get complete test combination (customer + product)
SELECT TOP 5
    c.CUST_NO,
    c.NAM AS CUST_NAM,
    c.GRP_COD AS NCR_BID_NO,  -- Use this value in API test
    i.ITEM_NO,                 -- Use this value in API test
    i.DESCR AS ITEM_DESCRIPTION,
    v.NCR_TYPE
FROM dbo.AR_CUST c
INNER JOIN dbo.IM_PRC_RUL r ON c.GRP_COD = r.GRP_COD
INNER JOIN dbo.VI_PRODUCT_NCR_TYPE v ON r.ITEM_FILT_TEXT LIKE '%' + v.NCR_TYPE + '%'
INNER JOIN dbo.IM_ITEM i ON i.ITEM_NO = v.ITEM_NO
WHERE r.GRP_TYP = 'C'  -- Contract type
  AND v.NCR_TYPE != 'UNKNOWN'
ORDER BY c.CUST_NO, i.ITEM_NO;

-- Option 3: Simple - just get GRP_COD values
SELECT DISTINCT TOP 10
    GRP_COD AS NCR_BID_NO,  -- Use this in API test
    COUNT(DISTINCT CUST_NO) AS CUSTOMER_COUNT
FROM dbo.AR_CUST
WHERE GRP_COD IS NOT NULL
  AND GRP_COD != ''
GROUP BY GRP_COD
ORDER BY CUSTOMER_COUNT DESC;

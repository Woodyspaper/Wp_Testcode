-- Minimal test data query - Only uses columns we know exist
-- Date: December 30, 2025
-- Updated after discovering GRP_NAM doesn't exist

-- Option 1: Get contract group codes (simplified - no GRP_NAM)
SELECT DISTINCT TOP 10
    GRP_COD AS NCR_BID_NO,  -- Use this value in API test
    COUNT(DISTINCT RUL_SEQ_NO) AS RULE_COUNT
FROM dbo.IM_PRC_RUL
WHERE GRP_TYP = 'C'  -- Contract type
GROUP BY GRP_COD
ORDER BY RULE_COUNT DESC;

-- Option 2: Get complete test combination (GRP_COD + Product)
-- Cast ITEM_FILT_TEXT to NVARCHAR to handle text/ntext data type
SELECT TOP 5
    r.GRP_COD AS NCR_BID_NO,  -- Use this in API test
    i.ITEM_NO,                 -- Use this in API test
    i.DESCR AS ITEM_DESCRIPTION,
    v.NCR_TYPE,
    r.RUL_SEQ_NO,
    r.DESCR AS RULE_DESCRIPTION
FROM dbo.IM_PRC_RUL r
INNER JOIN dbo.VI_PRODUCT_NCR_TYPE v ON CAST(r.ITEM_FILT_TEXT AS NVARCHAR(MAX)) LIKE '%' + v.NCR_TYPE + '%'
INNER JOIN dbo.IM_ITEM i ON i.ITEM_NO = v.ITEM_NO
WHERE r.GRP_TYP = 'C'  -- Contract type
  AND v.NCR_TYPE != 'UNKNOWN'
ORDER BY r.GRP_COD, i.ITEM_NO;

-- Option 3: Test with a specific contract group (simplified)
-- Replace 'YOUR_GRP_COD' with a value from Option 1
-- Cast ITEM_FILT_TEXT to NVARCHAR to handle text/ntext data type
SELECT 
    r.GRP_COD AS NCR_BID_NO,
    r.RUL_SEQ_NO,
    r.DESCR AS RULE_DESCRIPTION,
    CAST(r.ITEM_FILT_TEXT AS NVARCHAR(MAX)) AS PRODUCT_FILTER,
    COUNT(DISTINCT i.ITEM_NO) AS PRODUCT_COUNT
FROM dbo.IM_PRC_RUL r
LEFT JOIN dbo.VI_PRODUCT_NCR_TYPE v ON CAST(r.ITEM_FILT_TEXT AS NVARCHAR(MAX)) LIKE '%' + v.NCR_TYPE + '%'
LEFT JOIN dbo.IM_ITEM i ON i.ITEM_NO = v.ITEM_NO
WHERE r.GRP_TYP = 'C'
  AND r.GRP_COD = 'YOUR_GRP_COD'  -- Replace with actual GRP_COD from Option 1
GROUP BY r.GRP_COD, r.RUL_SEQ_NO, r.DESCR, CAST(r.ITEM_FILT_TEXT AS NVARCHAR(MAX))
ORDER BY r.RUL_SEQ_NO;

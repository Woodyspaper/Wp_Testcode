-- Find customers with NCR BID NO (after discovering column names)
-- Date: December 30, 2025
-- 
-- STEP 1: First run DISCOVER_AR_CUST_COLUMNS.sql to find actual column names
-- STEP 2: Update this query with correct column names
-- STEP 3: Run this query to get test data

-- Example (update with actual column names):
-- SELECT TOP 10
--     CUST_NO,           -- Update if different
--     CUST_NAM,          -- Update if different (might be CUST_NAME, NAME, etc.)
--     NCR_BID_NO         -- Update if different (might be NCR_BID, BID_NO, etc.)
-- FROM dbo.AR_CUST
-- WHERE NCR_BID_NO IS NOT NULL  -- Update column name
--   AND NCR_BID_NO != ''         -- Update column name
-- ORDER BY CUST_NO;

-- Alternative: If NCR BID is in a different table or field
-- Check contract pricing groups:
SELECT TOP 10
    GRP_COD,
    GRP_NAM,
    GRP_TYP
FROM dbo.IM_PRC_RUL
WHERE GRP_TYP = 'C'  -- Contract type
GROUP BY GRP_COD, GRP_NAM, GRP_TYP
ORDER BY GRP_COD;

-- Check customer groups:
SELECT TOP 10
    c.CUST_NO,
    c.CUST_NAM,  -- Update if column name is different
    c.GRP_COD
FROM dbo.AR_CUST c
INNER JOIN dbo.IM_PRC_RUL r ON c.GRP_COD = r.GRP_COD
WHERE r.GRP_TYP = 'C'
GROUP BY c.CUST_NO, c.CUST_NAM, c.GRP_COD
ORDER BY c.CUST_NO;

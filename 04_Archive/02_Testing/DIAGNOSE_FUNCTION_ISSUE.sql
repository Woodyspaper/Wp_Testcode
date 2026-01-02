-- Diagnose why fn_GetContractPrice returns empty
-- Date: December 30, 2025

-- Step 1: Check if regular price exists for this product
SELECT 
    p.ITEM_NO,
    p.LOC_ID,
    p.REG_PRC,
    p.PRC_1,
    p.PRC_2,
    p.PRC_3
FROM dbo.IM_PRC p
WHERE p.ITEM_NO = '01-10100'
  AND p.LOC_ID = '01';

-- Step 2: Check all locations for this product
SELECT 
    p.ITEM_NO,
    p.LOC_ID,
    p.REG_PRC,
    p.PRC_1,
    p.PRC_2,
    p.PRC_3
FROM dbo.IM_PRC p
WHERE p.ITEM_NO = '01-10100'
ORDER BY p.LOC_ID;

-- Step 3: Check if product exists in IM_ITEM
-- First discover column names, then check product
SELECT TOP 1 *
FROM dbo.IM_ITEM
WHERE ITEM_NO = '01-10100';

-- Step 4: Test function with different location (if needed)
-- First check what locations are available in Step 2, then test:
-- SELECT * 
-- FROM dbo.fn_GetContractPrice('144319', '01-10100', 50.0, 'YOUR_LOC_ID');

-- Step 5: Check what the function's RegularPrice CTE would return
SELECT 
    p.REG_PRC AS BASE_PRICE,
    p.PRC_1,
    p.PRC_2,
    p.PRC_3,
    'R' AS PRC_BASIS  -- From quantity break
FROM dbo.IM_PRC p
WHERE p.ITEM_NO = '01-10100'
  AND p.LOC_ID = '01';

-- Step 6: Manual price calculation check
-- If REG_PRC = 100 and discount = 49.4949%, contract price should be 50.5051
SELECT 
    p.REG_PRC AS REGULAR_PRICE,
    49.4949 AS DISCOUNT_PCT,
    p.REG_PRC * (1 - 49.4949 / 100) AS CALCULATED_CONTRACT_PRICE,
    'D' AS PRICING_METHOD
FROM dbo.IM_PRC p
WHERE p.ITEM_NO = '01-10100'
  AND p.LOC_ID = '01';

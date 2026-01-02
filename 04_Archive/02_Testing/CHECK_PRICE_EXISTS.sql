-- Quick check: Does price exist for this product?
-- Date: December 30, 2025

-- Check 1: Price for LOC_ID='01'
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

-- Check 2: All locations for this product
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

-- Check 3: If no price exists, try function with NULL location
-- (Function might handle NULL differently)
SELECT * 
FROM dbo.fn_GetContractPrice('144319', '01-10100', 50.0, NULL);

-- Check 4: Try with first available location
-- (Replace 'XX' with actual LOC_ID from Check 2)
-- SELECT * 
-- FROM dbo.fn_GetContractPrice('144319', '01-10100', 50.0, 'XX');

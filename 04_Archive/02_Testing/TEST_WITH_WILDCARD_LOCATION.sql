-- Test function with LOC_ID='*' (wildcard/default location)
-- Date: December 30, 2025
-- Price exists for LOC_ID='*', not '01'

-- Test 1: With LOC_ID='*'
SELECT * 
FROM dbo.fn_GetContractPrice('144319', '01-10100', 50.0, '*');

-- Test 2: With different quantities
SELECT * 
FROM dbo.fn_GetContractPrice('144319', '01-10100', 1.0, '*');

SELECT * 
FROM dbo.fn_GetContractPrice('144319', '01-10100', 10.0, '*');

SELECT * 
FROM dbo.fn_GetContractPrice('144319', '01-10100', 25.0, '*');

-- Expected results:
-- Regular Price: 41.7690 (or 41.7700)
-- Contract Price: ~21.08 (49.4949% discount from 41.77)
-- Pricing Method: D (Discount %)
-- Discount: 49.4949%

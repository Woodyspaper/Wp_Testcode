-- ============================================
-- Contract Price Calculation Function
-- ============================================
-- Purpose: Calculate contract price for a customer/product/quantity combination
-- 
-- Input Parameters:
--   @NCR_BID_NO    - Customer's NCR BID # (from AR_CUST.NCR_BID_NO)
--   @ITEM_NO       - Product SKU (from IM_ITEM.ITEM_NO)
--   @QUANTITY      - Order quantity
--   @LOC_ID        - Location ID (default '01')
--
-- Output:
--   CONTRACT_PRICE - Calculated contract price (NULL if no contract applies)
--   REGULAR_PRICE  - Regular price for comparison
--   DISCOUNT_PCT   - Discount percentage applied
--   PRICING_METHOD - How price was calculated (D=Discount%, O=Override, M=Markup%, A=AmountOff)
--
-- Returns: Table with price details or NULL if no contract
-- ============================================

-- First, create a view that extracts NCR TYPE for all products
-- This will be used by the function

IF EXISTS (SELECT * FROM sys.views WHERE name = 'VI_PRODUCT_NCR_TYPE')
    DROP VIEW dbo.VI_PRODUCT_NCR_TYPE;
GO

CREATE VIEW dbo.VI_PRODUCT_NCR_TYPE
AS
SELECT 
    ITEM_NO,
    DESCR,
    SHORT_DESCR,
    ATTR_COD_1,
    -- Extract NCR TYPE using the same logic from ENHANCED_NCR_TYPE_EXTRACTION.sql
    CASE 
        -- XERO/FORM II patterns (check first, more specific)
        WHEN (DESCR LIKE '%XERO/FORM II%PC%XF%' OR SHORT_DESCR LIKE '%XERO/FORM II%PC%XF%'
           OR DESCR LIKE '%XERO/FORM II SINGLES%PC%XF%' OR SHORT_DESCR LIKE '%XERO/FORM II SINGLES%PC%XF%')
        THEN 'PC XF'
        
        WHEN (DESCR LIKE '%XERO/FORM II%CB%XF%' OR SHORT_DESCR LIKE '%XERO/FORM II%CB%XF%'
           OR DESCR LIKE '%XERO/FORM II SINGLES%CB%XF%' OR SHORT_DESCR LIKE '%XERO/FORM II SINGLES%CB%XF%')
        THEN 'CB XF'
        
        WHEN (DESCR LIKE '%XERO/FORM II%CFB%XF%' OR SHORT_DESCR LIKE '%XERO/FORM II%CFB%XF%'
           OR DESCR LIKE '%XERO/FORM II SINGLES%CFB%XF%' OR SHORT_DESCR LIKE '%XERO/FORM II SINGLES%CFB%XF%')
        THEN 'CFB XF'
        
        -- SUPERIOR PERF pattern
        WHEN (DESCR LIKE '%SUPERIOR PERF%PC%S%P%' OR SHORT_DESCR LIKE '%SUPERIOR PERF%PC%S%P%'
           OR DESCR LIKE '%PERF PC S P%' OR SHORT_DESCR LIKE '%PERF PC S P%')
        THEN 'PC S P'
        
        -- CB patterns (check before PC)
        WHEN (DESCR LIKE '%SUPERIOR CB%' OR SHORT_DESCR LIKE '%SUPERIOR CB%'
           OR DESCR LIKE '%CB WHITE%' OR DESCR LIKE '%CB CANARY%' OR DESCR LIKE '%CB PINK%'
           OR DESCR LIKE '%CB GOLDENROD%' OR DESCR LIKE '%CB GREEN%' OR DESCR LIKE '%CB BLUE%'
           OR SHORT_DESCR LIKE '%CB WHITE%' OR SHORT_DESCR LIKE '%CB CANARY%' OR SHORT_DESCR LIKE '%CB PINK%'
           OR SHORT_DESCR LIKE '%CB GOLDENROD%' OR SHORT_DESCR LIKE '%CB GREEN%' OR SHORT_DESCR LIKE '%CB BLUE%'
           OR DESCR LIKE '%NCR CB%' OR SHORT_DESCR LIKE '%NCR CB%')
         AND ATTR_COD_1 IN ('8.5X11', '8.5X14', '11X17', '12X18', '18X12', '17X11', '8.5X11.5', '11.5X17', '12X15.5')
        THEN 'CB S CS'
        
        WHEN (DESCR LIKE '%SUPERIOR CB%' OR SHORT_DESCR LIKE '%SUPERIOR CB%'
           OR DESCR LIKE '%CB WHITE%' OR DESCR LIKE '%CB CANARY%' OR DESCR LIKE '%CB PINK%'
           OR DESCR LIKE '%CB GOLDENROD%' OR DESCR LIKE '%CB GREEN%' OR DESCR LIKE '%CB BLUE%'
           OR SHORT_DESCR LIKE '%CB WHITE%' OR SHORT_DESCR LIKE '%CB CANARY%' OR SHORT_DESCR LIKE '%CB PINK%'
           OR SHORT_DESCR LIKE '%CB GOLDENROD%' OR SHORT_DESCR LIKE '%CB GREEN%' OR SHORT_DESCR LIKE '%CB BLUE%'
           OR DESCR LIKE '%NCR CB%' OR SHORT_DESCR LIKE '%NCR CB%')
         AND ATTR_COD_1 IN ('17.5X22.5', '34.5X22.5', '34.5X28.5', '23X35', '26X40', '28X40', '22.5X35', '25X38', '20.5X29.5')
        THEN 'CB S F'
        
        -- PC patterns
        WHEN (DESCR LIKE '%SUPERIOR PC%' OR SHORT_DESCR LIKE '%SUPERIOR PC%')
         AND ATTR_COD_1 IN ('8.5X11', '8.5X14', '11X17', '12X18', '18X12', '17X11', '8.5X11.5', '11.5X17', '12X15.5')
        THEN 'PC S CS'
        
        WHEN (DESCR LIKE '%SUPERIOR PC%' OR SHORT_DESCR LIKE '%SUPERIOR PC%')
         AND ATTR_COD_1 IN ('17.5X22.5', '34.5X22.5', '34.5X28.5', '23X35', '26X40', '28X40', '22.5X35', '25X38', '20.5X29.5')
        THEN 'PC S F'
        
        -- CFB patterns
        WHEN (DESCR LIKE '%SUPERIOR CFB%' OR SHORT_DESCR LIKE '%SUPERIOR CFB%')
         AND ATTR_COD_1 IN ('8.5X11', '8.5X14', '11X17', '12X18', '18X12', '17X11', '8.5X11.5', '11.5X17', '12X15.5')
        THEN 'CFB S CS'
        
        WHEN (DESCR LIKE '%SUPERIOR CFB%' OR SHORT_DESCR LIKE '%SUPERIOR CFB%')
         AND ATTR_COD_1 IN ('17.5X22.5', '34.5X22.5', '34.5X28.5', '23X35', '26X40', '28X40', '22.5X35', '25X38', '20.5X29.5')
        THEN 'CFB S F'
        
        -- CF patterns
        WHEN (DESCR LIKE '%SUPERIOR CF%' OR SHORT_DESCR LIKE '%SUPERIOR CF%')
         AND NOT (DESCR LIKE '%SUPERIOR CFB%' OR SHORT_DESCR LIKE '%SUPERIOR CFB%')
         AND ATTR_COD_1 IN ('8.5X11', '8.5X14', '11X17', '12X18', '18X12', '17X11', '8.5X11.5', '11.5X17', '12X15.5')
        THEN 'CF S CS'
        
        WHEN (DESCR LIKE '%SUPERIOR CF%' OR SHORT_DESCR LIKE '%SUPERIOR CF%')
         AND NOT (DESCR LIKE '%SUPERIOR CFB%' OR SHORT_DESCR LIKE '%SUPERIOR CFB%')
         AND ATTR_COD_1 IN ('17.5X22.5', '34.5X22.5', '34.5X28.5', '23X35', '26X40', '28X40', '22.5X35', '25X38', '20.5X29.5')
        THEN 'CF S F'
        
        -- Generic CF
        WHEN (DESCR LIKE '%CF%' OR SHORT_DESCR LIKE '%CF%')
         AND NOT (DESCR LIKE '%CFB%' OR SHORT_DESCR LIKE '%CFB%')
         AND NOT (DESCR LIKE '%CF S%' OR SHORT_DESCR LIKE '%CF S%')
        THEN 'CF'
        
        ELSE 'UNKNOWN'
    END AS NCR_TYPE
FROM dbo.IM_ITEM
WHERE IS_ECOMM_ITEM = 'Y';
GO

-- ============================================
-- Function: Calculate Contract Price
-- ============================================

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'TF' AND name = 'fn_GetContractPrice')
    DROP FUNCTION dbo.fn_GetContractPrice;
GO

CREATE FUNCTION dbo.fn_GetContractPrice(
    @NCR_BID_NO VARCHAR(15),
    @ITEM_NO    VARCHAR(30),
    @QUANTITY   DECIMAL(15,4) = 1,
    @LOC_ID     VARCHAR(10) = '01'
)
RETURNS TABLE
AS
RETURN
(
    WITH ProductNCRType AS (
        SELECT NCR_TYPE
        FROM dbo.VI_PRODUCT_NCR_TYPE
        WHERE ITEM_NO = @ITEM_NO
    ),
    MatchingRule AS (
        SELECT TOP 1
            r.GRP_COD,
            r.RUL_SEQ_NO,
            r.DESCR AS RULE_DESCR,
            CAST(r.ITEM_FILT_TEXT AS NVARCHAR(MAX)) AS ITEM_FILTER
        FROM dbo.IM_PRC_RUL r
        CROSS JOIN ProductNCRType p
        WHERE r.GRP_COD = @NCR_BID_NO
          AND r.GRP_TYP = 'C'
          AND (
            -- No filter (applies to all products)
            CAST(r.ITEM_FILT_TEXT AS NVARCHAR(MAX)) IS NULL
            OR CAST(r.ITEM_FILT_TEXT AS NVARCHAR(MAX)) = ''
            OR CAST(r.ITEM_FILT_TEXT AS NVARCHAR(MAX)) = '***All***'
            -- NCR TYPE exact match (97.8% of cases)
            OR (p.NCR_TYPE != 'UNKNOWN' 
                AND CAST(r.ITEM_FILT_TEXT AS NVARCHAR(MAX)) LIKE '%NCR TYPE is (exactly) ' + p.NCR_TYPE + '%')
            -- Complex filter: NCR TYPE + Item number (0.2% of cases)
            OR (p.NCR_TYPE != 'UNKNOWN' 
                AND CAST(r.ITEM_FILT_TEXT AS NVARCHAR(MAX)) LIKE '%NCR TYPE is (exactly) ' + p.NCR_TYPE + '%'
                AND CAST(r.ITEM_FILT_TEXT AS NVARCHAR(MAX)) LIKE '%Item number is (exactly) ' + @ITEM_NO + '%')
            -- Specific item filter (1.9% of cases)
            OR CAST(r.ITEM_FILT_TEXT AS NVARCHAR(MAX)) LIKE '%Item number is (exactly) ' + @ITEM_NO + '%'
          )
        ORDER BY 
            -- Prioritize specific item filters over NCR TYPE filters
            CASE WHEN CAST(r.ITEM_FILT_TEXT AS NVARCHAR(MAX)) LIKE '%Item number is (exactly) ' + @ITEM_NO + '%' THEN 1 ELSE 2 END,
            r.RUL_SEQ_NO
    ),
    QuantityBreak AS (
        SELECT TOP 1
            b.AMT_OR_PCT,
            b.PRC_METH,
            b.PRC_BASIS,
            b.MIN_QTY
        FROM MatchingRule mr
        INNER JOIN dbo.IM_PRC_RUL_BRK b ON b.GRP_COD = mr.GRP_COD AND b.RUL_SEQ_NO = mr.RUL_SEQ_NO
        WHERE b.MIN_QTY <= @QUANTITY
        ORDER BY b.MIN_QTY DESC
    ),
    RegularPrice AS (
        SELECT 
            CASE qb.PRC_BASIS
                WHEN '1' THEN p.PRC_1
                WHEN '2' THEN p.PRC_2
                WHEN '3' THEN p.PRC_3
                WHEN 'R' THEN p.REG_PRC
                ELSE p.REG_PRC
            END AS BASE_PRICE
        FROM dbo.IM_PRC p
        CROSS JOIN QuantityBreak qb
        WHERE p.ITEM_NO = @ITEM_NO
          AND p.LOC_ID = @LOC_ID
    )
    SELECT 
        CASE qb.PRC_METH
            WHEN 'D' THEN rp.BASE_PRICE * (1 - qb.AMT_OR_PCT / 100)  -- Discount %
            WHEN 'O' THEN qb.AMT_OR_PCT                               -- Override (fixed price)
            WHEN 'M' THEN rp.BASE_PRICE * (1 + qb.AMT_OR_PCT / 100)  -- Markup %
            WHEN 'A' THEN rp.BASE_PRICE - qb.AMT_OR_PCT             -- Amount off
            ELSE rp.BASE_PRICE
        END AS CONTRACT_PRICE,
        rp.BASE_PRICE AS REGULAR_PRICE,
        CASE qb.PRC_METH
            WHEN 'D' THEN qb.AMT_OR_PCT
            ELSE NULL
        END AS DISCOUNT_PCT,
        qb.PRC_METH AS PRICING_METHOD,
        mr.RULE_DESCR,
        qb.MIN_QTY AS APPLIED_QTY_BREAK,
        @QUANTITY AS REQUESTED_QUANTITY
    FROM MatchingRule mr
    CROSS JOIN QuantityBreak qb
    CROSS JOIN RegularPrice rp
    WHERE mr.GRP_COD IS NOT NULL  -- Only return if rule found
);
GO

-- ============================================
-- Test the Function
-- ============================================
-- Example usage:
--
-- SELECT * FROM dbo.fn_GetContractPrice('144319', '01-10100', 10, '01');
-- SELECT * FROM dbo.fn_GetContractPrice('144319', '01-10100', 50, '01');
-- SELECT * FROM dbo.fn_GetContractPrice('144319', '01-10100', 100, '01');
--
-- Returns NULL if no contract applies

PRINT 'Contract price calculation function created successfully!';
PRINT 'Use: SELECT * FROM dbo.fn_GetContractPrice(@NCR_BID_NO, @ITEM_NO, @QUANTITY, @LOC_ID)';
GO


-- ============================================
-- FIND FAILED ORDERS (Dead Letter Queue)
-- ============================================
-- Purpose: Find orders that have failed validation/processing
--          and need manual review
-- ============================================

USE WOODYS_CP;
GO

PRINT '============================================';
PRINT 'FAILED ORDERS - NEEDS MANUAL REVIEW';
PRINT '============================================';
PRINT '';

-- Find orders with validation errors
SELECT 
    STAGING_ID,
    WOO_ORDER_ID,
    WOO_ORDER_NO,
    CUST_NO,
    CUST_EMAIL,
    ORD_DAT,
    TOT_AMT,
    VALIDATION_ERROR,
    CREATED_DT,
    DATEDIFF(HOUR, CREATED_DT, GETDATE()) AS HoursOld,
    CASE 
        WHEN DATEDIFF(HOUR, CREATED_DT, GETDATE()) > 24 THEN 'CRITICAL - Over 24 hours old'
        WHEN DATEDIFF(HOUR, CREATED_DT, GETDATE()) > 6 THEN 'WARNING - Over 6 hours old'
        ELSE 'INFO - Recent failure'
    END AS Priority
FROM dbo.USER_ORDER_STAGING
WHERE IS_APPLIED = 0
  AND VALIDATION_ERROR IS NOT NULL
ORDER BY CREATED_DT ASC;

PRINT '';
PRINT '============================================';
PRINT 'SUMMARY';
PRINT '============================================';
PRINT '';

SELECT 
    COUNT(*) AS TotalFailed,
    COUNT(CASE WHEN DATEDIFF(HOUR, CREATED_DT, GETDATE()) > 24 THEN 1 END) AS Critical_Over24Hours,
    COUNT(CASE WHEN DATEDIFF(HOUR, CREATED_DT, GETDATE()) > 6 THEN 1 END) AS Warning_Over6Hours,
    MIN(CREATED_DT) AS OldestFailure,
    MAX(CREATED_DT) AS NewestFailure
FROM dbo.USER_ORDER_STAGING
WHERE IS_APPLIED = 0
  AND VALIDATION_ERROR IS NOT NULL;

PRINT '';
PRINT '============================================';
PRINT 'COMMON ERROR TYPES';
PRINT '============================================';
PRINT '';

SELECT 
    LEFT(VALIDATION_ERROR, 50) AS ErrorType,
    COUNT(*) AS Count
FROM dbo.USER_ORDER_STAGING
WHERE IS_APPLIED = 0
  AND VALIDATION_ERROR IS NOT NULL
GROUP BY LEFT(VALIDATION_ERROR, 50)
ORDER BY Count DESC;

PRINT '';
PRINT '============================================';
PRINT 'ACTIONS';
PRINT '============================================';
PRINT '';
PRINT 'To review a specific order:';
PRINT '  python cp_order_processor.py show <STAGING_ID>';
PRINT '';
PRINT 'To retry a failed order:';
PRINT '  python cp_order_processor.py process <STAGING_ID>';
PRINT '';
PRINT 'To retry all failed orders:';
PRINT '  python cp_order_processor.py process --all';
PRINT '';
PRINT 'To fix and retry:';
PRINT '  1. Review VALIDATION_ERROR message';
PRINT '  2. Fix the issue in USER_ORDER_STAGING';
PRINT '  3. Clear VALIDATION_ERROR: UPDATE USER_ORDER_STAGING SET VALIDATION_ERROR = NULL WHERE STAGING_ID = <ID>';
PRINT '  4. Retry: python cp_order_processor.py process <STAGING_ID>';
PRINT '';

GO

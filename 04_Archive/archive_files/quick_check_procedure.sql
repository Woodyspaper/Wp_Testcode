-- ============================================
-- Quick Check: Does Procedure Have the Fix?
-- ============================================

USE WOODYS_CP;  -- or CPPractice if testing
GO

-- Check the procedure definition to see the default value
-- We'll search the procedure text for the default value
DECLARE @ProcText NVARCHAR(MAX);
SELECT @ProcText = OBJECT_DEFINITION(OBJECT_ID('dbo.usp_Create_Customers_From_Staging'));

PRINT 'Checking procedure definition for @DefaultTAX_COD...';
PRINT '';

-- Extract the line with @DefaultTAX_COD
IF @ProcText LIKE '%@DefaultTAX_COD%'
BEGIN
    DECLARE @StartPos INT = CHARINDEX('@DefaultTAX_COD', @ProcText);
    DECLARE @EndPos INT = CHARINDEX(CHAR(13) + CHAR(10), @ProcText, @StartPos);
    IF @EndPos = 0 SET @EndPos = CHARINDEX(CHAR(10), @ProcText, @StartPos);
    IF @EndPos = 0 SET @EndPos = LEN(@ProcText);
    
    DECLARE @Line NVARCHAR(500) = SUBSTRING(@ProcText, @StartPos, @EndPos - @StartPos);
    
    PRINT 'Found this line in procedure:';
    PRINT @Line;
    PRINT '';
    
    -- Check for the actual value (not the comment)
    -- Look for the pattern: = 'FL-BROWAR' or = 'FL-BROWARD'
    IF @Line LIKE '%= ''FL-BROWARD''%' OR @Line LIKE '%= ''FL-BROWARD'',%'
    BEGIN
        PRINT '❌ PROBLEM: Procedure still has ''FL-BROWARD'' (11 chars)';
        PRINT '   Need to recreate procedure with ''FL-BROWAR'' (10 chars)';
    END
    ELSE IF @Line LIKE '%= ''FL-BROWAR''%' OR @Line LIKE '%= ''FL-BROWAR'',%'
    BEGIN
        PRINT '✅ GOOD: Procedure has ''FL-BROWAR'' (10 chars) - FIXED!';
        PRINT '   The truncation error should be resolved.';
        PRINT '   If you still get truncation, it''s a different field.';
    END
    ELSE
    BEGIN
        PRINT '⚠️ Could not determine default value from procedure text.';
    END
END
ELSE
BEGIN
    PRINT '❌ Could not find @DefaultTAX_COD in procedure definition.';
END
GO


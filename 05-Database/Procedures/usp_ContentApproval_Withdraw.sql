-- ============================================================
-- SP 3: usp_ContentApproval_Withdraw
-- Submitter cancels a pending approval back to 'withdrawn'.
-- Content tables are never touched here (they never held 'pending').
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_ContentApproval_Withdraw]
    @ApprovalId   INT,
    @CallerUserId VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ContentType VARCHAR(50);
    DECLARE @ContentId   BIGINT;
    DECLARE @ActionType  VARCHAR(10);

    SELECT @ContentType = [content_type], @ContentId = [content_id], @ActionType = [action_type]
    FROM   [dbo].[content_approval]
    WHERE  [id]           = @ApprovalId
      AND  [status]       IN ('pending', 'rejected')
      AND  [submitted_by] = TRY_CAST(@CallerUserId AS UNIQUEIDENTIFIER);

    IF @ContentType IS NULL
    BEGIN
        SELECT 0 AS AffectedRows;
        RETURN;
    END

    BEGIN TRANSACTION;

    IF @ActionType = 'create'
    BEGIN
        -- Draft with no live equivalent — delete the ca record entirely (returns to Flow A)
        DELETE FROM [dbo].[content_approval] WHERE [id] = @ApprovalId;
    END
    ELSE
    BEGIN
        -- Edit or delete proposal on live approved content — restore approved state (returns to Flow B)
        UPDATE [dbo].[content_approval]
        SET    [status]        = 'approved',
               [modified_by]   = @CallerUserId,
               [modified_time] = SYSUTCDATETIME()
        WHERE  [id] = @ApprovalId;
    END

    COMMIT TRANSACTION;

    SELECT 1 AS AffectedRows;
END

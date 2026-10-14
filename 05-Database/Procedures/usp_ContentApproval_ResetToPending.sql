-- ============================================================
-- SP 10: usp_ContentApproval_ResetToPending
-- Compensation SP: called when edit/delete apply fails after
-- the Decide SP already set status='approved'. Resets the
-- record back to pending so the approver can retry.
-- Only acts when current status='approved' (idempotent guard).
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_ContentApproval_ResetToPending]
    @ApprovalId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    UPDATE [dbo].[content_approval]
    SET    [status]     = 'pending',
           [decided_at] = NULL,
           [decided_by] = NULL
    WHERE  [id] = @ApprovalId AND [status] = 'approved';

    COMMIT TRANSACTION;
END

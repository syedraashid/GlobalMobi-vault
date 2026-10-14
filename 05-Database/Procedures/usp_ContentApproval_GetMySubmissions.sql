-- ============================================================
-- SP 6: usp_ContentApproval_GetMySubmissions
-- All approval records where caller is the submitter (all statuses).
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_ContentApproval_GetMySubmissions]
    @SpaceId      INT,
    @CallerUserId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        ca.[id]               AS ApprovalId,
        ca.[space_id]         AS SpaceId,
        ca.[content_type]     AS ContentType,
        ca.[content_id]       AS ContentId,
        ca.[content_name]     AS ContentName,
        ca.[status]           AS Status,
        ca.[submitted_at]     AS SubmittedAt,
        ca.[decided_at]       AS DecidedAt,
        ca.[rejection_reason] AS RejectionReason,
        u.[display_name]      AS DecidedByName,
        ca.[action_type]      AS ActionType
    FROM  [dbo].[content_approval] ca
    LEFT JOIN [dbo].[user]         u  ON u.[id] = ca.[decided_by]
    WHERE ca.[space_id]     = @SpaceId
      AND ca.[submitted_by]  = @CallerUserId
    ORDER BY ca.[submitted_at] DESC;
END

-- ============================================================
-- SP 8: usp_ContentApproval_GetByContent
-- Returns the single approval record for a content item.
-- Used by IsParentBlockedAsync and other gate checks.
-- Returns TOP 1 ordered by submitted_at DESC (latest record wins).
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_ContentApproval_GetByContent]
    @ContentType VARCHAR(50),
    @ContentId   BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1
        ca.[id]                AS ApprovalId,
        ca.[space_id]          AS SpaceId,
        ca.[content_type]      AS ContentType,
        ca.[content_id]        AS ContentId,
        ca.[content_name]      AS ContentName,
        ca.[submitted_by]      AS SubmittedBy,
        ca.[last_edited_by]    AS LastEditedBy,
        ca.[status]            AS Status,
        ca.[submitted_at]      AS SubmittedAt,
        ca.[action_type]       AS ActionType,
        ca.[rejection_reason]  AS RejectionReason,
        ca.[proposed_data]     AS ProposedData,
        ca.[current_snapshot]  AS CurrentSnapshot,
        ca.[proposed_snapshot] AS ProposedSnapshot
    FROM [dbo].[content_approval] ca
    WHERE ca.[content_type] = @ContentType
      AND ca.[content_id]   = @ContentId
    ORDER BY ca.[submitted_at] DESC;
END

-- ============================================================
-- SP 7: usp_ContentApproval_GetById
-- Single record used for guard validation before approve/reject.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_ContentApproval_GetById]
    @ApprovalId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
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
    FROM  [dbo].[content_approval] ca
    WHERE ca.[id] = @ApprovalId;
END

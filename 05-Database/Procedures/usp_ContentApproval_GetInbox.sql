-- ============================================================
-- SP 5: usp_ContentApproval_GetInbox
-- Pending approvals for a space that the caller did NOT submit/last-edit.
-- Role filtering applied in C# (ApproverResolutionService).
-- DEMO_USER: @IncludeOwn BIT added — when 1, returns all pending including caller's own
--            submissions (used for demo_user who can self-approve). Revert: remove
--            @IncludeOwn param and restore the two-line AND filter below.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_ContentApproval_GetInbox]
    @SpaceId      INT,
    @CallerUserId UNIQUEIDENTIFIER,
    @IncludeOwn   BIT = 0  -- DEMO_USER: revert this param
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        ca.[id]               AS ApprovalId,
        ca.[space_id]         AS SpaceId,
        ca.[content_type]     AS ContentType,
        ca.[content_id]       AS ContentId,
        ca.[content_name]     AS ContentName,
        ca.[submitted_by]     AS SubmittedByUserId,
        u.[display_name]      AS SubmittedByName,
        ca.[submitted_at]     AS SubmittedAt,
        ca.[last_edited_by]   AS LastEditedByUserId,
        ca.[action_type]      AS ActionType
    FROM  [dbo].[content_approval] ca
    JOIN  [dbo].[user]             u  ON u.[id] = ca.[submitted_by]
    WHERE ca.[space_id]     = @SpaceId
      AND ca.[status]       = 'pending'
      -- DEMO_USER: revert this block — restore original two-line filter:
      --   AND ca.[submitted_by] <> @CallerUserId
      --   AND (ca.[last_edited_by] IS NULL OR ca.[last_edited_by] <> @CallerUserId)
      AND (@IncludeOwn = 1 OR (
              ca.[submitted_by] <> @CallerUserId
          AND (ca.[last_edited_by] IS NULL OR ca.[last_edited_by] <> @CallerUserId)
      ))
      -- END DEMO_USER
    ORDER BY ca.[submitted_at] ASC;
END

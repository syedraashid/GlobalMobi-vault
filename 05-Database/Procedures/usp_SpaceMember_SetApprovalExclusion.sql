------------------------------------------------------------------------
-- 4) usp_SpaceMember_SetApprovalExclusion — flips the toggle, records who/when
------------------------------------------------------------------------
CREATE   PROCEDURE [dbo].[usp_SpaceMember_SetApprovalExclusion]
    @SpaceId    INT,
    @UserId     UNIQUEIDENTIFIER,
    @IsExcluded BIT,
    @ChangedBy  VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.space_member
    SET is_excluded_from_approval     = @IsExcluded,
        approval_exclusion_changed_by = @ChangedBy,
        approval_exclusion_changed_at = SYSUTCDATETIME()
    WHERE space_id = @SpaceId
      AND user_id  = @UserId
      AND is_deleted = 0;
END

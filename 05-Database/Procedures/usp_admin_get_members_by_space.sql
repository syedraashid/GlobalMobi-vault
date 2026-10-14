------------------------------------------------------------------------
-- 3) usp_admin_get_members_by_space — surface the toggle's state + audit info
------------------------------------------------------------------------
CREATE   PROCEDURE [dbo].[usp_admin_get_members_by_space]
    @SpaceId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.[id]                              AS UserId,
        u.[display_name]                    AS Name,
        u.[email]                           AS Email,
        u.[entity_id]                       AS EntityId,
        r.[name]                            AS RoleName,
        smr.[role_id]                       AS RoleId,
        sm.[joined_at]                      AS AssignedAt,
        ISNULL(sp.[display_name], '')       AS SpaceName,
        sm.[is_excluded_from_approval]      AS IsExcludedFromApproval,
        sm.[approval_exclusion_changed_by]  AS ApprovalExclusionChangedBy,
        chgu.[display_name]                 AS ApprovalExclusionChangedByName,
        sm.[approval_exclusion_changed_at]  AS ApprovalExclusionChangedAt
    FROM   dbo.space_member sm
    JOIN   dbo.[user] u
        ON     u.[id] = sm.[user_id]
        AND    u.[is_deleted] = 0
    JOIN   dbo.space_member_role smr
        ON     smr.[space_member_id] = sm.[id]
    JOIN   dbo.[role] r
        ON     r.[id] = smr.[role_id]
        AND    r.[is_deleted] = 0
    LEFT JOIN dbo.space sp
        ON     sp.[id] = sm.[space_id]
    LEFT JOIN dbo.[user] chgu
        ON     chgu.[id] = TRY_CAST(sm.[approval_exclusion_changed_by] AS UNIQUEIDENTIFIER)
    WHERE  (@SpaceId IS NULL OR sm.[space_id] = @SpaceId)
        AND sm.[is_deleted] = 0
    ORDER BY sm.[joined_at] ASC, r.[name] ASC;
END

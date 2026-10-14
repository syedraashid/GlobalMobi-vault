------------------------------------------------------------------------
-- 2) usp_ContentApproval_GetSpaceMembersWithRoles — exclude flagged members
------------------------------------------------------------------------
CREATE   PROCEDURE [dbo].[usp_ContentApproval_GetSpaceMembersWithRoles]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        sm.[user_id]         AS UserId,
        u.[display_name]     AS DisplayName,
        r.[name]             AS Role
    FROM   dbo.space_member      sm
    JOIN   dbo.[user]            u   ON u.[id] = sm.[user_id]
    JOIN   dbo.space_member_role smr ON smr.[space_member_id] = sm.[id]
    JOIN   dbo.[role]            r   ON r.[id] = smr.[role_id]
                                      AND r.[is_deleted] = 0
    WHERE  sm.[space_id]     = @SpaceId
        AND sm.[is_deleted]  = 0
        AND u.[is_deleted]   = 0
        AND sm.[is_excluded_from_approval] = 0
    ORDER BY sm.[user_id];
END

-- ------------------------------------------------------------
-- 2. usp_admin_get_pending_invitations_by_space
--    Adds pi.[name] AS Name to the SELECT list.
-- ------------------------------------------------------------
CREATE   PROCEDURE [dbo].[usp_admin_get_pending_invitations_by_space]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        pi.[id]                      AS Id,
        pi.[name]                    AS Name,
        pi.[email]                   AS Email,
        pi.[role_id]                 AS RoleId,
        r.[name]                     AS RoleName,
        ISNULL(u.[display_name], '') AS InvitedByName,
        pi.[created_time]            AS CreatedTime,
        pi.[expires_at]              AS ExpiresAt
    FROM  [dbo].[pending_invitation] pi
    JOIN  [dbo].[role] r
        ON  r.[id]         = pi.[role_id]
        AND r.[is_deleted] = 0
    LEFT JOIN [dbo].[user] u
        ON  u.[id] = pi.[invited_by]
    WHERE pi.[space_id]    = @SpaceId
      AND pi.[accepted_at] IS NULL
      AND pi.[is_deleted]  = 0
      AND pi.[expires_at]  > GETUTCDATE()
    ORDER BY pi.[created_time] DESC;
END

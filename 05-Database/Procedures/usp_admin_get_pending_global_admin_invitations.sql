-- ============================================================
-- SECTION 3: usp_admin_get_pending_global_admin_invitations
--
-- Lists unexpired, unaccepted, unrevoked global_admin invitations.
-- Scoped to r.[name] = 'global_admin' so gms_accountant rows
-- (which share space_id IS NULL / entity_id IS NULL) are excluded.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_admin_get_pending_global_admin_invitations]
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
        AND r.[name]       = 'global_admin'
        AND r.[is_deleted] = 0
    LEFT JOIN [dbo].[user] u
        ON  u.[id] = pi.[invited_by]
    WHERE pi.[space_id]    IS NULL
      AND pi.[entity_id]   IS NULL
      AND pi.[accepted_at] IS NULL
      AND pi.[is_deleted]  = 0
      AND pi.[expires_at]  > GETUTCDATE()
    ORDER BY pi.[created_time] DESC;
END

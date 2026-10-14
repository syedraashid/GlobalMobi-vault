-- =============================================================================
-- 2. usp_admin_get_pending_entity_admin_invitations
-- Returns open entity_admin invitations for a given entity.
-- Identified by: entity_id = @EntityId, space_id IS NULL,
-- role = entity_admin, not accepted, not deleted, not expired.
-- AdminSql.cs: GetPendingEntityAdminInvitations
-- =============================================================================
CREATE   PROCEDURE [dbo].[usp_admin_get_pending_entity_admin_invitations]
    @EntityId INT
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
        AND r.[name]       = 'entity_admin'
        AND r.[is_deleted] = 0
    LEFT JOIN [dbo].[user] u
        ON  u.[id] = pi.[invited_by]
    WHERE pi.[entity_id]   = @EntityId
      AND pi.[space_id]    IS NULL
      AND pi.[accepted_at] IS NULL
      AND pi.[is_deleted]  = 0
      AND pi.[expires_at]  > GETUTCDATE()
    ORDER BY pi.[created_time] DESC;
END;

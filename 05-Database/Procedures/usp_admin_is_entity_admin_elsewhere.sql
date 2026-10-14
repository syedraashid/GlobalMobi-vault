-- ---------------------------------------------------------------------
-- dbo.usp_admin_is_entity_admin_elsewhere
-- ---------------------------------------------------------------------
-- Returns 1 when @Email is already an entity_admin (active user, or an
-- unexpired pending invitation) of a DIFFERENT entity than @EntityId.
-- Same-entity is not a conflict (re-inviting/re-confirming your own
-- entity's admin is fine); only the cross-entity case is blocked.
-- ---------------------------------------------------------------------
CREATE PROCEDURE [dbo].[usp_admin_is_entity_admin_elsewhere]
    @Email    VARCHAR(256),
    @EntityId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CAST(
        CASE WHEN EXISTS (
            SELECT 1 FROM [dbo].[user] u
            JOIN [dbo].[role] r ON r.[id] = u.[system_role_id] AND r.[is_deleted] = 0
            WHERE u.[email] = @Email AND u.[is_deleted] = 0
              AND r.[name] = 'entity_admin'
              AND u.[entity_id] <> @EntityId
        ) OR EXISTS (
            SELECT 1 FROM [dbo].[pending_invitation] pi
            JOIN [dbo].[role] r ON r.[id] = pi.[role_id] AND r.[is_deleted] = 0
            WHERE pi.[email]       = @Email
              AND pi.[accepted_at] IS NULL
              AND pi.[is_deleted]  = 0
              AND pi.[expires_at]  > GETUTCDATE()
              AND r.[name]         = 'entity_admin'
              AND pi.[entity_id]  <> @EntityId
        ) THEN 1 ELSE 0 END
    AS BIT);
END

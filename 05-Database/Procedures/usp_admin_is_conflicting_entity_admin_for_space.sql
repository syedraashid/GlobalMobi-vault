CREATE   PROCEDURE [dbo].[usp_admin_is_conflicting_entity_admin_for_space]
    @Email   VARCHAR(256),
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SpaceEntityId INT = (SELECT [entity_id] FROM [dbo].[space] WHERE [id] = @SpaceId);

    SELECT CAST(
        CASE WHEN EXISTS (
            SELECT 1 FROM [dbo].[user] u
            JOIN [dbo].[role] r ON r.[id] = u.[system_role_id] AND r.[is_deleted] = 0
            WHERE u.[email] = @Email AND u.[is_deleted] = 0
              AND r.[name] = 'entity_admin'
              AND u.[entity_id] <> @SpaceEntityId
        ) OR EXISTS (
            SELECT 1 FROM [dbo].[pending_invitation] pi
            JOIN [dbo].[role] r ON r.[id] = pi.[role_id] AND r.[is_deleted] = 0
            WHERE pi.[email]       = @Email
              AND pi.[accepted_at] IS NULL
              AND pi.[is_deleted]  = 0
              AND pi.[expires_at]  > GETUTCDATE()
              AND r.[name]         = 'entity_admin'
              AND pi.[entity_id]  <> @SpaceEntityId
        ) THEN 1 ELSE 0 END
    AS BIT);
END

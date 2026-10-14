CREATE   PROCEDURE [dbo].[usp_admin_get_pending_invitation_by_email]
    @Email VARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1
        pi.[space_id]  AS SpaceId,
        pi.[entity_id] AS EntityId,
        pi.[role_id]   AS RoleId,
        pi.[email]     AS Email,
        pi.[name]      AS Name
    FROM  [dbo].[pending_invitation] pi
    WHERE pi.[email]       = @Email
      AND pi.[accepted_at] IS NULL
      AND pi.[is_deleted]  = 0
      AND pi.[expires_at]  > GETUTCDATE()
    ORDER BY pi.[id] DESC;
END

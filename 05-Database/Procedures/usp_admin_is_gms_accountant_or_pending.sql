CREATE   PROCEDURE [dbo].[usp_admin_is_gms_accountant_or_pending]
    @Email VARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CAST(
        CASE WHEN EXISTS (
            SELECT 1 FROM [dbo].[user] u
            JOIN [dbo].[role] r ON r.[id] = u.[system_role_id] AND r.[is_deleted] = 0
            WHERE u.[email] = @Email AND u.[is_deleted] = 0 AND r.[name] = 'gms_accountant'
        ) OR EXISTS (
            SELECT 1 FROM [dbo].[pending_invitation] pi
            JOIN [dbo].[role] r ON r.[id] = pi.[role_id] AND r.[is_deleted] = 0
            WHERE pi.[email]       = @Email
              AND pi.[accepted_at] IS NULL
              AND pi.[is_deleted]  = 0
              AND pi.[expires_at]  > GETUTCDATE()
              AND r.[name]         = 'gms_accountant'
        ) THEN 1 ELSE 0 END
    AS BIT);
END

CREATE   PROCEDURE [dbo].[usp_admin_has_any_space_membership_or_pending]
    @Email VARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CAST(
        CASE WHEN EXISTS (
            SELECT 1 FROM [dbo].[space_member] sm
            JOIN [dbo].[user] u ON u.[id] = sm.[user_id]
            WHERE u.[email] = @Email AND u.[is_deleted] = 0 AND sm.[is_deleted] = 0
        ) OR EXISTS (
            SELECT 1 FROM [dbo].[pending_invitation] pi
            WHERE pi.[email]       = @Email
              AND pi.[space_id]    IS NOT NULL
              AND pi.[accepted_at] IS NULL
              AND pi.[is_deleted]  = 0
              AND pi.[expires_at]  > GETUTCDATE()
        ) THEN 1 ELSE 0 END
    AS BIT);
END

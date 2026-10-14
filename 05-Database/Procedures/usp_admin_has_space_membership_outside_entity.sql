CREATE   PROCEDURE [dbo].[usp_admin_has_space_membership_outside_entity]
    @Email    VARCHAR(256),
    @EntityId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CAST(
        CASE WHEN EXISTS (
            SELECT 1
            FROM [dbo].[space_member] sm
            JOIN [dbo].[user] u   ON u.[id] = sm.[user_id]
            JOIN [dbo].[space] sp ON sp.[id] = sm.[space_id]
            WHERE u.[email] = @Email AND u.[is_deleted] = 0 AND sm.[is_deleted] = 0
              AND sp.[entity_id] <> @EntityId
        ) OR EXISTS (
            SELECT 1
            FROM [dbo].[pending_invitation] pi
            JOIN [dbo].[space] sp ON sp.[id] = pi.[space_id]
            WHERE pi.[email]       = @Email
              AND pi.[space_id]    IS NOT NULL
              AND pi.[accepted_at] IS NULL
              AND pi.[is_deleted]  = 0
              AND pi.[expires_at]  > GETUTCDATE()
              AND sp.[entity_id]  <> @EntityId
        ) THEN 1 ELSE 0 END
    AS BIT);
END

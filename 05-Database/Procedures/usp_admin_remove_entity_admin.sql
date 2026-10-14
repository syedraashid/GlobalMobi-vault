-- =============================================================================
-- 4. usp_admin_remove_entity_admin
-- Strips the entity_admin role from a user (clears system_role_id + entity_id).
-- Returns HasActiveSpaces BIT — if 1, user still has space memberships and the
-- caller can offer permanent account deletion instead.
-- AdminSql.cs: RemoveEntityAdmin
-- =============================================================================
CREATE   PROCEDURE [dbo].[usp_admin_remove_entity_admin]
    @EntityId   INT,
    @UserId     UNIQUEIDENTIFIER,
    @ModifiedBy VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [dbo].[user]
    SET    [system_role_id] = NULL,
           [entity_id]      = NULL,
           [modified_time]  = GETUTCDATE(),
           [modified_by]    = @ModifiedBy
    WHERE  [id]         = @UserId
      AND  [entity_id]  = @EntityId
      AND  [is_deleted] = 0;

    SELECT CAST(CASE WHEN EXISTS (
        SELECT 1 FROM [dbo].[space_member]
        WHERE  [user_id]    = @UserId
          AND  [is_deleted] = 0
    ) THEN 1 ELSE 0 END AS BIT) AS HasActiveSpaces;
END;

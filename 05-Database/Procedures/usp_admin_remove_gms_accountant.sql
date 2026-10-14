-- =============================================================================
-- 6. usp_admin_remove_gms_accountant
-- Strips the gms_accountant role from a user (clears system_role_id).
-- Returns HasActiveSpaces BIT — if 1, user still has space memberships.
-- AdminSql.cs: RemoveGmsAccountant
-- =============================================================================
CREATE   PROCEDURE [dbo].[usp_admin_remove_gms_accountant]
    @UserId     UNIQUEIDENTIFIER,
    @ModifiedBy VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @GmsRoleId INT;
    SELECT  @GmsRoleId = [id] FROM [dbo].[role]
    WHERE   [name] = 'gms_accountant' AND [is_deleted] = 0;

    UPDATE [dbo].[user]
    SET    [system_role_id] = NULL,
           [modified_time]  = GETUTCDATE(),
           [modified_by]    = @ModifiedBy
    WHERE  [id]             = @UserId
      AND  [system_role_id] = @GmsRoleId
      AND  [is_deleted]     = 0;

    SELECT CAST(CASE WHEN EXISTS (
        SELECT 1 FROM [dbo].[space_member]
        WHERE  [user_id]    = @UserId
          AND  [is_deleted] = 0
    ) THEN 1 ELSE 0 END AS BIT) AS HasActiveSpaces;
END;

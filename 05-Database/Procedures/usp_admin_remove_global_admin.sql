-- ============================================================
-- SECTION 6: usp_admin_remove_global_admin
--
-- Demotes a global_admin: clears system_role_id and entity_id.
-- Does NOT delete the user or their space memberships.
-- Returns HasActiveSpaces BIT so the caller can show a warning.
-- Mirrors the expected shape of usp_admin_remove_gms_accountant.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_admin_remove_global_admin]
    @UserId     UNIQUEIDENTIFIER,
    @ModifiedBy VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @HasActiveSpaces BIT = 0;

    IF EXISTS (
        SELECT 1 FROM [dbo].[space_member]
        WHERE  [user_id]    = @UserId
          AND  [is_deleted] = 0
    )
        SET @HasActiveSpaces = 1;

    UPDATE [dbo].[user]
    SET    [system_role_id] = NULL,
           [entity_id]      = NULL,
           [modified_time]  = GETUTCDATE(),
           [modified_by]    = @ModifiedBy
    WHERE  [id]         = @UserId
      AND  [is_deleted] = 0;

    SELECT @HasActiveSpaces AS HasActiveSpaces;
END

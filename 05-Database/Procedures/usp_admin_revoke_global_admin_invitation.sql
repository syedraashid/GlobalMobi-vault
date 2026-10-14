-- ============================================================
-- SECTION 4: usp_admin_revoke_global_admin_invitation
--
-- Soft-deletes a pending global_admin invitation.
-- [role_id] filter is a defense-in-depth guard: prevents this SP
-- from accidentally revoking a gms_accountant invitation even if
-- the caller passes a matching id (both share space_id/entity_id IS NULL).
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_admin_revoke_global_admin_invitation]
    @InvitationId INT,
    @ModifiedBy   VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @GlobalAdminRoleId INT;
    SELECT @GlobalAdminRoleId = [id]
    FROM   [dbo].[role]
    WHERE  [name] = 'global_admin' AND [is_deleted] = 0;

    UPDATE [dbo].[pending_invitation]
    SET    [is_deleted]    = 1,
           [modified_time] = GETUTCDATE(),
           [modified_by]   = @ModifiedBy
    WHERE  [id]          = @InvitationId
      AND  [role_id]     = @GlobalAdminRoleId
      AND  [space_id]    IS NULL
      AND  [entity_id]   IS NULL
      AND  [accepted_at] IS NULL
      AND  [is_deleted]  = 0;
END

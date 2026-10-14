-- Revokes (soft-deletes) a pending GMS Accountant invitation.
-- Scoped to space_id IS NULL + entity_id IS NULL as a defense-in-depth check
-- so this SP cannot accidentally revoke a space-member or entity-admin invitation.
CREATE   PROCEDURE [dbo].[usp_admin_revoke_gms_accountant_invitation]
    @InvitationId INT,
    @ModifiedBy   VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE [dbo].[pending_invitation]
    SET    [is_deleted]    = 1,
           [modified_time] = GETUTCDATE(),
           [modified_by]   = @ModifiedBy
    WHERE  [id]          = @InvitationId
      AND  [space_id]    IS NULL
      AND  [entity_id]   IS NULL
      AND  [accepted_at] IS NULL
      AND  [is_deleted]  = 0;
END

-- =============================================================================
-- 3. usp_admin_revoke_entity_admin_invitation
-- Soft-deletes a pending entity_admin invitation.
-- Scoped to entity_id + space_id IS NULL as a safety check so it cannot
-- accidentally revoke a space-member or gms_accountant invitation.
-- AdminSql.cs: RevokeEntityAdminInvitation
-- =============================================================================
CREATE   PROCEDURE [dbo].[usp_admin_revoke_entity_admin_invitation]
    @EntityId     INT,
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
      AND  [entity_id]   = @EntityId
      AND  [space_id]    IS NULL
      AND  [accepted_at] IS NULL
      AND  [is_deleted]  = 0;
END;

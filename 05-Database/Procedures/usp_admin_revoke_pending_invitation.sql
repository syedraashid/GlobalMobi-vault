-- Revokes (soft-deletes) a pending invitation. No-op if already accepted/revoked
-- or if it belongs to a different space (defense in depth alongside route auth).
CREATE   PROCEDURE [dbo].[usp_admin_revoke_pending_invitation]
    @SpaceId      INT,
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
      AND  [space_id]    = @SpaceId
      AND  [accepted_at] IS NULL
      AND  [is_deleted]  = 0;
END

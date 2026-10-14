-- ============================================================
-- SP 12: usp_friend_notification_mark_all_read
-- Mark all unread notifications as read for a user in a space
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_friend_notification_mark_all_read]
    @RecipientId UNIQUEIDENTIFIER,
    @SpaceId     INT,
    @ModifiedBy  VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [dbo].[friend_notification]
    SET is_read       = 1,
        modified_time = SYSUTCDATETIME(),
        modified_by   = @ModifiedBy
    WHERE recipient_id = @RecipientId
      AND space_id     = @SpaceId
      AND is_read      = 0
      AND is_deleted   = 0;
END;

-- ============================================================
-- SP 11: usp_friend_notification_mark_read
-- Mark a single notification as read. Validates recipient ownership.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_friend_notification_mark_read]
    @NotificationId UNIQUEIDENTIFIER,
    @RecipientId    UNIQUEIDENTIFIER,
    @SpaceId        INT,
    @ModifiedBy     VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1 FROM [dbo].[friend_notification]
        WHERE id           = @NotificationId
          AND recipient_id = @RecipientId
          AND space_id     = @SpaceId
          AND is_deleted   = 0
    )
    BEGIN
        RAISERROR('Notification not found.', 16, 1);
        RETURN;
    END;

    UPDATE [dbo].[friend_notification]
    SET is_read       = 1,
        modified_time = SYSUTCDATETIME(),
        modified_by   = @ModifiedBy
    WHERE id           = @NotificationId
      AND recipient_id = @RecipientId;
END;

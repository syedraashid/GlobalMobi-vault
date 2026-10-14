-- ============================================================
-- SP 10: usp_friend_notification_get
-- Returns TWO result sets:
--   1st: UnreadCount (scalar)
--   2nd: Notification rows (paginated)
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_friend_notification_get]
    @RecipientId UNIQUEIDENTIFIER,
    @SpaceId     INT,
    @Limit       INT = 20,
    @Offset      INT = 0,
    @UnreadOnly  BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    -- Result set 1: unread count
    SELECT COUNT(*) AS UnreadCount
    FROM [dbo].[friend_notification]
    WHERE recipient_id = @RecipientId
      AND space_id     = @SpaceId
      AND is_read      = 0
      AND is_deleted   = 0;

    -- Result set 2: notification rows
    SELECT
        fn.id           AS NotificationId,
        fn.space_id     AS SpaceId,
        t.type_name     AS NotificationType,
        fn.sender_id    AS SenderId,
        u.username      AS SenderUsername,
        u.display_name  AS SenderDisplayName,
        u.avatar_id     AS SenderAvatarId,
        fn.reference_id AS ReferenceId,
        fn.is_read      AS IsRead,
        fn.created_at   AS CreatedAt
    FROM [dbo].[friend_notification] fn
    JOIN [dbo].[friend_notification_type] t ON t.id = fn.notification_type_id
    JOIN [dbo].[user] u ON u.id = fn.sender_id
    WHERE fn.recipient_id = @RecipientId
      AND fn.space_id     = @SpaceId
      AND fn.is_deleted   = 0
      AND u.is_deleted    = 0
      AND (@UnreadOnly = 0 OR fn.is_read = 0)
    ORDER BY fn.created_at DESC
    OFFSET @Offset ROWS FETCH NEXT @Limit ROWS ONLY;
END;

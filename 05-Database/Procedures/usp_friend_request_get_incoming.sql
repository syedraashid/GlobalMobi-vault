-- ============================================================
-- SP 4: usp_friend_request_get_incoming
-- All Pending requests received by a user in a space
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_friend_request_get_incoming]
    @ReceiverId UNIQUEIDENTIFIER,
    @SpaceId    INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        fr.id          AS RequestId,
        fr.space_id    AS SpaceId,
        fr.sender_id   AS SenderId,
        u.username     AS SenderUsername,
        u.display_name AS SenderDisplayName,
        u.avatar_id    AS SenderAvatarId,
        fr.sent_at     AS SentAt
    FROM [dbo].[friend_request] fr
    JOIN [dbo].[user] u ON u.id = fr.sender_id
    JOIN [dbo].[friend_request_status] s ON s.id = fr.status_id
    WHERE fr.receiver_id = @ReceiverId
      AND fr.space_id    = @SpaceId
      AND s.status       = 'Pending'
      AND fr.is_deleted  = 0
      AND u.is_deleted   = 0
    ORDER BY fr.sent_at DESC;
END;

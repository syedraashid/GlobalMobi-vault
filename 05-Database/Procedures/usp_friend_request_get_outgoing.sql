-- ============================================================
-- SP 5: usp_friend_request_get_outgoing
-- All Pending requests sent by a user in a space
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_friend_request_get_outgoing]
    @SenderId UNIQUEIDENTIFIER,
    @SpaceId  INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        fr.id           AS RequestId,
        fr.space_id     AS SpaceId,
        fr.receiver_id  AS ReceiverId,
        u.username      AS ReceiverUsername,
        u.display_name  AS ReceiverDisplayName,
        u.avatar_id     AS ReceiverAvatarId,
        fr.sent_at      AS SentAt
    FROM [dbo].[friend_request] fr
    JOIN [dbo].[user] u ON u.id = fr.receiver_id
    JOIN [dbo].[friend_request_status] s ON s.id = fr.status_id
    WHERE fr.sender_id  = @SenderId
      AND fr.space_id   = @SpaceId
      AND s.status      = 'Pending'
      AND fr.is_deleted = 0
      AND u.is_deleted  = 0
    ORDER BY fr.sent_at DESC;
END;

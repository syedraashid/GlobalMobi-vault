-- ============================================================
-- SP 6: usp_friend_request_get_by_id
-- Fetch a single request for ownership validation in service layer
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_friend_request_get_by_id]
    @RequestId UNIQUEIDENTIFIER,
    @SpaceId   INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        fr.id          AS RequestId,
        fr.space_id    AS SpaceId,
        fr.sender_id   AS SenderId,
        fr.receiver_id AS ReceiverId,
        s.status       AS Status,
        fr.sent_at     AS SentAt
    FROM [dbo].[friend_request] fr
    JOIN [dbo].[friend_request_status] s ON s.id = fr.status_id
    WHERE fr.id        = @RequestId
      AND fr.space_id  = @SpaceId
      AND fr.is_deleted = 0;
END;

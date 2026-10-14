CREATE   PROCEDURE [dbo].[usp_friend_request_send]
    @SenderId   UNIQUEIDENTIFIER,
    @ReceiverId UNIQUEIDENTIFIER,
    @SpaceId    INT,
    @ModifiedBy VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    -- Cannot send to yourself
    IF @SenderId = @ReceiverId
    BEGIN
        RAISERROR('Cannot send a friend request to yourself.', 16, 1);
        RETURN;
    END;

    -- Receiver must exist and be an immersive user: Microsoft identity (oid + tid) or Google identity (google_sub)
    IF NOT EXISTS (
        SELECT 1 FROM [dbo].[user]
        WHERE id = @ReceiverId
          AND ((oid IS NOT NULL AND tid IS NOT NULL) OR google_sub IS NOT NULL)
          AND is_deleted = 0
    )
    BEGIN
        RAISERROR('Receiver not found or not eligible.', 16, 2);
        RETURN;
    END;

    -- Already friends in this space
    DECLARE @A UNIQUEIDENTIFIER = CASE WHEN @SenderId < @ReceiverId THEN @SenderId ELSE @ReceiverId END;
    DECLARE @B UNIQUEIDENTIFIER = CASE WHEN @SenderId < @ReceiverId THEN @ReceiverId ELSE @SenderId END;

    IF EXISTS (
        SELECT 1 FROM [dbo].[friend]
        WHERE user_id_a = @A AND user_id_b = @B AND space_id = @SpaceId AND is_deleted = 0
    )
    BEGIN
        RAISERROR('Users are already friends in this space.', 16, 3);
        RETURN;
    END;

    -- Pending request already exists in either direction
    IF EXISTS (
        SELECT 1 FROM [dbo].[friend_request] fr
        JOIN [dbo].[friend_request_status] s ON s.id = fr.status_id
        WHERE fr.space_id   = @SpaceId
          AND fr.is_deleted = 0
          AND s.status      = 'Pending'
          AND (
                (fr.sender_id = @SenderId   AND fr.receiver_id = @ReceiverId) OR
                (fr.sender_id = @ReceiverId AND fr.receiver_id = @SenderId)
              )
    )
    BEGIN
        RAISERROR('A pending request already exists between these users.', 16, 4);
        RETURN;
    END;

    DECLARE @NewId UNIQUEIDENTIFIER = NEWID();

    INSERT INTO [dbo].[friend_request]
        ([id], [space_id], [sender_id], [receiver_id], [status_id], [modified_by])
    VALUES (
        @NewId,
        @SpaceId,
        @SenderId,
        @ReceiverId,
        (SELECT id FROM [dbo].[friend_request_status] WHERE status = 'Pending' AND is_deleted = 0),
        @ModifiedBy
    );

    SELECT
        fr.id           AS RequestId,
        fr.space_id     AS SpaceId,
        fr.sender_id    AS SenderId,
        fr.receiver_id  AS ReceiverId,
        u.username      AS ReceiverUsername,
        u.display_name  AS ReceiverDisplayName,
        u.avatar_id     AS ReceiverAvatarId,
        s.status        AS Status,
        fr.sent_at      AS SentAt
    FROM [dbo].[friend_request] fr
    JOIN [dbo].[user] u ON u.id = fr.receiver_id
    JOIN [dbo].[friend_request_status] s ON s.id = fr.status_id
    WHERE fr.id = @NewId;
END;

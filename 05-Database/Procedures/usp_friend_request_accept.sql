-- ============================================================
-- SP 7: usp_friend_request_accept
-- Transaction: update request + insert friend + insert notification
-- Returns friendship + friend user info
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_friend_request_accept]
    @RequestId  UNIQUEIDENTIFIER,
    @CallerId   UNIQUEIDENTIFIER,
    @SpaceId    INT,
    @ModifiedBy VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;

    BEGIN TRY
        DECLARE @SenderId   UNIQUEIDENTIFIER;
        DECLARE @ReceiverId UNIQUEIDENTIFIER;
        DECLARE @StatusName VARCHAR(32);

        SELECT
            @SenderId   = fr.sender_id,
            @ReceiverId = fr.receiver_id,
            @StatusName = s.status
        FROM [dbo].[friend_request] fr
        JOIN [dbo].[friend_request_status] s ON s.id = fr.status_id
        WHERE fr.id        = @RequestId
          AND fr.space_id  = @SpaceId
          AND fr.is_deleted = 0;

        IF @SenderId IS NULL
        BEGIN
            RAISERROR('Friend request not found.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        IF @ReceiverId <> @CallerId
        BEGIN
            RAISERROR('Only the receiver can accept this request.', 16, 2);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        IF @StatusName <> 'Pending'
        BEGIN
            RAISERROR('Friend request is no longer pending.', 16, 3);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- 1. Update request to Accepted
        UPDATE [dbo].[friend_request]
        SET status_id     = (SELECT id FROM [dbo].[friend_request_status] WHERE status = 'Accepted' AND is_deleted = 0),
            responded_at  = SYSUTCDATETIME(),
            modified_time = SYSUTCDATETIME(),
            modified_by   = @ModifiedBy
        WHERE id = @RequestId;

        -- 2. Insert or reactivate canonical friendship row
        DECLARE @FriendshipId UNIQUEIDENTIFIER;
        DECLARE @A UNIQUEIDENTIFIER = CASE WHEN @SenderId < @ReceiverId THEN @SenderId ELSE @ReceiverId END;
        DECLARE @B UNIQUEIDENTIFIER = CASE WHEN @SenderId < @ReceiverId THEN @ReceiverId ELSE @SenderId END;

        IF EXISTS (
            SELECT 1 FROM [dbo].[friend]
            WHERE user_id_a = @A AND user_id_b = @B AND space_id = @SpaceId AND is_deleted = 1
        )
        BEGIN
            -- Reactivate the previously-removed friendship (avoids UQ constraint violation on re-add)
            UPDATE [dbo].[friend]
            SET is_deleted    = 0,
                modified_time = SYSUTCDATETIME(),
                modified_by   = @ModifiedBy
            WHERE user_id_a = @A AND user_id_b = @B AND space_id = @SpaceId AND is_deleted = 1;

            SELECT @FriendshipId = id
            FROM   [dbo].[friend]
            WHERE  user_id_a = @A AND user_id_b = @B AND space_id = @SpaceId AND is_deleted = 0;
        END
        ELSE
        BEGIN
            SET @FriendshipId = NEWID();
            INSERT INTO [dbo].[friend] ([id], [space_id], [user_id_a], [user_id_b], [modified_by])
            VALUES (@FriendshipId, @SpaceId, @A, @B, @ModifiedBy);
        END

        -- 3. Notification for original sender
        INSERT INTO [dbo].[friend_notification]
            ([space_id], [recipient_id], [sender_id], [notification_type_id], [reference_id], [modified_by])
        VALUES (
            @SpaceId,
            @SenderId,
            @ReceiverId,
            (SELECT id FROM [dbo].[friend_notification_type] WHERE type_name = 'FriendRequestAccepted' AND is_deleted = 0),
            @RequestId,
            @ModifiedBy
        );

        COMMIT TRANSACTION;

        -- Return result to service layer
        SELECT
            f.id           AS FriendshipId,
            f.space_id     AS SpaceId,
            u.id           AS FriendUserId,
            u.username     AS FriendUsername,
            u.display_name AS FriendDisplayName,
            u.avatar_id    AS FriendAvatarId,
            CASE WHEN EXISTS (
                SELECT 1 FROM [dbo].[user_session_management] s
                WHERE s.user_id        = u.id
                  AND s.status_id      = 1
                  AND s.end_time       IS NULL
                  AND s.expiration_time > SYSUTCDATETIME()
                  AND s.space_id       = @SpaceId
                  AND s.is_deleted     = 0
            ) THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsOnline,
            f.created_at   AS FriendsSince,
            @SenderId      AS OriginalSenderId
        FROM [dbo].[friend] f
        JOIN [dbo].[user] u ON u.id = @SenderId
        WHERE f.id = @FriendshipId;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

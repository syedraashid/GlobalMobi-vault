-- ============================================================
-- SP 8: usp_friend_request_decline
-- Transaction: update request status + insert notification for sender
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_friend_request_decline]
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
            RAISERROR('Only the receiver can decline this request.', 16, 2);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        IF @StatusName <> 'Pending'
        BEGIN
            RAISERROR('Friend request is no longer pending.', 16, 3);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        UPDATE [dbo].[friend_request]
        SET status_id     = (SELECT id FROM [dbo].[friend_request_status] WHERE status = 'Declined' AND is_deleted = 0),
            responded_at  = SYSUTCDATETIME(),
            modified_time = SYSUTCDATETIME(),
            modified_by   = @ModifiedBy
        WHERE id = @RequestId;

        INSERT INTO [dbo].[friend_notification]
            ([space_id], [recipient_id], [sender_id], [notification_type_id], [reference_id], [modified_by])
        VALUES (
            @SpaceId,
            @SenderId,
            @ReceiverId,
            (SELECT id FROM [dbo].[friend_notification_type] WHERE type_name = 'FriendRequestDeclined' AND is_deleted = 0),
            @RequestId,
            @ModifiedBy
        );

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

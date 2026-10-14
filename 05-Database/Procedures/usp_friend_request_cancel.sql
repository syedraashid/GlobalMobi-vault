-- ============================================================
-- SP 9: usp_friend_request_cancel
-- Only sender can cancel. Only Pending requests can be cancelled.
-- Returns receiver_id so service can fire SignalR event.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_friend_request_cancel]
    @RequestId  UNIQUEIDENTIFIER,
    @CallerId   UNIQUEIDENTIFIER,
    @SpaceId    INT,
    @ModifiedBy VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

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
        RETURN;
    END;

    IF @SenderId <> @CallerId
    BEGIN
        RAISERROR('Only the sender can cancel this request.', 16, 2);
        RETURN;
    END;

    IF @StatusName <> 'Pending'
    BEGIN
        RAISERROR('Only pending requests can be cancelled.', 16, 3);
        RETURN;
    END;

    UPDATE [dbo].[friend_request]
    SET status_id     = (SELECT id FROM [dbo].[friend_request_status] WHERE status = 'Cancelled' AND is_deleted = 0),
        responded_at  = SYSUTCDATETIME(),
        modified_time = SYSUTCDATETIME(),
        modified_by   = @ModifiedBy
    WHERE id = @RequestId;

    -- Return receiver_id for SignalR FriendRequestCancelled notification
    SELECT @ReceiverId AS ReceiverId;
END;

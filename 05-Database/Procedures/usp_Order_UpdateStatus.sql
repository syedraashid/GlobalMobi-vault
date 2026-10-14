CREATE   PROCEDURE [dbo].[usp_Order_UpdateStatus]
    @OrderId      UNIQUEIDENTIFIER,
    @StatusId     INT,
    @ChangeReason VARCHAR(500) = NULL,
    @ModBy        VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE orders
    SET status_id     = @StatusId,
        change_reason = @ChangeReason,
        modified_time = SYSUTCDATETIME(),
        modified_by   = @ModBy
    WHERE id = @OrderId;
END

CREATE   PROCEDURE [dbo].[usp_Order_UpdatePaidStatus]
    @OrderId      UNIQUEIDENTIFIER,
    @PaidStatusId INT,
    @ModBy        VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE orders
    SET status_id     = @PaidStatusId,
        modified_time = SYSUTCDATETIME(),
        modified_by   = @ModBy
    WHERE id = @OrderId
      AND status_id <> @PaidStatusId;
END

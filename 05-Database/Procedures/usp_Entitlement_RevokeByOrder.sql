-- usp_Entitlement_RevokeByOrder
-- Sets all entitlements for an order to RevokedStatus with an optional reason.
-- Used during refund processing.
CREATE   PROCEDURE [dbo].[usp_Entitlement_RevokeByOrder]
    @OrderId       UNIQUEIDENTIFIER,
    @RevokedStatus INT,
    @Reason        VARCHAR(500) = NULL,
    @ModBy         VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE e
    SET e.status_id      = @RevokedStatus,
        e.revoked_reason = @Reason,
        e.modified_time  = SYSUTCDATETIME(),
        e.modified_by    = @ModBy
    FROM entitlement e
    JOIN order_line_item ol ON ol.id = e.order_line_item_id
    WHERE ol.order_id = @OrderId;
END

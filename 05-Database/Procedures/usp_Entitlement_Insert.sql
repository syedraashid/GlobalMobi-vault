-- ============================================================
-- ENTITLEMENT SPs
-- ============================================================

-- usp_Entitlement_Insert
-- Grants entitlements for every order line item on a paid order.
-- Idempotent: LEFT JOIN excludes line items that already have an entitlement row,
-- so re-runs after a partial failure are safe.
CREATE   PROCEDURE [dbo].[usp_Entitlement_Insert]
    @OrderId         UNIQUEIDENTIFIER,
    @OrderStatusPaid INT,
    @GrantedStatus   INT,
    @ModBy           VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO entitlement
    (id, order_line_item_id, user_id, status_id, quantity,
     granted_datetime, revoked_reason, metadata,
     is_deleted, modified_time, modified_by)
    SELECT
        NEWID(), ol.id, o.user_id, @GrantedStatus, ol.quantity,
        SYSUTCDATETIME(), NULL, ol.metadata,
        0, SYSUTCDATETIME(), @ModBy
    FROM order_line_item ol
    JOIN orders o         ON o.id = ol.order_id
    LEFT JOIN entitlement e ON e.order_line_item_id = ol.id
    WHERE ol.order_id = @OrderId
      AND o.status_id = @OrderStatusPaid
      AND e.id IS NULL;
END

CREATE   PROCEDURE [dbo].[usp_Order_SelectEntitlements]
    @OrderId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        CAST(e.id AS NVARCHAR(36))                 AS id,
        CAST(e.order_line_item_id AS NVARCHAR(36)) AS order_line_id,
        CAST(e.user_id AS NVARCHAR(36))            AS user_id,
        e.status_id                                 AS status,
        e.quantity, e.granted_datetime, e.revoked_reason, e.metadata
    FROM entitlement e
    WHERE e.order_line_item_id IN (
        SELECT id FROM order_line_item WHERE order_id = @OrderId
    )
    ORDER BY e.modified_time;
END

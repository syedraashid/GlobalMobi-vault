-- usp_Order_SelectLines: returns unit_amount as BIGINT, currency_id from parent orders row.
CREATE   PROCEDURE [dbo].[usp_Order_SelectLines]
    @OrderId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        CAST(ol.id AS NVARCHAR(36))          AS id,
        ol.item_type_id,
        CAST(ol.item_ref_id AS NVARCHAR(36)) AS item_ref_id,
        NULL                                 AS entity_id,
        ol.shop_id,
        ol.quantity,
        ol.unit_amount,
        o.currency_id,
        ol.metadata
    FROM order_line_item ol
    JOIN orders o ON o.id = ol.order_id
    WHERE ol.order_id = @OrderId
    ORDER BY ol.modified_time;
END

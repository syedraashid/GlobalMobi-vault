CREATE   PROCEDURE [dbo].[usp_Order_SelectAdjustments]
    @OrderId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        CAST(id AS NVARCHAR(36))                 AS id,
        CAST(order_line_item_id AS NVARCHAR(36)) AS order_line_id,
        adjustment_type_id                        AS item_type_id,
        code, amount, description_key, metadata
    FROM order_adjustment
    WHERE order_id = @OrderId
    ORDER BY id;
END

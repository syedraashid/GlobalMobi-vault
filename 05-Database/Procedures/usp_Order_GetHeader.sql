CREATE   PROCEDURE [dbo].[usp_Order_GetHeader]
    @OrderId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SELECT space_id, currency_id, total_net_amount, gateway_preferred_id
    FROM orders
    WHERE id = @OrderId;
END

CREATE   PROCEDURE [dbo].[usp_Order_GetTotalNet]
    @OrderId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1 total_net_amount
    FROM orders
    WHERE id = @OrderId;
END

CREATE   PROCEDURE [dbo].[usp_Order_SumCaptured]
    @OrderId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SELECT COALESCE(SUM(pc.amount_captured), 0)
    FROM payment_charge pc
    JOIN payment_intent pi ON pi.id = pc.payment_intent_id
    WHERE pi.order_id = @OrderId;
END

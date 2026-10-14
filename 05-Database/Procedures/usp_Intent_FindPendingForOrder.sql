CREATE   PROCEDURE [dbo].[usp_Intent_FindPendingForOrder]
    @OrderId   UNIQUEIDENTIFIER,
    @GatewayId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1
        CAST(id AS NVARCHAR(36)) AS id,
        status_id, idempotency_key, provider_intent_id,
        payment_gateway_id, amount, currency_id
    FROM payment_intent
    WHERE order_id = @OrderId
      AND status_id IN (1, 2)
      AND (@GatewayId IS NULL OR payment_gateway_id = @GatewayId)
    ORDER BY modified_time DESC;
END

-- ============================================================
-- READ SPs
-- ============================================================

CREATE   PROCEDURE [dbo].[usp_Intent_SelectByOrder]
    @OrderId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        CAST(id AS NVARCHAR(36)) AS id,
        payment_gateway_id, status_id, amount, currency_id,
        client_secret, provider_intent_id
    FROM payment_intent
    WHERE order_id = @OrderId
    ORDER BY modified_time;
END

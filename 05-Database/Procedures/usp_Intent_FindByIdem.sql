CREATE   PROCEDURE [dbo].[usp_Intent_FindByIdem]
    @OrderId UNIQUEIDENTIFIER,
    @Key     VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1
        CAST(id AS NVARCHAR(36)) AS id,
        provider_intent_id
    FROM payment_intent
    WHERE order_id         = @OrderId
      AND idempotency_key  = @Key;
END

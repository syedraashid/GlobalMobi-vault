-- ============================================================
-- WRITE SPs
-- ============================================================

CREATE   PROCEDURE [dbo].[usp_Intent_Insert]
    @Id      UNIQUEIDENTIFIER,
    @OrderId UNIQUEIDENTIFIER,
    @Gw      INT,
    @Status  INT,
    @Amt     BIGINT,
    @Ccy     INT,
    @ProvId  VARCHAR(128) = NULL,
    @Key     VARCHAR(255) = NULL,
    @ModBy   VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO payment_intent
    (id, order_id, payment_gateway_id, status_id, amount, currency_id,
     client_secret, provider_intent_id, idempotency_key,
     is_deleted, modified_time, modified_by)
    VALUES
    (@Id, @OrderId, @Gw, @Status, @Amt, @Ccy,
     NULL, @ProvId, @Key,
     0, SYSUTCDATETIME(), @ModBy);
END

-- ============================================================
-- CHARGE — READ SPs
-- ============================================================

CREATE   PROCEDURE [dbo].[usp_Charge_SelectByOrder]
    @OrderId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        CAST(pc.id AS NVARCHAR(36))                AS id,
        CAST(pc.payment_intent_id AS NVARCHAR(36)) AS payment_intent_id,
        pc.status_id,
        pc.amount_captured,
        pc.currency_id,
        pc.provider_charge_id,
        pc.gateway_fee_amount,
        CAST(pc.exchange_rate AS DECIMAL(18,6))    AS exchange_rate,
        pc.payment_datetime,
        pc.payer_email,
        pc.payer_id
    FROM payment_charge pc
    WHERE pc.payment_intent_id IN (
        SELECT id FROM payment_intent WHERE order_id = @OrderId
    )
    ORDER BY pc.payment_datetime;
END

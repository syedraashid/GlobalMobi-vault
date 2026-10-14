-- ============================================================
-- REFUND — READ SPs
-- ============================================================

CREATE   PROCEDURE [dbo].[usp_Refund_SelectByOrder]
    @OrderId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        CAST(id AS NVARCHAR(36))                AS id,
        CAST(payment_charge_id AS NVARCHAR(36)) AS payment_charge_id,
        status_id, amount, currency_id,
        provider_refund_id, reason, refund_datetime
    FROM payment_refund
    WHERE payment_charge_id IN (
        SELECT pc.id FROM payment_charge pc
        WHERE pc.payment_intent_id IN (
            SELECT id FROM payment_intent WHERE order_id = @OrderId
        )
    )
    ORDER BY refund_datetime;
END

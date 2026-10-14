CREATE   PROCEDURE [dbo].[usp_Charge_GetContext]
    @ChargeId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        CAST(o.id AS NVARCHAR(36))  AS order_id,
        o.space_id,
        o.currency_id,
        pi.payment_gateway_id,
        pc.provider_charge_id,
        pc.amount_captured          AS amount_captured_minor,
        COALESCE(SUM(pr.amount), 0) AS total_refunded_so_far_minor
    FROM payment_charge pc
    JOIN payment_intent pi ON pi.id = pc.payment_intent_id
    JOIN orders o           ON o.id  = pi.order_id
    LEFT JOIN payment_refund pr ON pr.payment_charge_id = pc.id
                                AND pr.status_id = 2
    WHERE pc.id = @ChargeId
    GROUP BY o.id, o.space_id, o.currency_id, pi.payment_gateway_id,
             pc.provider_charge_id, pc.amount_captured;
END

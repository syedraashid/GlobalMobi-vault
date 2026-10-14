-- ============================================================
-- RECONCILE + CURRENCY (related to order lifecycle)
-- ============================================================

CREATE   PROCEDURE [dbo].[usp_Reconcile_FindCandidates]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        CAST(o.id AS NVARCHAR(36))                                         AS OrderId,
        o.space_id                                                          AS SpaceId,
        o.gateway_preferred_id                                              AS PaymentGatewayId,
        CAST(CASE WHEN o.status_id = 3        THEN 1 ELSE 0 END AS BIT)   AS IsPaid,
        CAST(CASE WHEN ISNULL(inv.cnt, 0) > 0 THEN 1 ELSE 0 END AS BIT)  AS HasInvoice,
        CAST(CASE WHEN ISNULL(ent.cnt, 0) > 0 THEN 1 ELSE 0 END AS BIT)  AS HasEntitlements,
        CAST(pi.id AS NVARCHAR(36))                                         AS IntentId,
        pi.provider_intent_id                                               AS ProviderIntentId,
        ch.last_charge_id                                                   AS LastChargeId,
        o.total_net_amount                                                  AS ExpectedPaidMinor
    FROM orders o
    LEFT JOIN (
        SELECT order_id, MAX(modified_time) AS last_ct
        FROM payment_intent
        GROUP BY order_id
    ) last ON last.order_id = o.id
    LEFT JOIN payment_intent pi
        ON pi.order_id = o.id AND pi.modified_time = last.last_ct
    LEFT JOIN (
        SELECT order_id, COUNT(*) AS cnt
        FROM invoice
        GROUP BY order_id
    ) inv ON inv.order_id = o.id
    LEFT JOIN (
        SELECT ol.order_id, COUNT(*) AS cnt
        FROM entitlement e
        JOIN order_line_item ol ON ol.id = e.order_line_item_id
        GROUP BY ol.order_id
    ) ent ON ent.order_id = o.id
    LEFT JOIN (
        SELECT pi2.order_id, MAX(CAST(pc.id AS NVARCHAR(36))) AS last_charge_id
        FROM payment_charge pc
        JOIN payment_intent pi2 ON pi2.id = pc.payment_intent_id
        GROUP BY pi2.order_id
    ) ch ON ch.order_id = o.id
    WHERE (pi.status_id IN (1, 2))
       OR (o.status_id = 3 AND (ISNULL(inv.cnt, 0) = 0 OR ISNULL(ent.cnt, 0) = 0));
END

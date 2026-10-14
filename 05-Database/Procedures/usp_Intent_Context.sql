-- 2.3 — usp_Intent_Context: contract_percentage now comes from entity
--       (via space.entity_id), not from space directly. Zero extra
--       round trips — still loaded in the same context call
--       CaptureHandler already makes on every capture.
CREATE   PROCEDURE [dbo].[usp_Intent_Context]
    @IntentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        CAST(i.order_id AS NVARCHAR(36)) AS order_id,
        o.space_id,
        o.currency_id,
        o.total_net_amount,
        CAST(o.user_id AS NVARCHAR(36))  AS user_id,
        i.provider_intent_id,
        i.payment_gateway_id,
        en.contract_percentage
    FROM payment_intent i
    JOIN orders o  ON o.id  = i.order_id
    JOIN space  sp ON sp.id = o.space_id
    JOIN entity en ON en.id = sp.entity_id
    WHERE i.id = @IntentId;
END

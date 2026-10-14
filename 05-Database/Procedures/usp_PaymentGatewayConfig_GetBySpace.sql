-- ============================================================
-- usp_PaymentGatewayConfig_GetBySpace
-- Returns all gateway configs belonging to the space itself
-- (charity_id IS NULL).
-- Used by GET /api/space/{spaceId}/payments/gateways
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_PaymentGatewayConfig_GetBySpace]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        c.id,
        c.space_id,
        c.charity_id,
        c.payment_gateway_id,
        pg.payment_gateway  AS gateway_key,
        c.encrypted_client_id,
        c.encrypted_secret_key,
        c.is_enabled,
        c.created_time,
        c.created_by,
        c.modified_time,
        c.modified_by
    FROM  payment_gateway_config c
    JOIN  payment_gateway        pg ON pg.id = c.payment_gateway_id
    WHERE c.space_id   = @SpaceId
      AND c.charity_id IS NULL
      AND c.is_deleted = 0;
END;

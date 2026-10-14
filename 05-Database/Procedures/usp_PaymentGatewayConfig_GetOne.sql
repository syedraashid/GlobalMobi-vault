-- ============================================================
-- usp_PaymentGatewayConfig_GetOne
-- Returns a single config row including encrypted blobs.
-- Called by the gateway factory at payment processing time.
-- @CharityId = NULL  → fetch the space-level config
-- @CharityId = value → fetch that charity's config
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_PaymentGatewayConfig_GetOne]
    @SpaceId          INT,
    @CharityId        INT = NULL,
    @PaymentGatewayId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        c.id,
        c.encrypted_client_id,
        c.encrypted_secret_key,
        c.is_enabled
    FROM  payment_gateway_config c
    WHERE c.space_id           = @SpaceId
      AND (
              (c.charity_id IS NULL     AND @CharityId IS NULL)
           OR (c.charity_id = @CharityId)
          )
      AND  c.payment_gateway_id = @PaymentGatewayId
      AND  c.is_deleted         = 0;
END;

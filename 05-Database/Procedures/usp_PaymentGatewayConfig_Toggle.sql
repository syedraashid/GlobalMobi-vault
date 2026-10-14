-- ============================================================
-- usp_PaymentGatewayConfig_Toggle
-- Flips is_enabled for a single config without requiring the
-- user to re-enter credentials.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_PaymentGatewayConfig_Toggle]
    @SpaceId          INT,
    @CharityId        INT = NULL,
    @PaymentGatewayId INT,
    @IsEnabled        BIT,
    @ModifiedBy       VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE payment_gateway_config
    SET    is_enabled    = @IsEnabled,
           modified_time = SYSUTCDATETIME(),
           modified_by   = @ModifiedBy
    WHERE  space_id           = @SpaceId
      AND  (
               (charity_id IS NULL     AND @CharityId IS NULL)
            OR (charity_id = @CharityId)
           )
      AND  payment_gateway_id = @PaymentGatewayId
      AND  is_deleted         = 0;
END;

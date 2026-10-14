-- ============================================================
-- usp_PaymentGatewayConfig_Upsert
-- INSERT or UPDATE one config row identified by owner (space_id +
-- charity_id) and gateway type. On INSERT sets all audit columns;
-- on UPDATE only touches modified_time + modified_by.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_PaymentGatewayConfig_Upsert]
    @SpaceId            INT,
    @CharityId          INT           = NULL,
    @PaymentGatewayId   INT,
    @EncryptedClientId  NVARCHAR(MAX),
    @EncryptedSecretKey NVARCHAR(MAX),
    @IsEnabled          BIT,
    @ModifiedBy         VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    MERGE payment_gateway_config AS target
    USING (
        SELECT
            @SpaceId          AS space_id,
            @CharityId        AS charity_id,
            @PaymentGatewayId AS payment_gateway_id
    ) AS source
        ON  target.space_id           = source.space_id
        AND (
                (target.charity_id IS NULL     AND source.charity_id IS NULL)
             OR (target.charity_id = source.charity_id)
            )
        AND target.payment_gateway_id = source.payment_gateway_id
        AND target.is_deleted         = 0

    WHEN MATCHED THEN
        UPDATE SET
            encrypted_client_id  = @EncryptedClientId,
            encrypted_secret_key = @EncryptedSecretKey,
            is_enabled           = @IsEnabled,
            modified_time        = SYSUTCDATETIME(),
            modified_by          = @ModifiedBy

    WHEN NOT MATCHED THEN
        INSERT (
            space_id, charity_id, payment_gateway_id,
            encrypted_client_id, encrypted_secret_key,
            is_enabled,
            created_by, modified_by
        )
        VALUES (
            @SpaceId, @CharityId, @PaymentGatewayId,
            @EncryptedClientId, @EncryptedSecretKey,
            @IsEnabled,
            @ModifiedBy, @ModifiedBy
        );

END;

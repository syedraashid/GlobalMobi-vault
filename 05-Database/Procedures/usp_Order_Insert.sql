-- ============================================================
-- WRITE SPs
-- ============================================================

CREATE   PROCEDURE [dbo].[usp_Order_Insert]
    @Id                 UNIQUEIDENTIFIER,
    @UserId             UNIQUEIDENTIFIER,
    @SpaceId            INT,
    @Trx                INT,
    @CcyId              INT,
    @StatusId           INT,
    @Gross              BIGINT,
    @Disc               BIGINT,
    @Tax                BIGINT,
    @Fees               BIGINT,
    @Net                BIGINT,
    @SessionId          CHAR(36),
    @GatewayPreferredId INT          = NULL,
    @Remarks            VARCHAR(255) = NULL,
    @IdemKey            VARCHAR(255) = NULL,
    @ModBy              VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO orders
    (id, user_id, space_id, transaction_type_id, currency_id, status_id,
     total_gross_amount, total_discount_amount, change_reason,
     total_tax_amount, total_fee_amount, total_net_amount,
     original_order_id, session_id, gateway_preferred_id,
     order_datetime, remarks, idempotency_key,
     is_deleted, modified_time, modified_by)
    VALUES
    (@Id, @UserId, @SpaceId, @Trx, @CcyId, @StatusId,
     @Gross, @Disc, NULL,
     @Tax, @Fees, @Net,
     NULL, @SessionId, @GatewayPreferredId,
     SYSUTCDATETIME(), @Remarks, @IdemKey,
     0, SYSUTCDATETIME(), @ModBy);
END

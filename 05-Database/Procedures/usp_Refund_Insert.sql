-- ============================================================
-- REFUND — WRITE SPs
-- ============================================================

CREATE   PROCEDURE [dbo].[usp_Refund_Insert]
    @Id             UNIQUEIDENTIFIER,
    @ChargeId       UNIQUEIDENTIFIER,
    @Status         INT,
    @Amt            BIGINT,
    @Ccy            INT,
    @ProvRefund     VARCHAR(128) = NULL,
    @Reason         VARCHAR(500) = NULL,
    @IdempotencyKey VARCHAR(255) = NULL,
    @ModBy          VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO payment_refund
    (id, payment_charge_id, status_id, amount, currency_id,
     provider_refund_id, reason, idempotency_key, refund_datetime,
     is_deleted, modified_time, modified_by)
    VALUES
    (@Id, @ChargeId, @Status, @Amt, @Ccy,
     @ProvRefund, @Reason, @IdempotencyKey, SYSUTCDATETIME(),
     0, SYSUTCDATETIME(), @ModBy);
END

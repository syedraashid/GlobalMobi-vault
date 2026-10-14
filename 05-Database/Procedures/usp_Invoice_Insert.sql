-- ============================================================
-- usp_Invoice_Insert
-- Phase 7 version: all monetary parameters are BIGINT minor units.
-- Original version used DECIMAL(18,4) which conflicts with the Phase 7
-- ALTER TABLE that changed invoice columns to BIGINT.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Invoice_Insert]
    @Id           UNIQUEIDENTIFIER,
    @No           VARCHAR(64),
    @UserId       UNIQUEIDENTIFIER,
    @OrderId      UNIQUEIDENTIFIER,
    @Status       INT,
    @ChargeId     UNIQUEIDENTIFIER,
    @GatewayId    INT,
    @ProvChargeId VARCHAR(128)  = NULL,
    @SpaceId      INT,
    @CurrencyId   INT,
    @Subtotal     BIGINT,
    @Discount     BIGINT,
    @Tax          BIGINT,
    @Fee          BIGINT,
    @Total        BIGINT,
    @BillToName   VARCHAR(128)  = NULL,
    @BillToEmail  VARCHAR(255)  = NULL,
    @Notes        VARCHAR(255)  = NULL,
    @Metadata     NVARCHAR(MAX) = NULL,
    @ModBy        VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO invoice
    (id, invoice_number, user_id, order_id, subscription_id,
     status_id, payment_charge_id, payment_gateway_id, provider_charge_id,
     space_id, issue_datetime, currency_id,
     subtotal_amount, discount_amount, tax_amount, fee_amount, total_amount,
     bill_to_name, bill_to_email, notes, pdf_url, metadata,
     is_deleted, modified_time, modified_by)
    VALUES
    (@Id, @No, @UserId, @OrderId, NULL,
     @Status, @ChargeId, @GatewayId, @ProvChargeId,
     @SpaceId, SYSUTCDATETIME(), @CurrencyId,
     @Subtotal, @Discount, @Tax, @Fee, @Total,
     @BillToName, @BillToEmail, @Notes, NULL, @Metadata,
     0, SYSUTCDATETIME(), @ModBy);
END

-- 2.4 — usp_Charge_Insert: persists the contract % snapshot and the
--       merchant net amount + its currency, whatever their source.
--       Unaffected by the space -> entity move; unchanged from the
--       original migration.
CREATE   PROCEDURE [dbo].[usp_Charge_Insert]
    @Id           UNIQUEIDENTIFIER,
    @IntentId     UNIQUEIDENTIFIER,
    @Status       INT,
    @Amt          BIGINT,
    @Ccy          INT,
    @ProvCharge   VARCHAR(128)  = NULL,
    @PaidAt       DATETIME2,
    @PayerEmail   VARCHAR(255)  = NULL,
    @PayerId      VARCHAR(128)  = NULL,
    @ExchangeRate DECIMAL(18,6) = NULL,
    @GatewayFee   BIGINT        = NULL,
    @PayMethod    VARCHAR(50)   = NULL,
    @ContractPct  DECIMAL(5,2)  = NULL,
    @MerchantNetAmt BIGINT      = NULL,
    @MerchantNetCcy INT         = NULL,
    @ModBy        VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO payment_charge
    (id, payment_intent_id, status_id, amount_captured, currency_id,
     provider_charge_id, payment_datetime,
     payer_email, payer_id, exchange_rate, gateway_fee_amount, payment_method_type,
     contract_percentage_applied, merchant_net_amount, merchant_net_currency_id,
     is_deleted, modified_time, modified_by)
    VALUES
    (@Id, @IntentId, @Status, @Amt, @Ccy,
     @ProvCharge, @PaidAt,
     @PayerEmail, @PayerId, @ExchangeRate, @GatewayFee, @PayMethod,
     @ContractPct, @MerchantNetAmt, @MerchantNetCcy,
     0, SYSUTCDATETIME(), @ModBy);
END

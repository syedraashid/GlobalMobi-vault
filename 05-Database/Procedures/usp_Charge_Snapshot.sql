CREATE   PROCEDURE [dbo].[usp_Charge_Snapshot]
    @ChargeId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SELECT pc.provider_charge_id, pi.payment_gateway_id
    FROM payment_charge pc
    JOIN payment_intent pi ON pi.id = pc.payment_intent_id
    WHERE pc.id = @ChargeId;
END

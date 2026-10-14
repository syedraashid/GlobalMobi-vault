-- =====================================================================================
-- 5. usp_Charge_AssignDepositId — updated in place
-- =====================================================================================
-- This is one of only two touches to already-shipped, live behavior in this entire
-- migration (the other is section 6). The body below is the real, current definition
-- (re-verified read-only via sp_helptext immediately before writing this revision — the
-- live body is byte-identical to the previous capture), with one change: the UPDATE now
-- writes the resolved payment_deposit surrogate id (as text) instead of the raw @DepositId
-- free text. Every existing guard (already-assigned charges skipped, cross-space charges
-- skipped, @@ROWCOUNT semantics) is untouched — search for "NEW" below for the only real
-- change.
-- =====================================================================================

CREATE   PROCEDURE [dbo].[usp_Charge_AssignDepositId]
    @SpaceId    INT,
    @ChargeIds  NVARCHAR(MAX),
    @DepositId  VARCHAR(64),
    @ModifiedBy VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    -- NEW: resolve (or create) the payment_deposit registry row for this (space, deposit
    -- text) pair, then write its surrogate id — not the free text itself — onto
    -- payment_charge.deposit_id. usp_Transaction_Select (section 6) resolves it back to
    -- this same text for display, so nothing user-facing changes.
    DECLARE @PaymentDepositId INT;

    SELECT @PaymentDepositId = [id]
    FROM   [dbo].[payment_deposit]
    WHERE  [space_id] = @SpaceId AND [deposit_id] = @DepositId AND [is_deleted] = 0;

    IF @PaymentDepositId IS NULL
    BEGIN
        INSERT INTO [dbo].[payment_deposit] ([deposit_id], [space_id], [is_deleted], [modified_time], [modified_by])
        VALUES (@DepositId, @SpaceId, 0, SYSUTCDATETIME(), @ModifiedBy);

        SET @PaymentDepositId = SCOPE_IDENTITY();
    END

    -- NEW: a deposit represents one real bank deposit, which is definitionally one currency —
    -- usp_Deposit_Select/GetDetail SUM each charge's Net Amount in ITS OWN transaction
    -- currency, so mixing currencies within one deposit would sum incompatible units. Resolve
    -- which currency this deposit is committed to (an already-assigned charge's currency, if
    -- any exist — the deposit's currency is fixed on its first charge and never changes after);
    -- otherwise the smallest currency_id among this batch's eligible charges (STRING_SPLIT
    -- gives no ordering guarantee, so "first in @ChargeIds" isn't a meaningful tie-break).
    -- Any charge below with a different currency is silently excluded from the UPDATE — same
    -- treatment this proc already gives already-assigned/cross-space charges.
    DECLARE @DepositCurrencyId INT;

    SELECT TOP (1) @DepositCurrencyId = pc.currency_id
    FROM   payment_charge pc
    WHERE  TRY_CAST(pc.deposit_id AS INT) = @PaymentDepositId AND pc.is_deleted = 0;

    IF @DepositCurrencyId IS NULL
    BEGIN
        SELECT @DepositCurrencyId = MIN(pc.currency_id)
        FROM   payment_charge pc
        JOIN   payment_intent pi ON pi.id = pc.payment_intent_id
        JOIN   orders         o  ON o.id  = pi.order_id
        JOIN   (SELECT CAST(value AS UNIQUEIDENTIFIER) AS id FROM STRING_SPLIT(@ChargeIds, ',')) ids
          ON ids.id = pc.id
        WHERE  pc.is_deleted = 0
          AND  pc.deposit_id IS NULL
          AND  o.space_id     = @SpaceId;
    END

    UPDATE pc
       SET pc.deposit_id    = CAST(@PaymentDepositId AS VARCHAR(64)),
           pc.modified_time = SYSUTCDATETIME(),
           pc.modified_by   = @ModifiedBy
    FROM payment_charge pc
    JOIN payment_intent pi ON pi.id = pc.payment_intent_id
    JOIN orders         o  ON o.id  = pi.order_id
    JOIN (SELECT CAST(value AS UNIQUEIDENTIFIER) AS id FROM STRING_SPLIT(@ChargeIds, ',')) ids
      ON ids.id = pc.id
    WHERE pc.is_deleted = 0
      AND pc.deposit_id IS NULL
      AND o.space_id     = @SpaceId
      AND (@DepositCurrencyId IS NULL OR pc.currency_id = @DepositCurrencyId); -- NEW

    SELECT @@ROWCOUNT AS affected;
END

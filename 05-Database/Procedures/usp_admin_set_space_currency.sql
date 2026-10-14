-- Sets a space's own currency override (space.currency_id).
-- Single-purpose alternative to usp_admin_upsert_space_config, which would
-- otherwise require re-sending all 14 feature-flag values just to set currency.
CREATE   PROCEDURE [dbo].[usp_admin_set_space_currency]
    @SpaceId    INT,
    @CurrencyId INT,
    @ModifiedBy VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [dbo].[space]
    SET    [currency_id]   = @CurrencyId,
           [modified_time] = SYSUTCDATETIME(),
           [modified_by]   = @ModifiedBy
    WHERE  [id] = @SpaceId;
END

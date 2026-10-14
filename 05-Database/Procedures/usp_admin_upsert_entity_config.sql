-- 2.2c — usp_admin_upsert_entity_config: add @ContractPercentage,
--        saved in the same call as currency/locale (one Save button
--        in the admin UI covers all three).
CREATE   PROCEDURE [dbo].[usp_admin_upsert_entity_config]
    @EntityId           INT,
    @CurrencyId         INT,
    @LocaleId           VARCHAR(20),
    @ContractPercentage DECIMAL(5,2)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE [dbo].[entity]
    SET [currency_id]         = @CurrencyId,
        [locale_id]           = @LocaleId,
        [contract_percentage] = @ContractPercentage,
        [modified_time]       = GETUTCDATE()
    WHERE [id] = @EntityId AND [is_deleted] = 0;
END

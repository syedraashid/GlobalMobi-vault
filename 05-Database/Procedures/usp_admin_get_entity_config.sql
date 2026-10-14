-- 2.2b — usp_admin_get_entity_config: add ContractPercentage alongside
--        the existing currency/locale fields (verified against the
--        live proc body before writing this ALTER).
CREATE   PROCEDURE [dbo].[usp_admin_get_entity_config]
    @EntityId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        c.[ISO]                  AS Currency,
        l.[language_name]        AS Language,
        e.[currency_id]          AS CurrencyId,
        e.[locale_id]            AS LocaleId,
        e.[contract_percentage]  AS ContractPercentage
    FROM [dbo].[entity] e
    JOIN [dbo].[currency] c ON c.[id] = e.[currency_id]
    JOIN [dbo].[i18n_locale] l ON l.[id] = e.[locale_id]
    WHERE e.[id] = @EntityId AND e.[is_deleted] = 0;
END

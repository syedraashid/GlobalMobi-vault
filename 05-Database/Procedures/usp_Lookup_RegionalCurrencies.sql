CREATE   PROCEDURE [dbo].[usp_Lookup_RegionalCurrencies]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT rc.id,
           r.code   AS RegionCode,
           c.name   AS CurrencyName,
           c.ISO    AS CurrencyIso,
           c.symbol AS CurrencySymbol
    FROM regional_currency rc
    JOIN region   r ON r.id = rc.region_id
    JOIN currency c ON c.id = rc.currency_id
    WHERE rc.is_deleted = 0
    ORDER BY rc.id;
END

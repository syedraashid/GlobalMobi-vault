CREATE   PROCEDURE [dbo].[usp_Lookup_Currencies]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id,
           name           AS Name,
           ISO,
           symbol         AS Symbol,
           delimiter      AS Delimiter,
           decimal_places AS DecimalPlaces
    FROM currency
    WHERE is_deleted = 0
    ORDER BY id;
END

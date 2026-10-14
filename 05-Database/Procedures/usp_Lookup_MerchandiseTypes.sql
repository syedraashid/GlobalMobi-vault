-- ============================================================
-- 1. usp_Lookup_MerchandiseTypes
--    Adds position + interaction, removes is_top.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Lookup_MerchandiseTypes]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        id,
        [type]      AS Type,
        position    AS Position,
        interaction AS Interaction
    FROM  merchandise_type
    WHERE is_deleted = 0
    ORDER BY id;
END

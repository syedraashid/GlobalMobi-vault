-- ============================================================
-- usp_TaxCategory_SelectBySpace
-- Lists all active tax categories for a space (for admin dropdowns).
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_TaxCategory_SelectBySpace]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id, space_id, name, rate_pct, modified_time, modified_by
    FROM tax_category
    WHERE space_id = @SpaceId AND is_deleted = 0
    ORDER BY name;
END

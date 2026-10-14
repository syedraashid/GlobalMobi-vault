-- ============================================================
-- usp_TaxCategory_ExistsInSpace
-- Returns 1 row if the tax category belongs to the space and
-- is not soft-deleted; empty result set otherwise.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_TaxCategory_ExistsInSpace]
    @TaxCategoryId INT,
    @SpaceId       INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) 1
    FROM tax_category
    WHERE id = @TaxCategoryId
      AND space_id  = @SpaceId
      AND is_deleted = 0;
END

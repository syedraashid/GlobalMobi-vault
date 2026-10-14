-- ============================================================
-- usp_TaxCategory_GetById
-- Returns a single tax category row by id.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_TaxCategory_GetById]
    @TaxCategoryId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id       AS tax_category_id,
           name     AS tax_category_name,
           rate_pct AS tax_rate_pct
    FROM   [dbo].[tax_category]
    WHERE  id = @TaxCategoryId AND is_deleted = 0;
END

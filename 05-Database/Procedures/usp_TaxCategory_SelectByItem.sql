-- ============================================================
-- usp_TaxCategory_SelectByItem
-- Returns tax rate for a specific item (used in Phase 5 tax calculation).
-- Returns 0 rows if item has no tax_category_id (meaning 0% / no tax).
-- tax_is_inclusive is on item, not tax_category — reads i.tax_is_inclusive.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_TaxCategory_SelectByItem]
    @ItemRefId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1
        tc.id              AS tax_category_id,
        tc.rate_pct,
        i.tax_is_inclusive
    FROM item i
    JOIN tax_category tc ON tc.id = i.tax_category_id
    WHERE i.id          = @ItemRefId
      AND tc.is_deleted = 0;
END

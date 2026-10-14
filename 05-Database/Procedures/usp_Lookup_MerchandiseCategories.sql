-- ============================================================
-- 14. usp_Lookup_MerchandiseCategories
--     Used by LookupSql.cs / LookupController to populate the
--     category dropdown in ItemModal.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Lookup_MerchandiseCategories]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        id,
        category AS Category
    FROM merchandise_category
    WHERE is_deleted = 0
    ORDER BY id;
END

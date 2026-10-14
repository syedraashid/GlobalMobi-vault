-- ── 2. sp_CustomBoothItem_GetTypes ──────────────────────────
-- No caching by design — matches sp_Portal's own type-lookup convention.

CREATE   PROCEDURE [dbo].[sp_CustomBoothItem_GetTypes]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id, type_key, name, description
    FROM   custom_booth_item_type
    WHERE  is_deleted = 0
    ORDER BY id;
END

-- ============================================================
-- usp_Badge_GetCurrent
-- Returns media_id, name_key, description_key for a badge item.
-- Used in UpdateAsync to determine which keys/media to replace.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Badge_GetCurrent]
    @ItemId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) media_id, name_key, description_key
    FROM badge
    WHERE id = @ItemId
    ORDER BY id;
END

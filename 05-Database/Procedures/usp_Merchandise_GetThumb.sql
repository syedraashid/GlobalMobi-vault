-- ============================================================
-- usp_Merchandise_GetThumb
-- Returns the current thumbnail_media_id for a merchandise item.
-- Used in UpdateAsync before deciding whether to replace or reuse.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Merchandise_GetThumb]
    @ItemId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT thumbnail_media_id
    FROM merchandise
    WHERE id = @ItemId;
END

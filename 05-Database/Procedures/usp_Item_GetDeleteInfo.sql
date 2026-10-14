-- ============================================================
-- usp_Item_GetDeleteInfo
-- Returns item row + subtype media ids used to cascade soft-deletes.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Item_GetDeleteInfo]
    @ItemId  INT,
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1)
        i.id,
        i.space_id,
        i.item_type_id,
        i.name_key,
        i.description_key,
        m.thumbnail_media_id AS merch_thumb_media_id,
        b.media_id           AS badge_media_id
    FROM item i
    LEFT JOIN merchandise m ON m.id = i.id
    LEFT JOIN badge       b ON b.id = i.id
    WHERE i.id = @ItemId AND i.space_id = @SpaceId AND i.is_deleted = 0
    ORDER BY i.id;
END

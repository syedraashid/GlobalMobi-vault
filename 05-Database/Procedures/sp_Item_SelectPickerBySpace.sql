CREATE   PROCEDURE [dbo].[sp_Item_SelectPickerBySpace]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        i.id AS ItemId,
        i.item_type_id AS ItemTypeId,
        COALESCE(ni.[value], CAST(i.name_key AS VARCHAR(36))) AS Name,
        thumb.media_link AS ThumbnailUrl
    FROM dbo.item i
    OUTER APPLY (
        SELECT TOP 1 n.[value] FROM dbo.i18n n
        WHERE n.[key] = i.name_key AND n.space_id = i.space_id
        ORDER BY n.locale_id
    ) ni
    OUTER APPLY (
        SELECT TOP 1 ml.media_link
        FROM (
            SELECT m.thumbnail_media_id AS media_id FROM dbo.merchandise m WHERE m.id = i.id AND m.is_deleted = 0
            UNION ALL
            SELECT t.thumbnail_media_id FROM dbo.ticket t WHERE t.id = i.id AND t.is_deleted = 0
            UNION ALL
            SELECT b.media_id FROM dbo.badge b WHERE b.id = i.id AND b.is_deleted = 0
            UNION ALL
            SELECT a.thumbnail_media_id FROM dbo.avatar a WHERE a.id = i.id AND a.is_deleted = 0
        ) src
        JOIN dbo.media_localization ml ON ml.media_id = src.media_id
        ORDER BY ml.locale_id
    ) thumb
    WHERE i.space_id = @SpaceId AND i.is_deleted = 0 AND i.is_price_only = 0
      AND i.[status] = 'approved' AND i.is_available = 1
    ORDER BY i.id;
END

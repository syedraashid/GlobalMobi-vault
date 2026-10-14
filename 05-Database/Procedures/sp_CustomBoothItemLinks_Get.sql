-- ── 6. sp_CustomBoothItemLinks_Get / _GetApproved_Unity ─────────────────────
CREATE   PROCEDURE [dbo].[sp_CustomBoothItemLinks_Get]
    @SpaceId           INT,
    @CustomBoothItemIds NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Ids TABLE (id INT PRIMARY KEY);
    INSERT INTO @Ids SELECT value FROM OPENJSON(@CustomBoothItemIds) WITH (value INT '$');

    SELECT
        l.id AS link_id, l.custom_booth_item_id, l.position_id, l.external_link,
        l.thumbnail_media_id, tm.media_type_id AS thumb_media_type_id,
        loc.locale_id, loc.media_link AS thumb_media_link,
        l.status AS link_status
    FROM   custom_booth_item_link l
    JOIN   @Ids ci ON ci.id = l.custom_booth_item_id
    LEFT JOIN media tm              ON tm.id = l.thumbnail_media_id
    LEFT JOIN media_localization loc ON loc.media_id = l.thumbnail_media_id AND loc.is_deleted = 0
    WHERE  l.is_deleted = 0;
END

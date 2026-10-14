-- ============================================================
-- sp_Booth_GetMediaById
-- Returns a single booth media item (3 result sets):
--   RS1: core row (media_id, media_type_id, text_key,
--                  description_key, status)
--   RS2: link localizations (locale_id, media_link)
--   RS3: i18n rows (key_type='text'|'description',
--                   locale_id, value)
-- Returns 0 rows in RS1 if media_id does not belong to @SpaceId.
-- ============================================================
CREATE   PROCEDURE [dbo].[sp_Booth_GetMediaById]
    @SpaceId INT,
    @MediaId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    -- RS1: core
    SELECT bm.media_id,
           m.media_type_id,
           m.text_key,
           m.description_key,
           bm.[status]
    FROM   [dbo].[booth_media] bm  WITH (NOLOCK)
    JOIN   [dbo].[booth]       b   WITH (NOLOCK) ON b.id = bm.booth_id AND b.space_id = @SpaceId
    JOIN   [dbo].[media]       m   WITH (NOLOCK) ON m.id = bm.media_id
    WHERE  bm.media_id = @MediaId AND bm.is_deleted = 0;

    -- RS2: link localizations
    SELECT ml.locale_id, ml.media_link
    FROM   [dbo].[media_localization] ml WITH (NOLOCK)
    WHERE  ml.media_id = @MediaId AND ml.is_deleted = 0;

    -- RS3: i18n (text + description keys)
    SELECT
        CASE WHEN m.text_key IS NOT NULL
                  AND i.[key] = CONVERT(NVARCHAR(64), m.text_key) THEN 'text'
             ELSE 'description'
        END            AS key_type,
        i.locale_id,
        i.[value]
    FROM   [dbo].[media] m   WITH (NOLOCK)
    JOIN   [dbo].[i18n]  i   WITH (NOLOCK)
           ON  i.space_id   = @SpaceId
           AND i.is_deleted = 0
           AND (
                   (m.text_key        IS NOT NULL AND i.[key] = CONVERT(NVARCHAR(64), m.text_key))
                OR (m.description_key IS NOT NULL AND i.[key] = CONVERT(NVARCHAR(64), m.description_key))
               )
    WHERE  m.id = @MediaId;
END

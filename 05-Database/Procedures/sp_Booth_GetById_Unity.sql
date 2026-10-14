CREATE   PROCEDURE [dbo].[sp_Booth_GetById_Unity]
    @SpaceId INT,
    @BoothId INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;

    -- --------------------------------------------------------
    -- RS1: Approved booth + name localizations
    -- --------------------------------------------------------
    SELECT
        b.id,
        b.space_id,
        b.name_key,
        b.map_spot_id,
        ms.x,
        ms.y,
        ms.z,
        i.locale_id,
        i.[value]
    FROM booth b
    LEFT JOIN i18n i
           ON  i.[key]      = b.name_key
          AND  i.space_id   = b.space_id
          AND  i.is_deleted = 0
    LEFT JOIN map_spot ms
           ON  ms.id = b.map_spot_id
    WHERE b.space_id   = @SpaceId
      AND b.id         = @BoothId
      AND b.is_deleted = 0
      AND b.[status]   = 'approved'
    ORDER BY i.locale_id;

    -- --------------------------------------------------------
    -- RS2: Approved booth media + link localizations
    -- --------------------------------------------------------
    SELECT
        bm.booth_id,
        bm.media_id,
        m.media_type_id,
        m.text_key,
        m.description_key,
        ml.locale_id,
        ml.media_link,
        bm.created_time AS created_at
    FROM booth_media bm
    INNER JOIN media m
           ON  m.id         = bm.media_id
          AND  m.space_id   = @SpaceId
          AND  m.is_deleted = 0
    LEFT JOIN media_localization ml
           ON  ml.media_id   = m.id
          AND  ml.is_deleted = 0
    WHERE bm.booth_id  = @BoothId
      AND bm.is_deleted = 0
      AND bm.[status]   = 'approved'
    ORDER BY bm.media_id, ml.locale_id;

    -- --------------------------------------------------------
    -- RS3: Media text_key and description_key i18n values
    -- --------------------------------------------------------
    SELECT m.id AS media_id, 'text' AS key_type, i.locale_id, i.[value]
    FROM media m
    INNER JOIN booth_media bm
           ON  bm.media_id  = m.id
          AND  bm.booth_id  = @BoothId
          AND  bm.is_deleted = 0
          AND  bm.[status]   = 'approved'
    INNER JOIN i18n i
           ON  i.[key]      = m.text_key
          AND  i.space_id   = @SpaceId
          AND  i.is_deleted = 0
    WHERE m.is_deleted   = 0
      AND m.text_key IS NOT NULL

    UNION ALL

    SELECT m.id AS media_id, 'desc' AS key_type, i.locale_id, i.[value]
    FROM media m
    INNER JOIN booth_media bm
           ON  bm.media_id  = m.id
          AND  bm.booth_id  = @BoothId
          AND  bm.is_deleted = 0
          AND  bm.[status]   = 'approved'
    INNER JOIN i18n i
           ON  i.[key]      = m.description_key
          AND  i.space_id   = @SpaceId
          AND  i.is_deleted = 0
    WHERE m.is_deleted       = 0
      AND m.description_key IS NOT NULL

    ORDER BY media_id, key_type, locale_id;
END;

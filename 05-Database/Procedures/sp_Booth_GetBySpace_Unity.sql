CREATE   PROCEDURE [dbo].[sp_Booth_GetBySpace_Unity]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Collect approved booth IDs once; reused by RS2 and RS3.
        CREATE TABLE #BoothIds_U (id INT NOT NULL PRIMARY KEY);
        INSERT INTO #BoothIds_U (id)
            SELECT id
            FROM booth WITH (NOLOCK)
            WHERE space_id  = @SpaceId
              AND is_deleted = 0
              AND [status]   = 'approved';

        -- --------------------------------------------------------
        -- RS1: Approved booths + name localizations
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
        FROM booth b WITH (NOLOCK)
        LEFT JOIN i18n i WITH (NOLOCK)
               ON  i.[key]      = b.name_key
              AND  i.space_id   = b.space_id
              AND  i.is_deleted = 0
        LEFT JOIN map_spot ms WITH (NOLOCK)
               ON  ms.id = b.map_spot_id
        WHERE b.space_id  = @SpaceId
          AND b.is_deleted = 0
          AND b.[status]   = 'approved'
        ORDER BY b.id, i.locale_id;

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
        FROM booth_media bm WITH (NOLOCK)
        INNER JOIN media m WITH (NOLOCK)
               ON  m.id         = bm.media_id
              AND  m.space_id   = @SpaceId
              AND  m.is_deleted = 0
        LEFT JOIN media_localization ml WITH (NOLOCK)
               ON  ml.media_id   = m.id
              AND  ml.is_deleted = 0
        WHERE bm.booth_id  IN (SELECT id FROM #BoothIds_U)
          AND bm.is_deleted = 0
          AND bm.[status]   = 'approved'
        ORDER BY bm.booth_id, bm.media_id, ml.locale_id;

        -- --------------------------------------------------------
        -- RS3: Media text_key and description_key i18n values
        --      (only for approved booth_media rows)
        -- --------------------------------------------------------
        SELECT m.id AS media_id, 'text' AS key_type, i.locale_id, i.[value]
        FROM media m WITH (NOLOCK)
        INNER JOIN booth_media bm WITH (NOLOCK)
               ON  bm.media_id  = m.id
              AND  bm.is_deleted = 0
              AND  bm.[status]   = 'approved'
        INNER JOIN i18n i WITH (NOLOCK)
               ON  i.[key]      = m.text_key
              AND  i.space_id   = @SpaceId
              AND  i.is_deleted = 0
        WHERE bm.booth_id  IN (SELECT id FROM #BoothIds_U)
          AND m.is_deleted   = 0
          AND m.text_key IS NOT NULL

        UNION ALL

        SELECT m.id AS media_id, 'desc' AS key_type, i.locale_id, i.[value]
        FROM media m WITH (NOLOCK)
        INNER JOIN booth_media bm WITH (NOLOCK)
               ON  bm.media_id  = m.id
              AND  bm.is_deleted = 0
              AND  bm.[status]   = 'approved'
        INNER JOIN i18n i WITH (NOLOCK)
               ON  i.[key]      = m.description_key
              AND  i.space_id   = @SpaceId
              AND  i.is_deleted = 0
        WHERE bm.booth_id      IN (SELECT id FROM #BoothIds_U)
          AND m.is_deleted      = 0
          AND m.description_key IS NOT NULL

        ORDER BY media_id, key_type, locale_id;

        DROP TABLE #BoothIds_U;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#BoothIds_U') IS NOT NULL DROP TABLE #BoothIds_U;
        THROW;
    END CATCH
END;

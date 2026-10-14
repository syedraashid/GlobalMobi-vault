CREATE   PROCEDURE [dbo].[sp_Booth_GetBySpace]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        CREATE TABLE #BoothIds (id INT NOT NULL PRIMARY KEY);
        INSERT INTO #BoothIds (id)
            SELECT id FROM booth WITH (NOLOCK)
            WHERE space_id  = @SpaceId
              AND is_deleted = 0;

        -- --------------------------------------------------------
        -- RS1: Booths + name localizations
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
            i.[value],
            COALESCE(ca.[status], b.[status]) AS approval_status,
            ca.id         AS approval_id,
            ca.[action_type] AS approval_action_type,
            ca.[current_snapshot]  AS current_snapshot,
            ca.[proposed_snapshot] AS proposed_snapshot,
            b.[status]             AS content_status,
            b.icon_key             AS icon_key -- NEW
        FROM  booth b WITH (NOLOCK)
        LEFT JOIN i18n i WITH (NOLOCK)
            ON  i.[key]      = b.name_key
            AND i.space_id   = b.space_id
            AND i.is_deleted = 0
        LEFT JOIN map_spot ms WITH (NOLOCK)
            ON  ms.id      = b.map_spot_id
        LEFT JOIN dbo.content_approval ca WITH (NOLOCK)
            ON  ca.content_type = 'booth'
            AND ca.content_id   = b.id
            AND ca.[status]    != 'withdrawn'
        WHERE b.space_id  = @SpaceId
          AND b.is_deleted = 0
        ORDER BY b.id, i.locale_id;

        -- --------------------------------------------------------
        -- RS2: Booth media + link localizations + approval state
        -- --------------------------------------------------------
        SELECT
            bm.booth_id,
            bm.media_id,
            m.media_type_id,
            m.text_key,
            m.description_key,
            ml.locale_id,
            ml.media_link,
            bm.created_time          AS created_at,
            ca.approval_id,
            ca.approval_status,
            ca.approval_action_type,
            ca.current_snapshot,
            ca.proposed_snapshot,
            bm.[status]              AS content_status
        FROM  booth_media bm WITH (NOLOCK)
        INNER JOIN media m WITH (NOLOCK)
            ON  m.id         = bm.media_id
            AND m.space_id   = @SpaceId
            AND m.is_deleted = 0
        LEFT JOIN media_localization ml WITH (NOLOCK)
            ON  ml.media_id   = m.id
            AND ml.is_deleted = 0
        OUTER APPLY (
            SELECT TOP 1
                ca.id                  AS approval_id,
                ca.[status]            AS approval_status,
                ca.action_type         AS approval_action_type,
                ca.[current_snapshot]  AS current_snapshot,
                ca.[proposed_snapshot] AS proposed_snapshot
            FROM  content_approval ca WITH (NOLOCK)
            WHERE ca.content_type = 'booth_media'
              AND ca.content_id   = bm.media_id
              AND ca.[status]    != 'withdrawn'
            ORDER BY ca.submitted_at DESC
        ) ca
        WHERE bm.booth_id   IN (SELECT id FROM #BoothIds)
          AND bm.is_deleted  = 0
        ORDER BY bm.booth_id, bm.media_id, ml.locale_id;

        -- --------------------------------------------------------
        -- RS3: Media text_key and description_key i18n values
        -- --------------------------------------------------------
        SELECT m.id AS media_id, 'text' AS key_type, i.locale_id, i.[value]
        FROM  media m WITH (NOLOCK)
        INNER JOIN booth_media bm WITH (NOLOCK)
            ON  bm.media_id  = m.id
            AND bm.is_deleted = 0
        INNER JOIN i18n i WITH (NOLOCK)
            ON  i.[key]      = m.text_key
            AND i.space_id   = @SpaceId
            AND i.is_deleted = 0
        WHERE bm.booth_id   IN (SELECT id FROM #BoothIds)
          AND m.is_deleted   = 0
          AND m.text_key IS NOT NULL

        UNION ALL

        SELECT m.id AS media_id, 'desc' AS key_type, i.locale_id, i.[value]
        FROM  media m WITH (NOLOCK)
        INNER JOIN booth_media bm WITH (NOLOCK)
            ON  bm.media_id  = m.id
            AND bm.is_deleted = 0
        INNER JOIN i18n i WITH (NOLOCK)
            ON  i.[key]      = m.description_key
            AND i.space_id   = @SpaceId
            AND i.is_deleted = 0
        WHERE bm.booth_id      IN (SELECT id FROM #BoothIds)
          AND m.is_deleted      = 0
          AND m.description_key IS NOT NULL

        ORDER BY media_id, key_type, locale_id;

        DROP TABLE #BoothIds;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#BoothIds') IS NOT NULL
            DROP TABLE #BoothIds;
        THROW;
    END CATCH
END;

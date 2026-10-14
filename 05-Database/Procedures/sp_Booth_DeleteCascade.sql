-- ── 10. sp_Booth_DeleteCascade — full replacement (rev 09/11: adds custom_booth_item_link) ──

CREATE   PROCEDURE [dbo].[sp_Booth_DeleteCascade]
    @BoothId INT,
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM booth WITH (UPDLOCK, ROWLOCK, HOLDLOCK) WHERE id = @BoothId AND space_id = @SpaceId)
        BEGIN
            COMMIT TRANSACTION;
            SELECT 0 AS success;
            RETURN;
        END;

        -- ── Collect all dependent IDs upfront ────────────────────────
        CREATE TABLE #Portals
        (
            id                     INT              NOT NULL PRIMARY KEY,
            text_field_key         UNIQUEIDENTIFIER NOT NULL,
            corresponding_media_id BIGINT           NULL,
            corr_text_key          UNIQUEIDENTIFIER NULL,
            corr_desc_key          UNIQUEIDENTIFIER NULL
        );

        INSERT INTO #Portals (id, text_field_key, corresponding_media_id, corr_text_key, corr_desc_key)
            SELECT p.id, p.text_field_key, p.corresponding_media_id, m.text_key, m.description_key
            FROM   portal p
            LEFT JOIN media m ON m.id = p.corresponding_media_id
            WHERE  p.booth_id = @BoothId AND p.space_id = @SpaceId;

        CREATE TABLE #ThumbMedia
        (
            media_id        BIGINT           NOT NULL PRIMARY KEY,
            text_key        UNIQUEIDENTIFIER NULL,
            description_key UNIQUEIDENTIFIER NULL
        );

        INSERT INTO #ThumbMedia (media_id, text_key, description_key)
            SELECT DISTINCT pl.thumbnail_media_id, m.text_key, m.description_key
            FROM   portal_link pl
            JOIN   media m ON m.id = pl.thumbnail_media_id
            WHERE  pl.portal_id IN (SELECT id FROM #Portals)
              AND  pl.thumbnail_media_id IS NOT NULL;

        CREATE TABLE #BoothMedia
        (
            media_id        BIGINT           NOT NULL PRIMARY KEY,
            text_key        UNIQUEIDENTIFIER NULL,
            description_key UNIQUEIDENTIFIER NULL
        );

        INSERT INTO #BoothMedia (media_id, text_key, description_key)
            SELECT bm.media_id, m.text_key, m.description_key
            FROM   booth_media bm
            JOIN   media m ON m.id = bm.media_id
            WHERE  bm.booth_id = @BoothId;

        CREATE TABLE #CustomItems
        (
            id                     INT              NOT NULL PRIMARY KEY,
            corresponding_media_id BIGINT           NOT NULL,
            name_key               UNIQUEIDENTIFIER NOT NULL,
            description_key        UNIQUEIDENTIFIER NULL
        );

        INSERT INTO #CustomItems (id, corresponding_media_id, name_key, description_key)
            SELECT ci.id, ci.corresponding_media_id, ci.name_key, ci.description_key
            FROM   custom_booth_item ci
            WHERE  ci.booth_id = @BoothId;

        -- NEW (rev 09/11): custom item link thumbnails (a custom item can have up to 3
        -- positioned links, each with its own optional thumbnail — mirrors #ThumbMedia above).
        CREATE TABLE #CustomLinkThumbs
        (
            media_id        BIGINT           NOT NULL PRIMARY KEY,
            text_key        UNIQUEIDENTIFIER NULL,
            description_key UNIQUEIDENTIFIER NULL
        );

        INSERT INTO #CustomLinkThumbs (media_id, text_key, description_key)
            SELECT DISTINCT cl.thumbnail_media_id, m.text_key, m.description_key
            FROM   custom_booth_item_link cl
            JOIN   media m ON m.id = cl.thumbnail_media_id
            WHERE  cl.custom_booth_item_id IN (SELECT id FROM #CustomItems)
              AND  cl.thumbnail_media_id IS NOT NULL;

        -- ── Portal dependents ─────────────────────────────────────────
        -- 1. portal_access_mtx.portal_id → portal.id
        DELETE FROM portal_access_mtx
        WHERE portal_id IN (SELECT id FROM #Portals);

        -- 2. portal_link.portal_id → portal.id; portal_link.thumbnail_media_id → media.id
        DELETE FROM portal_link
        WHERE portal_id IN (SELECT id FROM #Portals);

        -- 3. Thumbnail media_localization
        DELETE FROM media_localization
        WHERE media_id IN (SELECT media_id FROM #ThumbMedia);

        -- 4. Thumbnail media
        DELETE FROM media
        WHERE id IN (SELECT media_id FROM #ThumbMedia);

        -- 5. Thumbnail i18n — text_key
        DELETE FROM i18n
        WHERE [key] IN (SELECT text_key FROM #ThumbMedia WHERE text_key IS NOT NULL)
          AND space_id = @SpaceId;

        -- 6. Thumbnail i18n — description_key
        DELETE FROM i18n
        WHERE [key] IN (SELECT description_key FROM #ThumbMedia WHERE description_key IS NOT NULL)
          AND space_id = @SpaceId;

        -- 7. Portal i18n — text_field_key
        DELETE FROM i18n
        WHERE [key] IN (SELECT text_field_key FROM #Portals)
          AND space_id = @SpaceId;

        -- 8. Portals
        DELETE FROM portal
        WHERE id IN (SELECT id FROM #Portals) AND space_id = @SpaceId;

        -- ── Corresponding media (portal FK now cleared) ────────────────
        -- 9. Corresponding media_localization
        DELETE FROM media_localization
        WHERE media_id IN (SELECT corresponding_media_id FROM #Portals WHERE corresponding_media_id IS NOT NULL);

        -- 10. Corresponding media
        DELETE FROM media
        WHERE id IN (SELECT corresponding_media_id FROM #Portals WHERE corresponding_media_id IS NOT NULL);

        -- 11. Corresponding media i18n — text_key
        DELETE FROM i18n
        WHERE [key] IN (SELECT corr_text_key FROM #Portals WHERE corr_text_key IS NOT NULL)
          AND space_id = @SpaceId;

        -- 12. Corresponding media i18n — description_key
        DELETE FROM i18n
        WHERE [key] IN (SELECT corr_desc_key FROM #Portals WHERE corr_desc_key IS NOT NULL)
          AND space_id = @SpaceId;

        -- ── Booth dependents ────────────────────────────────────────────
        -- 13. booth_comment.booth_id → booth.id
        DELETE FROM booth_comment WHERE booth_id = @BoothId;

        -- 14. user_booth_activity_mtx.booth_id → booth.id
        DELETE FROM user_booth_activity_mtx WHERE booth_id = @BoothId;

        -- 15. Booth media_localization
        DELETE FROM media_localization
        WHERE media_id IN (SELECT media_id FROM #BoothMedia);

        -- 16. booth_media.booth_id → booth.id
        DELETE FROM booth_media WHERE booth_id = @BoothId;

        -- 17. Booth media
        DELETE FROM media
        WHERE id IN (SELECT media_id FROM #BoothMedia);

        -- 18. Booth media i18n — text_key
        DELETE FROM i18n
        WHERE [key] IN (SELECT text_key FROM #BoothMedia WHERE text_key IS NOT NULL)
          AND space_id = @SpaceId;

        -- 19. Booth media i18n — description_key
        DELETE FROM i18n
        WHERE [key] IN (SELECT description_key FROM #BoothMedia WHERE description_key IS NOT NULL)
          AND space_id = @SpaceId;

        -- ── Custom item dependents ───────────────────────────────────────
        -- 20. Custom item links FIRST — they FK to custom_booth_item, must precede step 23
        -- (mirrors step 2's portal_link → portal ordering).
        DELETE FROM custom_booth_item_link
        WHERE custom_booth_item_id IN (SELECT id FROM #CustomItems);

        -- 21. Custom item link thumbnail media_localization
        DELETE FROM media_localization
        WHERE media_id IN (SELECT media_id FROM #CustomLinkThumbs);

        -- 22. Custom item link thumbnail media
        DELETE FROM media
        WHERE id IN (SELECT media_id FROM #CustomLinkThumbs);

        -- 23. Custom item rows themselves — clears their corresponding_media_id FK
        DELETE FROM custom_booth_item
        WHERE id IN (SELECT id FROM #CustomItems);

        -- 24. Custom item link thumbnail i18n
        DELETE FROM i18n
        WHERE [key] IN (SELECT text_key FROM #CustomLinkThumbs WHERE text_key IS NOT NULL)
          AND space_id = @SpaceId;
        DELETE FROM i18n
        WHERE [key] IN (SELECT description_key FROM #CustomLinkThumbs WHERE description_key IS NOT NULL)
          AND space_id = @SpaceId;

        -- 25. Custom item corresponding media_localization
        DELETE FROM media_localization
        WHERE media_id IN (SELECT corresponding_media_id FROM #CustomItems);

        -- 26. Custom item corresponding media
        DELETE FROM media
        WHERE id IN (SELECT corresponding_media_id FROM #CustomItems);

        -- 27. Custom item name/description i18n
        DELETE FROM i18n
        WHERE [key] IN (SELECT name_key FROM #CustomItems)
          AND space_id = @SpaceId;
        DELETE FROM i18n
        WHERE [key] IN (SELECT description_key FROM #CustomItems WHERE description_key IS NOT NULL)
          AND space_id = @SpaceId;

        -- 28. Booth i18n — name_key
        DELETE FROM i18n
        WHERE [key] = (SELECT name_key FROM booth WHERE id = @BoothId)
          AND space_id = @SpaceId;

        -- 29. Booth — must be last; all FKs pointing to booth.id are cleared above
        DELETE FROM booth WHERE id = @BoothId AND space_id = @SpaceId;

        DROP TABLE #Portals;
        DROP TABLE #ThumbMedia;
        DROP TABLE #BoothMedia;
        DROP TABLE #CustomItems;
        DROP TABLE #CustomLinkThumbs;

        COMMIT TRANSACTION;
        SELECT 1 AS success;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#Portals')          IS NOT NULL DROP TABLE #Portals;
        IF OBJECT_ID('tempdb..#ThumbMedia')       IS NOT NULL DROP TABLE #ThumbMedia;
        IF OBJECT_ID('tempdb..#BoothMedia')       IS NOT NULL DROP TABLE #BoothMedia;
        IF OBJECT_ID('tempdb..#CustomItems')      IS NOT NULL DROP TABLE #CustomItems;
        IF OBJECT_ID('tempdb..#CustomLinkThumbs') IS NOT NULL DROP TABLE #CustomLinkThumbs;
        THROW;
    END CATCH
END;

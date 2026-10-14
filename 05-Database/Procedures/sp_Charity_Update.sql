CREATE   PROCEDURE [dbo].[sp_Charity_Update]
    @SpaceId     INT,
    @CharityId   INT,
    @WebsiteUrl  NVARCHAR(500)  = NULL,
    @DonationUrl NVARCHAR(500)  = NULL,
    @IsActive    BIT            = NULL,
    @ModifiedBy  NVARCHAR(255)  = NULL,
    @RemoveLogo  BIT            = 0,
    @I18nName    NVARCHAR(MAX)  = NULL,
    @I18nDesc    NVARCHAR(MAX)  = NULL,
    @Media       NVARCHAR(MAX)  = NULL,
    @ForceStatus VARCHAR(20)    = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- ── 1. Lock and load ──────────────────────────────────────────
        DECLARE @NameKey        UNIQUEIDENTIFIER;
        DECLARE @DescKey        UNIQUEIDENTIFIER;
        DECLARE @CurrentMediaId BIGINT;

        SELECT
            @NameKey        = name_key,
            @DescKey        = description_key,
            @CurrentMediaId = logo_media_id
        FROM charity WITH (UPDLOCK, ROWLOCK, HOLDLOCK)
        WHERE id       = @CharityId
          AND space_id = @SpaceId
          AND is_deleted = 0;

        -- Return 0 if not found; the UPDLOCK guarantees the check and
        -- the subsequent writes run against the same locked snapshot.
        IF @NameKey IS NULL
        BEGIN
            COMMIT TRANSACTION;
            SELECT 0 AS found;
            RETURN;
        END;

        -- ── 2. i18n — name ───────────────────────────────────────────
        -- NULL  = caller omitted this field; leave i18n untouched.
        -- '[]'  = wipe all name translations (step a runs, b-1/b-2 produce 0 rows).
        IF @I18nName IS NOT NULL
        BEGIN
            -- Step a: soft-delete all active translations for this key
            UPDATE i18n
            SET    is_deleted = 1
            WHERE  [key]      = @NameKey
              AND  space_id   = @SpaceId
              AND  is_deleted = 0;

            -- Step b-1: re-activate rows whose locale is in the payload
            UPDATE i18n
            SET    is_deleted = 0,
                   [value]    = j.[value]
            FROM   i18n
            INNER JOIN OPENJSON(@I18nName) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j ON i18n.locale_id = j.locale_id
            WHERE  i18n.[key]    = @NameKey
              AND  i18n.space_id = @SpaceId;

            -- Step b-2: insert locales that have never had a physical row.
            -- LEFT JOIN anti-join instead of NOT EXISTS: j.locale_id stays in a
            -- JOIN ON clause (resolved correctly) rather than inside a correlated
            -- subquery (where some SQL Server builds fail to bind the OPENJSON alias).
            INSERT INTO i18n ([key], locale_id, [value], space_id)
            SELECT @NameKey, j.locale_id, j.[value], @SpaceId
            FROM   OPENJSON(@I18nName) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j
            LEFT JOIN i18n x
                ON  x.[key]     = @NameKey
                AND x.locale_id = j.locale_id
                AND x.space_id  = @SpaceId
            WHERE x.locale_id IS NULL;
        END;

        -- ── 3. i18n — description (same 3-step pattern) ──────────────
        IF @I18nDesc IS NOT NULL
        BEGIN
            UPDATE i18n
            SET    is_deleted = 1
            WHERE  [key]      = @DescKey
              AND  space_id   = @SpaceId
              AND  is_deleted = 0;

            UPDATE i18n
            SET    is_deleted = 0,
                   [value]    = j.[value]
            FROM   i18n
            INNER JOIN OPENJSON(@I18nDesc) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j ON i18n.locale_id = j.locale_id
            WHERE  i18n.[key]    = @DescKey
              AND  i18n.space_id = @SpaceId;

            INSERT INTO i18n ([key], locale_id, [value], space_id)
            SELECT @DescKey, j.locale_id, j.[value], @SpaceId
            FROM   OPENJSON(@I18nDesc) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j
            LEFT JOIN i18n x
                ON  x.[key]     = @DescKey
                AND x.locale_id = j.locale_id
                AND x.space_id  = @SpaceId
            WHERE x.locale_id IS NULL;
        END;

        -- ── 4. Media ─────────────────────────────────────────────────
        DECLARE @NewMediaId BIGINT = NULL;

        IF @RemoveLogo = 1 AND @Media IS NULL
        BEGIN
            -- Explicit logo removal: soft-delete old media_localization
            -- and media, then clear logo_media_id in the UPDATE below.
            IF @CurrentMediaId IS NOT NULL
            BEGIN
                UPDATE media_localization
                SET    is_deleted = 1
                WHERE  media_id   = @CurrentMediaId
                  AND  is_deleted = 0;

                UPDATE media
                SET    is_deleted = 1
                WHERE  id         = @CurrentMediaId
                  AND  space_id   = @SpaceId
                  AND  is_deleted = 0;
            END;
            -- @NewMediaId stays NULL → CASE sets logo_media_id = NULL
        END
        ELSE IF @Media IS NOT NULL
        BEGIN
            DECLARE @MediaId      BIGINT        = CAST(JSON_VALUE(@Media, '$.id')             AS BIGINT);
            DECLARE @MediaTypeId  INT           = CAST(JSON_VALUE(@Media, '$.media_type_id')  AS INT);
            DECLARE @MediaTextKey NVARCHAR(MAX) =      JSON_VALUE(@Media, '$.text_key');
            DECLARE @MediaDescKey NVARCHAR(MAX) =      JSON_VALUE(@Media, '$.description_key');
            DECLARE @MediaLocs    NVARCHAR(MAX) =      JSON_QUERY(@Media, '$.link_localizations');

            IF @MediaId IS NULL OR @MediaId = 0
            BEGIN
                -- Insert a brand-new media row; SCOPE_IDENTITY() captures its id.
                INSERT INTO media (space_id, media_type_id, text_key, description_key)
                VALUES (
                    @SpaceId,
                    @MediaTypeId,
                    TRY_CAST(@MediaTextKey AS UNIQUEIDENTIFIER),
                    TRY_CAST(@MediaDescKey AS UNIQUEIDENTIFIER)
                );
                SET @NewMediaId = SCOPE_IDENTITY();
            END
            ELSE
            BEGIN
                SET @NewMediaId = @MediaId;

                -- Update existing media row metadata directly (no COALESCE —
                -- text_key and description_key are always overwritten).
                UPDATE media
                SET    media_type_id   = @MediaTypeId,
                       text_key        = TRY_CAST(@MediaTextKey AS UNIQUEIDENTIFIER),
                       description_key = TRY_CAST(@MediaDescKey AS UNIQUEIDENTIFIER)
                WHERE  id       = @MediaId
                  AND  space_id = @SpaceId
                  AND  is_deleted = 0;

                IF @@ROWCOUNT = 0
                    THROW 50001, 'Media record not found in this space or is already deleted.', 1;
            END;

            -- media_localization 3-step (same pattern as i18n and sp_Portal_Update).
            -- NULL link_localizations = leave media_localization untouched.
            -- []   link_localizations = wipe all (step a runs, b-1/b-2 produce 0 rows).
            IF @MediaLocs IS NOT NULL
            BEGIN
                -- Step a: soft-delete all active localizations for this media
                UPDATE media_localization
                SET    is_deleted = 1
                WHERE  media_id   = @NewMediaId
                  AND  is_deleted = 0;

                -- Step b-1: re-activate rows whose locale is in the payload
                UPDATE media_localization
                SET    is_deleted = 0,
                       media_link = j.media_link
                FROM   media_localization
                INNER JOIN OPENJSON(@MediaLocs) WITH (
                    locale_id  NVARCHAR(20)  '$.locale_id',
                    media_link NVARCHAR(MAX) '$.media_link'
                ) j ON media_localization.locale_id = j.locale_id
                WHERE  media_localization.media_id = @NewMediaId;

                -- Step b-2: insert locales that have never had a physical row
                INSERT INTO media_localization (media_id, locale_id, media_link)
                SELECT @NewMediaId, j.locale_id, j.media_link
                FROM   OPENJSON(@MediaLocs) WITH (
                    locale_id  NVARCHAR(20)  '$.locale_id',
                    media_link NVARCHAR(MAX) '$.media_link'
                ) j
                LEFT JOIN media_localization x
                    ON  x.media_id  = @NewMediaId
                    AND x.locale_id = j.locale_id
                WHERE x.locale_id IS NULL;
            END;

            -- Soft-delete the orphaned old media when a brand-new row was
            -- inserted (id=0 path). Skipped when updating the same media row.
            IF @CurrentMediaId IS NOT NULL AND @CurrentMediaId <> @NewMediaId
            BEGIN
                UPDATE media_localization
                SET    is_deleted = 1
                WHERE  media_id   = @CurrentMediaId
                  AND  is_deleted = 0;

                UPDATE media
                SET    is_deleted = 1
                WHERE  id         = @CurrentMediaId
                  AND  space_id   = @SpaceId
                  AND  is_deleted = 0;
            END;
        END;

        -- ── 5. Update charity row ─────────────────────────────────────
        -- COALESCE: NULL parameter = leave column unchanged.
        -- CASE on logo_media_id: COALESCE alone cannot set a column to NULL
        -- (COALESCE(NULL, col) always returns col), so the CASE expression
        -- handles the three distinct states explicitly.
        UPDATE charity
        SET
            website_url   = COALESCE(@WebsiteUrl,  website_url),
            donation_url  = COALESCE(@DonationUrl, donation_url),
            is_active     = COALESCE(@IsActive,    is_active),
            logo_media_id = CASE
                                WHEN @RemoveLogo = 1 AND @Media IS NULL THEN NULL
                                WHEN @Media IS NOT NULL                  THEN @NewMediaId
                                ELSE                                          logo_media_id
                            END,
            modified_time = SYSUTCDATETIME(),
            modified_by   = ISNULL(@ModifiedBy, modified_by),
            [status]      = ISNULL(@ForceStatus, [status])
        WHERE id       = @CharityId
          AND space_id = @SpaceId
          AND is_deleted = 0;

        COMMIT TRANSACTION;
        SELECT 1 AS found;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

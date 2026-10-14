CREATE   PROCEDURE [dbo].[sp_Charity_Create]
    @SpaceId     INT,
    @NameKey     UNIQUEIDENTIFIER,
    @DescKey     UNIQUEIDENTIFIER,
    @WebsiteUrl  NVARCHAR(500)  = NULL,
    @DonationUrl NVARCHAR(500)  = NULL,
    @IsActive    BIT            = 1,
    @ModifiedBy  NVARCHAR(255)  = NULL,
    @CreatedBy   NVARCHAR(255)  = NULL,
    @I18nName    NVARCHAR(MAX)  = NULL,
    @I18nDesc    NVARCHAR(MAX)  = NULL,
    @Media       NVARCHAR(MAX)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- ── 1. Media ─────────────────────────────────────────────────
        DECLARE @NewMediaId BIGINT = NULL;

        IF @Media IS NOT NULL
        BEGIN
            DECLARE @MediaId      BIGINT        = CAST(JSON_VALUE(@Media, '$.id')             AS BIGINT);
            DECLARE @MediaTypeId  INT           = CAST(JSON_VALUE(@Media, '$.media_type_id')  AS INT);
            DECLARE @MediaTextKey NVARCHAR(MAX) =      JSON_VALUE(@Media, '$.text_key');
            DECLARE @MediaDescKey NVARCHAR(MAX) =      JSON_VALUE(@Media, '$.description_key');
            DECLARE @MediaLocs    NVARCHAR(MAX) =      JSON_QUERY(@Media, '$.link_localizations');

            IF @MediaId IS NULL OR @MediaId = 0
            BEGIN
                -- Insert a brand-new media row and capture its identity.
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
                -- Attach an existing media row (rare on create, but supported).
                SET @NewMediaId = @MediaId;
            END;

            -- Insert media_localization rows from the JSON array.
            -- Simple INSERT...SELECT — no soft-delete step needed since these
            -- are brand-new rows for a brand-new media record.
            IF @MediaLocs IS NOT NULL AND @NewMediaId IS NOT NULL
            BEGIN
                INSERT INTO media_localization (media_id, locale_id, media_link)
                SELECT @NewMediaId, j.locale_id, j.media_link
                FROM OPENJSON(@MediaLocs) WITH (
                    locale_id  NVARCHAR(20)  '$.locale_id',
                    media_link NVARCHAR(MAX) '$.media_link'
                ) j;
            END;
        END;

        -- ── 2. Insert charity ─────────────────────────────────────────
        INSERT INTO charity
            (space_id, name_key, description_key, website_url, logo_media_id,
             donation_url, is_active, modified_time, modified_by,
             created_by, created_time, [status])
        VALUES
            (@SpaceId, @NameKey, @DescKey, @WebsiteUrl, @NewMediaId,
             @DonationUrl, ISNULL(@IsActive, 1), SYSUTCDATETIME(), ISNULL(@ModifiedBy, 'system'),
             ISNULL(@CreatedBy, 'system'), SYSUTCDATETIME(), 'draft');

        DECLARE @NewId INT = CAST(SCOPE_IDENTITY() AS INT);

        -- ── 3. i18n — name ───────────────────────────────────────────
        -- Plain INSERT...SELECT: no prior rows exist for @NameKey, so no
        -- soft-delete or re-activate steps are required.
        IF @I18nName IS NOT NULL
        BEGIN
            INSERT INTO i18n ([key], locale_id, [value], space_id)
            SELECT @NameKey, j.locale_id, j.[value], @SpaceId
            FROM OPENJSON(@I18nName) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j;
        END;

        -- ── 4. i18n — description ─────────────────────────────────────
        IF @I18nDesc IS NOT NULL
        BEGIN
            INSERT INTO i18n ([key], locale_id, [value], space_id)
            SELECT @DescKey, j.locale_id, j.[value], @SpaceId
            FROM OPENJSON(@I18nDesc) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j;
        END;

        COMMIT TRANSACTION;
        SELECT @NewId AS new_id;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

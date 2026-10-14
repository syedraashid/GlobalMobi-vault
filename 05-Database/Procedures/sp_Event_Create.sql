-- ============================================================
-- SECTION 1 — Event CRUD/read
-- ============================================================

CREATE   PROCEDURE [dbo].[sp_Event_Create]
    @SpaceId         INT,
    @PlatformTypeId  INT,
    @EventTypeId     INT,
    @EventUrl        NVARCHAR(MAX)  = NULL,
    @IsLive          BIT            = 0,
    @SubtitleEnabled BIT            = NULL,
    @ScheduledLength INT,
    @ScheduledStart  DATETIME2(7),
    @ScheduledEnd    DATETIME2(7),
    @ActualStart     DATETIME2(7)   = NULL,
    @ActualEnd       DATETIME2(7)   = NULL,
    @Rating          DECIMAL(2,1)   = NULL,
    @Capacity        INT            = NULL,
    @EventFormatId   INT            = NULL,
    @NameKey         UNIQUEIDENTIFIER,
    @DescriptionKey  UNIQUEIDENTIFIER = NULL,
    @ModifiedBy      NVARCHAR(255)  = NULL,
    @CreatedBy       NVARCHAR(255)  = NULL,
    @I18nName        NVARCHAR(MAX)  = NULL,
    @I18nDescription NVARCHAR(MAX)  = NULL,
    @HostingStreamUrl NVARCHAR(2048) = NULL,
    -- Personality is a reusable entity-owned record (created/edited via the standalone
    -- /api/personality endpoints, not here) — this just links to one that already exists.
    @PersonalityId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO [event]
            (space_id, platform_type_id, event_type_id, personality_id,
             localized_name_id, description_id, event_url, is_live, subtitle_enabled,
             scheduled_length, scheduled_start_datetime, scheduled_end_datetime,
             actual_start_datetime, actual_end_datetime, rating, capacity, event_format_id,
             modified_time, modified_by, created_by, created_time, [status])
        VALUES
            (@SpaceId, @PlatformTypeId, @EventTypeId, @PersonalityId,
             @NameKey, @DescriptionKey, @EventUrl, CAST(@IsLive AS CHAR(1)), @SubtitleEnabled,
             @ScheduledLength, @ScheduledStart, @ScheduledEnd,
             @ActualStart, @ActualEnd, @Rating, @Capacity, @EventFormatId,
             SYSUTCDATETIME(), ISNULL(@ModifiedBy, 'system'), ISNULL(@CreatedBy, 'system'), SYSUTCDATETIME(), 'draft');

        DECLARE @NewId INT = CAST(SCOPE_IDENTITY() AS INT);

        IF @I18nName IS NOT NULL
        BEGIN
            INSERT INTO i18n ([key], locale_id, [value], space_id)
            SELECT @NameKey, j.locale_id, j.[value], @SpaceId
            FROM OPENJSON(@I18nName) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j;
        END;

        IF @I18nDescription IS NOT NULL AND @DescriptionKey IS NOT NULL
        BEGIN
            INSERT INTO i18n ([key], locale_id, [value], space_id)
            SELECT @DescriptionKey, j.locale_id, j.[value], @SpaceId
            FROM OPENJSON(@I18nDescription) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j;
        END;

        -- Inline delivery: creating an event with a stream URL creates its linked Hosting
        -- record in the same save, so the CMS user never has to hop to a separate page.
        -- Reuses the event's own name_key for the hosting row's name (same displayed text).
        IF @HostingStreamUrl IS NOT NULL AND LEN(@HostingStreamUrl) > 0
        BEGIN
            INSERT INTO hosting
                (space_id, event_id, name_key, stream_url, is_active,
                 modified_time, modified_by, created_by, created_time, [status])
            VALUES
                (@SpaceId, @NewId, @NameKey, @HostingStreamUrl, 1,
                 SYSUTCDATETIME(), ISNULL(@ModifiedBy, 'system'), ISNULL(@CreatedBy, 'system'), SYSUTCDATETIME(), 'draft');
        END;

        COMMIT TRANSACTION;
        SELECT @NewId AS new_id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

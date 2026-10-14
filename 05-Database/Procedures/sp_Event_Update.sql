CREATE   PROCEDURE [dbo].[sp_Event_Update]
    @SpaceId         INT,
    @EventId         INT,
    @PlatformTypeId  INT            = NULL,
    @EventTypeId     INT            = NULL,
    @EventUrl        NVARCHAR(MAX)  = NULL,
    @IsLive          BIT            = NULL,
    @SubtitleEnabled BIT            = NULL,
    @ScheduledLength INT            = NULL,
    @ScheduledStart  DATETIME2(7)   = NULL,
    @ScheduledEnd    DATETIME2(7)   = NULL,
    @ActualStart     DATETIME2(7)   = NULL,
    @ActualEnd       DATETIME2(7)   = NULL,
    @Rating          DECIMAL(2,1)   = NULL,
    @Capacity        INT            = NULL,
    @EventFormatId   INT            = NULL,
    @ModifiedBy      NVARCHAR(255)  = NULL,
    @I18nName        NVARCHAR(MAX)  = NULL,
    @I18nDescription NVARCHAR(MAX)  = NULL,
    @ForceStatus     VARCHAR(20)    = NULL,
    @HostingStreamUrl NVARCHAR(2048) = NULL,
    -- Unlike every other column above (COALESCE — NULL means "not supplied, leave
    -- unchanged"), this one is always overwritten unconditionally: the CMS dropdown
    -- always sends an explicit value on every save (a real id, or NULL for "no
    -- personality"), never omits it, so NULL here genuinely means "clear the link."
    @PersonalityId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Lock and load — fixes the orphaned-i18n-write bug: nothing below runs if the row is missing.
        DECLARE @NameKey UNIQUEIDENTIFIER, @DescKey UNIQUEIDENTIFIER;

        SELECT @NameKey = localized_name_id, @DescKey = description_id
        FROM [event] WITH (UPDLOCK, ROWLOCK, HOLDLOCK)
        WHERE id = @EventId AND space_id = @SpaceId AND is_deleted = 0;

        IF @NameKey IS NULL
        BEGIN
            COMMIT TRANSACTION;
            SELECT 0 AS found;
            RETURN;
        END;

        -- i18n — name (3-step soft-delete pattern, mirrors sp_Hosting_Update)
        IF @I18nName IS NOT NULL
        BEGIN
            UPDATE i18n SET is_deleted = 1 WHERE [key] = @NameKey AND space_id = @SpaceId AND is_deleted = 0;

            UPDATE i18n
            SET is_deleted = 0, [value] = j.[value]
            FROM i18n
            INNER JOIN OPENJSON(@I18nName) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j ON i18n.locale_id = j.locale_id
            WHERE i18n.[key] = @NameKey AND i18n.space_id = @SpaceId;

            INSERT INTO i18n ([key], locale_id, [value], space_id)
            SELECT @NameKey, j.locale_id, j.[value], @SpaceId
            FROM OPENJSON(@I18nName) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j
            LEFT JOIN i18n x ON x.[key] = @NameKey AND x.locale_id = j.locale_id AND x.space_id = @SpaceId
            WHERE x.locale_id IS NULL;
        END;

        -- i18n — description, same pattern, only if a description key exists on the row
        IF @I18nDescription IS NOT NULL AND @DescKey IS NOT NULL
        BEGIN
            UPDATE i18n SET is_deleted = 1 WHERE [key] = @DescKey AND space_id = @SpaceId AND is_deleted = 0;

            UPDATE i18n
            SET is_deleted = 0, [value] = j.[value]
            FROM i18n
            INNER JOIN OPENJSON(@I18nDescription) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j ON i18n.locale_id = j.locale_id
            WHERE i18n.[key] = @DescKey AND i18n.space_id = @SpaceId;

            INSERT INTO i18n ([key], locale_id, [value], space_id)
            SELECT @DescKey, j.locale_id, j.[value], @SpaceId
            FROM OPENJSON(@I18nDescription) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j
            LEFT JOIN i18n x ON x.[key] = @DescKey AND x.locale_id = j.locale_id AND x.space_id = @SpaceId
            WHERE x.locale_id IS NULL;
        END;

        -- Update event row — COALESCE: NULL parameter = leave column unchanged
        UPDATE [event]
        SET
            platform_type_id         = COALESCE(@PlatformTypeId, platform_type_id),
            event_type_id            = COALESCE(@EventTypeId, event_type_id),
            event_url                = COALESCE(@EventUrl, event_url),
            is_live                  = COALESCE(CAST(@IsLive AS CHAR(1)), is_live),
            subtitle_enabled         = COALESCE(@SubtitleEnabled, subtitle_enabled),
            scheduled_length         = COALESCE(@ScheduledLength, scheduled_length),
            scheduled_start_datetime = COALESCE(@ScheduledStart, scheduled_start_datetime),
            scheduled_end_datetime   = COALESCE(@ScheduledEnd, scheduled_end_datetime),
            actual_start_datetime    = COALESCE(@ActualStart, actual_start_datetime),
            actual_end_datetime      = COALESCE(@ActualEnd, actual_end_datetime),
            rating                   = COALESCE(@Rating, rating),
            capacity                 = COALESCE(@Capacity, capacity),
            event_format_id          = COALESCE(@EventFormatId, event_format_id),
            personality_id           = @PersonalityId,
            modified_time            = SYSUTCDATETIME(),
            modified_by              = ISNULL(@ModifiedBy, modified_by),
            [status]                 = ISNULL(@ForceStatus, [status])
        WHERE id = @EventId AND space_id = @SpaceId AND is_deleted = 0;

        -- Inline delivery, same as sp_Event_Create: update the linked hosting's stream URL
        -- if one already exists, otherwise create one now (an event that started with no
        -- delivery can have one added later, from the same Event edit form).
        -- NULL = param not supplied, leave hosting untouched (matches the COALESCE columns above).
        -- '' (empty string) = explicit clear — deactivate delivery without losing the row/history.
        IF @HostingStreamUrl IS NOT NULL
        BEGIN
            IF LEN(@HostingStreamUrl) = 0
            BEGIN
                UPDATE hosting
                SET is_active = 0, modified_time = SYSUTCDATETIME(), modified_by = ISNULL(@ModifiedBy, modified_by)
                WHERE event_id = @EventId AND is_deleted = 0;
            END
            ELSE IF EXISTS (SELECT 1 FROM hosting WHERE event_id = @EventId AND is_deleted = 0)
            BEGIN
                UPDATE hosting
                SET stream_url = @HostingStreamUrl, is_active = 1, modified_time = SYSUTCDATETIME(), modified_by = ISNULL(@ModifiedBy, modified_by)
                WHERE event_id = @EventId AND is_deleted = 0;
            END
            ELSE
            BEGIN
                INSERT INTO hosting
                    (space_id, event_id, name_key, stream_url, is_active,
                     modified_time, modified_by, created_by, created_time, [status])
                VALUES
                    (@SpaceId, @EventId, @NameKey, @HostingStreamUrl, 1,
                     SYSUTCDATETIME(), ISNULL(@ModifiedBy, 'system'), ISNULL(@ModifiedBy, 'system'), SYSUTCDATETIME(), 'draft');
            END;
        END;

        COMMIT TRANSACTION;
        SELECT 1 AS found;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

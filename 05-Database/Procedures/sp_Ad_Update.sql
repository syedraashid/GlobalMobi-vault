CREATE   PROCEDURE [dbo].[sp_Ad_Update]
    @SpaceId         INT,
    @AdId            INT,
    @PlacementId     INT           = NULL,
    @DurationSeconds INT           = NULL,
    @MediaTypeId     INT           = NULL,
    @ModifiedBy      NVARCHAR(255) = NULL,
    @MediaLinks      NVARCHAR(MAX) = NULL,
    @I18nName        NVARCHAR(MAX) = NULL,
    @ForceStatus     VARCHAR(20)   = NULL,
    @ScheduleDates   NVARCHAR(MAX) = NULL,
    @Today           DATE          = NULL,
    @ModelId         INT           = NULL,
    @Portal          NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    SET @Today = ISNULL(@Today, CAST(SYSDATETIMEOFFSET() AT TIME ZONE 'Eastern Standard Time' AS DATE));
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @NameKey         UNIQUEIDENTIFIER;
        DECLARE @MediaId         BIGINT;
        DECLARE @CurStart        DATE; DECLARE @CurEnd DATE;
        DECLARE @CurPlacementId  INT;
        DECLARE @CurStatus       VARCHAR(20);
        DECLARE @CurDuration     INT;
        DECLARE @CurMediaType    INT;
        DECLARE @CurModelId      INT;
        SELECT @NameKey = ad.name_key, @MediaId = ad.media_id,
               @CurStart = c.start_date, @CurEnd = c.end_date,
               @CurPlacementId = ad.placement_id,
               @CurStatus = ad.[status], @CurDuration = ad.duration_seconds, @CurModelId = ad.model_id
        FROM advertiser_ad ad WITH (UPDLOCK, ROWLOCK, HOLDLOCK)
        INNER JOIN advertiser_campaign c ON c.id = ad.campaign_id AND c.is_deleted = 0
        INNER JOIN advertiser a          ON a.id = c.advertiser_id AND a.space_id = @SpaceId AND a.is_deleted = 0
        WHERE ad.id = @AdId AND ad.is_deleted = 0;
        IF @NameKey IS NULL BEGIN COMMIT TRANSACTION; SELECT 0 AS found; RETURN; END;
        SELECT @CurMediaType = m.media_type_id FROM media m WHERE m.id = @MediaId;

        IF @PlacementId IS NOT NULL AND @PlacementId <> @CurPlacementId
           AND NOT EXISTS (SELECT 1 FROM ad_placement WITH (HOLDLOCK, ROWLOCK)
                           WHERE id = @PlacementId AND space_id = @SpaceId AND is_deleted = 0)
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 52101, 'Placement not found in this space.', 1;
        END;

        DECLARE @Is3d BIT = (SELECT is_3d FROM ad_placement WHERE id = COALESCE(@PlacementId, @CurPlacementId));
        DECLARE @Who VARCHAR(36) = ISNULL(@ModifiedBy, 'system');
        DECLARE @PortalStatus VARCHAR(20) = ISNULL(@ForceStatus, @CurStatus);
        IF @Is3d = 1
        BEGIN
            IF COALESCE(@ModelId, @CurModelId) IS NULL
            BEGIN
                ROLLBACK TRANSACTION;
                THROW 52110, 'A 3D placement requires a 3D model.', 1;
            END;
            IF @ModelId IS NOT NULL AND @ModelId <> ISNULL(@CurModelId, -1)
               AND NOT EXISTS (SELECT 1 FROM ad_3d_model WITH (HOLDLOCK, ROWLOCK)
                               WHERE id = @ModelId AND space_id = @SpaceId AND is_deleted = 0 AND is_active = 1)
            BEGIN
                ROLLBACK TRANSACTION;
                THROW 52111, 'The selected 3D model was not found or is inactive.', 1;
            END;
            SET @MediaTypeId = 4;
            SET @MediaLinks  = NULL;
        END
        ELSE
        BEGIN
            IF @ModelId IS NOT NULL OR @Portal IS NOT NULL
            BEGIN
                ROLLBACK TRANSACTION;
                THROW 52112, 'A 2D placement can''t have a 3D model.', 1;
            END;
            IF COALESCE(@MediaTypeId, @CurMediaType) = 4
            BEGIN
                ROLLBACK TRANSACTION;
                THROW 52114, 'The 3D Model media type can''t be used on a 2D placement.', 1;
            END;
        END;
        IF @ScheduleDates IS NOT NULL AND LEN(@ScheduleDates) > 2
           AND EXISTS (SELECT 1
                       FROM   OPENJSON(@ScheduleDates) WITH (run_date NVARCHAR(20) '$.run_date') j
                       WHERE  ISDATE(j.run_date) = 1
                         AND  CAST(j.run_date AS DATE) >= @Today
                         AND  CAST(j.run_date AS DATE) NOT BETWEEN @CurStart AND @CurEnd)
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 52103, 'Run dates must fall inside the campaign dates.', 1;
        END;

        IF @CurStatus = 'approved'
           AND EXISTS (SELECT 1 FROM ad_schedule_dates WHERE ad_id = @AdId AND is_deleted = 0 AND run_date <= @Today)
           AND (   (@PlacementId     IS NOT NULL AND @PlacementId     <> @CurPlacementId)
                OR (@DurationSeconds IS NOT NULL AND @DurationSeconds <> @CurDuration)
                OR (@MediaTypeId     IS NOT NULL AND @MediaTypeId     <> ISNULL(@CurMediaType, -1)))
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 52104, 'This ad has already started running, so its placement, duration and media type can no longer be changed. Create a new ad instead.', 1;
        END;

        IF @ScheduleDates IS NOT NULL AND LEN(@ScheduleDates) > 2
           AND EXISTS (SELECT 1 FROM ad_placement WHERE id = COALESCE(@PlacementId, @CurPlacementId) AND is_deleted = 1)
           AND EXISTS (SELECT 1
                       FROM   OPENJSON(@ScheduleDates) WITH (run_date NVARCHAR(20) '$.run_date') j
                       WHERE  ISDATE(j.run_date) = 1 AND CAST(j.run_date AS DATE) >= @Today)
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 52105, 'This ad''s placement was removed, so no new run dates can be scheduled for it. Create a new ad instead.', 1;
        END;
        DECLARE @EffPlacementId INT = COALESCE(@PlacementId, @CurPlacementId);

        IF @MediaTypeId IS NOT NULL
        BEGIN
            UPDATE media
            SET    media_type_id = @MediaTypeId
            WHERE  id = @MediaId AND is_deleted = 0;
        END;
        IF @I18nName IS NOT NULL
        BEGIN
            UPDATE i18n SET is_deleted = 1
            WHERE [key] = @NameKey AND space_id = @SpaceId AND is_deleted = 0;
            UPDATE i18n SET is_deleted = 0, [value] = j.[value]
            FROM i18n
            INNER JOIN OPENJSON(@I18nName) WITH (locale_id NVARCHAR(20) '$.locale_id', [value] NVARCHAR(MAX) '$.value') j
                ON i18n.locale_id = j.locale_id
            WHERE i18n.[key] = @NameKey AND i18n.space_id = @SpaceId;
            INSERT INTO i18n ([key], locale_id, [value], space_id)
            SELECT @NameKey, j.locale_id, j.[value], @SpaceId
            FROM OPENJSON(@I18nName) WITH (locale_id NVARCHAR(20) '$.locale_id', [value] NVARCHAR(MAX) '$.value') j
            LEFT JOIN i18n x ON x.[key] = @NameKey AND x.locale_id = j.locale_id AND x.space_id = @SpaceId
            WHERE x.locale_id IS NULL;
        END;
        IF @MediaLinks IS NOT NULL
        BEGIN
            UPDATE media_localization SET is_deleted = 1
            WHERE media_id = @MediaId AND is_deleted = 0;
            UPDATE media_localization SET is_deleted = 0, media_link = j.media_link
            FROM media_localization
            INNER JOIN OPENJSON(@MediaLinks) WITH (locale_id NVARCHAR(20) '$.locale_id', media_link NVARCHAR(2048) '$.media_link') j
                ON media_localization.locale_id = j.locale_id
            WHERE media_localization.media_id = @MediaId;
            INSERT INTO media_localization (media_id, locale_id, media_link)
            SELECT @MediaId, j.locale_id, j.media_link
            FROM OPENJSON(@MediaLinks) WITH (locale_id NVARCHAR(20) '$.locale_id', media_link NVARCHAR(2048) '$.media_link') j
            LEFT JOIN media_localization x ON x.media_id = @MediaId AND x.locale_id = j.locale_id
            WHERE x.locale_id IS NULL;
        END;
        IF @Is3d = 1
            UPDATE media_localization SET is_deleted = 1, modified_by = @Who, modified_time = SYSUTCDATETIME()
            WHERE media_id = @MediaId AND is_deleted = 0;
        UPDATE advertiser_ad
        SET placement_id     = COALESCE(@PlacementId, placement_id),
            duration_seconds = COALESCE(@DurationSeconds, duration_seconds),
            modified_time    = SYSUTCDATETIME(),
            modified_by      = ISNULL(@ModifiedBy, modified_by),
            [status]         = ISNULL(@ForceStatus, [status]),
            model_id         = CASE WHEN @Is3d = 1 THEN COALESCE(@ModelId, model_id) ELSE NULL END
        WHERE id = @AdId AND is_deleted = 0;
        IF @Is3d = 1
        BEGIN
            IF @Portal IS NOT NULL
                EXEC dbo.sp_AdPortal_Apply @SpaceId = @SpaceId, @AdId = @AdId, @Portal = @Portal, @Status = @PortalStatus, @ModifiedBy = @Who;
            ELSE IF @ForceStatus IS NOT NULL
            BEGIN
                UPDATE portal SET [status] = @ForceStatus, modified_by = @Who, modified_time = SYSUTCDATETIME()
                WHERE ad_id = @AdId AND is_deleted = 0 AND [status] <> @ForceStatus;
                UPDATE pl SET pl.[status] = @ForceStatus, pl.modified_by = @Who, pl.modified_time = SYSUTCDATETIME()
                FROM portal_link pl INNER JOIN portal p ON p.id = pl.portal_id
                WHERE p.ad_id = @AdId AND p.is_deleted = 0 AND pl.is_deleted = 0 AND pl.[status] <> @ForceStatus;
            END;
        END
        ELSE IF EXISTS (SELECT 1 FROM portal WHERE ad_id = @AdId AND is_deleted = 0)
            EXEC dbo.sp_AdPortal_Remove @AdId = @AdId, @ModifiedBy = @Who;   -- 3D -> 2D: soft-delete the whole portal chain

        IF @ScheduleDates IS NOT NULL
        BEGIN
            DELETE FROM ad_schedule_dates WHERE ad_id = @AdId AND (run_date >= @Today OR @CurStatus <> 'approved');
            IF LEN(@ScheduleDates) > 2
            BEGIN
                INSERT INTO ad_schedule_dates (ad_id, run_date)
                SELECT @AdId, CAST(j.run_date AS DATE)
                FROM   OPENJSON(@ScheduleDates) WITH (run_date NVARCHAR(20) '$.run_date') j
                WHERE  ISDATE(j.run_date) = 1
                  AND  CAST(j.run_date AS DATE) >= @Today;
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

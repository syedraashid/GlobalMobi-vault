CREATE   PROCEDURE [dbo].[sp_Ad_Create]
    @SpaceId         INT,
    @CampaignId      INT,
    @NameKey         UNIQUEIDENTIFIER,
    @PlacementId     INT,
    @DurationSeconds INT           = 30,
    @MediaTypeId     INT           = 1,
    @ModifiedBy      NVARCHAR(255) = NULL,
    @CreatedBy       NVARCHAR(255) = NULL,
    @MediaLinks      NVARCHAR(MAX) = NULL,
    @I18nName        NVARCHAR(MAX) = NULL,
    @ScheduleDates   NVARCHAR(MAX) = NULL,
    @Today           DATE          = NULL,
    @ModelId         INT           = NULL,
    @Portal          NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    SET @Today = ISNULL(@Today, CAST(SYSDATETIMEOFFSET() AT TIME ZONE 'Eastern Standard Time' AS DATE));   -- HISTORY
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @CurStart DATE; DECLARE @CurEnd DATE;
        SELECT @CurStart = c.start_date, @CurEnd = c.end_date
        FROM advertiser_campaign c
        INNER JOIN advertiser a ON a.id = c.advertiser_id AND a.space_id = @SpaceId AND a.is_active = 1 AND a.is_deleted = 0
        WHERE c.id = @CampaignId AND c.is_deleted = 0;
        IF @CurStart IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 50000, 'Campaign not found or advertiser is inactive.', 1;
        END;
        IF NOT EXISTS (SELECT 1 FROM ad_placement WITH (HOLDLOCK, ROWLOCK)
                       WHERE id = @PlacementId AND space_id = @SpaceId AND is_deleted = 0)
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 52101, 'Placement not found in this space.', 1;
        END;
        DECLARE @Is3d BIT = (SELECT is_3d FROM ad_placement WHERE id = @PlacementId);
        IF @Is3d = 1
        BEGIN
            IF @ModelId IS NULL
            BEGIN
                ROLLBACK TRANSACTION;
                THROW 52110, 'A 3D placement requires a 3D model.', 1;
            END;
            IF NOT EXISTS (SELECT 1 FROM ad_3d_model WITH (HOLDLOCK, ROWLOCK)
                           WHERE id = @ModelId AND space_id = @SpaceId AND is_deleted = 0 AND is_active = 1)
            BEGIN
                ROLLBACK TRANSACTION;
                THROW 52111, 'The selected 3D model was not found or is inactive.', 1;
            END;
            SET @MediaTypeId = 4;      -- a 3D ad has no media URL: its media row stays empty
            SET @MediaLinks  = NULL;
        END
        ELSE
        BEGIN
            IF @ModelId IS NOT NULL OR @Portal IS NOT NULL
            BEGIN
                ROLLBACK TRANSACTION;
                THROW 52112, 'A 2D placement can''t have a 3D model.', 1;
            END;
            IF @MediaTypeId = 4
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
        INSERT INTO media (media_type_id, space_id, is_deleted) VALUES (@MediaTypeId, @SpaceId, 0);
        DECLARE @NewMediaId BIGINT = CAST(SCOPE_IDENTITY() AS BIGINT);
        IF @MediaLinks IS NOT NULL
        BEGIN
            INSERT INTO media_localization (media_id, locale_id, media_link)
            SELECT @NewMediaId, j.locale_id, j.media_link
            FROM OPENJSON(@MediaLinks) WITH (locale_id NVARCHAR(20) '$.locale_id', media_link NVARCHAR(2048) '$.media_link') j;
        END;
        INSERT INTO advertiser_ad
            (campaign_id, name_key, placement_id, duration_seconds, media_id, is_deleted, modified_time, modified_by,
             created_by, created_time, [status], model_id)
        VALUES
            (@CampaignId, @NameKey, @PlacementId, ISNULL(@DurationSeconds, 30), @NewMediaId, 0, SYSUTCDATETIME(), ISNULL(@ModifiedBy, 'system'),
             ISNULL(@CreatedBy, 'system'), SYSUTCDATETIME(), 'draft', CASE WHEN @Is3d = 1 THEN @ModelId END);
        DECLARE @NewId INT = CAST(SCOPE_IDENTITY() AS INT);
        IF @I18nName IS NOT NULL
        BEGIN
            INSERT INTO i18n ([key], locale_id, [value], space_id)
            SELECT @NameKey, j.locale_id, j.[value], @SpaceId
            FROM OPENJSON(@I18nName) WITH (locale_id NVARCHAR(20) '$.locale_id', [value] NVARCHAR(MAX) '$.value') j;
        END;
        IF @Is3d = 1 AND @Portal IS NOT NULL
        BEGIN
            DECLARE @Who VARCHAR(36) = ISNULL(@ModifiedBy, 'system');
            EXEC dbo.sp_AdPortal_Apply @SpaceId = @SpaceId, @AdId = @NewId, @Portal = @Portal, @Status = 'draft', @ModifiedBy = @Who;
        END;
        IF @ScheduleDates IS NOT NULL AND LEN(@ScheduleDates) > 2
        BEGIN
            INSERT INTO ad_schedule_dates (ad_id, run_date)
            SELECT @NewId, CAST(j.run_date AS DATE)
            FROM   OPENJSON(@ScheduleDates) WITH (run_date NVARCHAR(20) '$.run_date') j
            WHERE  ISDATE(j.run_date) = 1
              AND  CAST(j.run_date AS DATE) >= @Today;
        END;
        COMMIT TRANSACTION;
        SELECT @NewId AS new_id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

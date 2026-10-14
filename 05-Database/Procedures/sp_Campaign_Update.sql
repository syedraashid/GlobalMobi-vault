CREATE   PROCEDURE [dbo].[sp_Campaign_Update]
    @SpaceId          INT,
    @CampaignId       INT,
    @DailyRate        DECIMAL(18,2) = NULL,
    @DurationModifier DECIMAL(5,2)  = NULL,
    @StartDate        DATE          = NULL,
    @EndDate          DATE          = NULL,
    @ModifiedBy       NVARCHAR(255) = NULL,
    @I18nName         NVARCHAR(MAX) = NULL,
    @ForceStatus      VARCHAR(20)   = NULL,
    @AdCleanupMode    VARCHAR(20)   = NULL,
    @AdIds            NVARCHAR(MAX) = NULL,
    @Today            DATE          = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    SET @Today = ISNULL(@Today, CAST(SYSDATETIMEOFFSET() AT TIME ZONE 'Eastern Standard Time' AS DATE));
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @NameKey     UNIQUEIDENTIFIER;
        DECLARE @CurRate     DECIMAL(18,2);
        DECLARE @CurModifier DECIMAL(5,2);
        DECLARE @CurStart    DATE;
        DECLARE @CurEnd      DATE;
        DECLARE @CurStatus   VARCHAR(20);
        SELECT @NameKey = c.name_key, @CurRate = c.daily_rate, @CurModifier = c.duration_modifier,
               @CurStart = c.start_date, @CurEnd = c.end_date, @CurStatus = c.[status]
        FROM advertiser_campaign c WITH (UPDLOCK, ROWLOCK, HOLDLOCK)
        INNER JOIN advertiser a ON a.id = c.advertiser_id AND a.space_id = @SpaceId AND a.is_deleted = 0
        WHERE c.id = @CampaignId AND c.is_deleted = 0;
        IF @NameKey IS NULL BEGIN COMMIT TRANSACTION; SELECT 0 AS found; RETURN; END;
        DECLARE @EffRate     DECIMAL(18,2) = COALESCE(@DailyRate, @CurRate);
        DECLARE @EffModifier DECIMAL(5,2) = COALESCE(@DurationModifier, @CurModifier);
        DECLARE @EffStart    DATE          = COALESCE(@StartDate, @CurStart);
        DECLARE @EffEnd      DATE          = COALESCE(@EndDate, @CurEnd);
        DECLARE @NewCPD      DECIMAL(18,2) = @EffRate * @EffModifier;
        DECLARE @NewTotal    DECIMAL(18,2) = @NewCPD * (DATEDIFF(day, @EffStart, @EffEnd) + 1);


        IF @EffStart <> @CurStart OR @EffEnd <> @CurEnd
        BEGIN
            IF @CurStatus = 'approved'
            BEGIN
                IF @Today > @CurEnd
                BEGIN
                    THROW 52203, 'This campaign has ended, so its start and end dates can no longer be changed.', 1;
                END;

                IF @Today >= @CurStart
                BEGIN
                    IF @EffStart <> @CurStart
                    BEGIN
                        THROW 52203, 'This campaign has already started, so its start date can no longer be changed.', 1;
                    END;
                    IF @EffEnd <> @CurEnd AND @EffEnd <= @Today
                    BEGIN
                        THROW 52203, 'The end date of a campaign that has started can only be shortened down to tomorrow.', 1;
                    END;
                END
                ELSE IF @EffStart <> @CurStart AND @EffStart < @Today
                BEGIN
                    THROW 52203, 'The start date cannot be moved to a date in the past.', 1;
                END;
            END
            ELSE
            BEGIN
                -- Never approved, so it has never run: it is not locked, but a date that is SET must not be in the past.
                IF @EffStart <> @CurStart AND @EffStart < @Today
                BEGIN
                    THROW 52203, 'The start date cannot be moved to a date in the past.', 1;
                END;
                IF @EffEnd <> @CurEnd AND @EffEnd < @Today
                BEGIN
                    THROW 52203, 'The end date cannot be moved to a date in the past.', 1;
                END;
            END;
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
        UPDATE advertiser_campaign
        SET daily_rate        = @EffRate,
            duration_modifier = @EffModifier,
            cost_per_day      = @NewCPD,
            total_cost        = @NewTotal,
            start_date        = @EffStart,
            end_date          = @EffEnd,
            modified_time     = SYSUTCDATETIME(),
            modified_by       = ISNULL(@ModifiedBy, modified_by),
            [status]          = ISNULL(@ForceStatus, [status])
        WHERE id = @CampaignId AND is_deleted = 0;

        IF @AdCleanupMode IS NOT NULL AND @AdIds IS NOT NULL
        BEGIN
            IF @AdCleanupMode NOT IN ('prune_dates', 'delete_all')
                THROW 52201, 'Invalid ad cleanup mode. Expected prune_dates or delete_all.', 1;

            DECLARE @Targets TABLE (ad_id INT PRIMARY KEY);
            INSERT INTO @Targets (ad_id)
            SELECT DISTINCT ad.id
            FROM   OPENJSON(@AdIds) WITH (ad_id INT '$') j
            INNER JOIN advertiser_ad ad ON ad.id = j.ad_id AND ad.campaign_id = @CampaignId AND ad.is_deleted = 0;


            IF EXISTS (SELECT 1
                       FROM   @Targets t
                       INNER JOIN content_approval ca ON ca.content_type = 'ad' AND ca.content_id = t.ad_id AND ca.[status] = 'pending')
                THROW 52202, 'An ad in this campaign is awaiting approval. Resolve it before changing the campaign dates.', 1;

            IF @AdCleanupMode = 'prune_dates'
            BEGIN

                DELETE s
                FROM   ad_schedule_dates s
                INNER JOIN @Targets t ON t.ad_id = s.ad_id
                WHERE  (s.run_date < @EffStart OR s.run_date > @EffEnd)
                  AND  s.run_date >= @Today;
            END
            ELSE
            BEGIN

                CREATE TABLE #AdPortalTargets (ad_id INT NOT NULL PRIMARY KEY);
                INSERT #AdPortalTargets (ad_id) SELECT ad_id FROM @Targets;
                DECLARE @Who VARCHAR(36) = ISNULL(@ModifiedBy, 'system');
                EXEC dbo.sp_AdPortal_RemoveForAds @ModifiedBy = @Who;
                UPDATE ml SET ml.is_deleted = 1
                FROM   media_localization ml
                INNER JOIN advertiser_ad ad ON ad.media_id = ml.media_id
                INNER JOIN @Targets t       ON t.ad_id = ad.id
                WHERE  ml.is_deleted = 0;

                UPDATE m SET m.is_deleted = 1
                FROM   media m
                INNER JOIN advertiser_ad ad ON ad.media_id = m.id
                INNER JOIN @Targets t       ON t.ad_id = ad.id
                WHERE  m.is_deleted = 0;

                UPDATE i18n SET is_deleted = 1
                FROM   i18n
                INNER JOIN advertiser_ad ad ON ad.name_key = i18n.[key]
                INNER JOIN @Targets t       ON t.ad_id = ad.id
                WHERE  i18n.space_id = @SpaceId AND i18n.is_deleted = 0;

                DELETE s
                FROM   ad_schedule_dates s
                INNER JOIN @Targets t ON t.ad_id = s.ad_id
                WHERE  s.run_date >= @Today;

                UPDATE ad
                SET    ad.is_deleted    = 1,
                       ad.modified_time = SYSUTCDATETIME(),
                       ad.modified_by   = ISNULL(@ModifiedBy, ad.modified_by)
                FROM   advertiser_ad ad
                INNER JOIN @Targets t ON t.ad_id = ad.id;
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

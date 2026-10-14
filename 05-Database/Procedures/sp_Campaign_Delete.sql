CREATE   PROCEDURE [dbo].[sp_Campaign_Delete]
    @SpaceId    INT,
    @CampaignId INT,
    @Today      DATE = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    SET @Today = ISNULL(@Today, CAST(SYSDATETIMEOFFSET() AT TIME ZONE 'Eastern Standard Time' AS DATE));
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @NameKey UNIQUEIDENTIFIER;
        DECLARE @CurStatus VARCHAR(20);
        DECLARE @CurStart DATE;
        SELECT @NameKey = c.name_key, @CurStatus = c.[status], @CurStart = c.start_date
        FROM advertiser_campaign c WITH (UPDLOCK, ROWLOCK, HOLDLOCK)
        INNER JOIN advertiser a ON a.id = c.advertiser_id AND a.space_id = @SpaceId AND a.is_deleted = 0
        WHERE c.id = @CampaignId AND c.is_deleted = 0;
        IF @NameKey IS NULL BEGIN COMMIT TRANSACTION; SELECT 0 AS found; RETURN; END;


        IF @CurStatus = 'approved' AND @CurStart <= @Today
        BEGIN
            THROW 52204, 'This campaign has already started, so it can no longer be deleted.', 1;
        END;


        CREATE TABLE #AdPortalTargets (ad_id INT NOT NULL PRIMARY KEY);
        INSERT #AdPortalTargets (ad_id) SELECT ad.id FROM advertiser_ad ad WHERE ad.campaign_id = @CampaignId AND ad.is_deleted = 0;
        EXEC dbo.sp_AdPortal_RemoveForAds @ModifiedBy = 'system';

        UPDATE ml
        SET    ml.is_deleted = 1
        FROM   media_localization ml
        INNER JOIN advertiser_ad ad ON ad.media_id = ml.media_id AND ad.is_deleted = 0
        WHERE  ad.campaign_id = @CampaignId AND ml.is_deleted = 0;

        UPDATE m
        SET    m.is_deleted = 1
        FROM   media m
        INNER JOIN advertiser_ad ad ON ad.media_id = m.id AND ad.is_deleted = 0
        WHERE  ad.campaign_id = @CampaignId AND m.is_deleted = 0;

        UPDATE i18n
        SET    is_deleted = 1
        FROM   i18n
        INNER JOIN advertiser_ad ad ON ad.name_key = i18n.[key] AND ad.is_deleted = 0
        WHERE  ad.campaign_id = @CampaignId
          AND  i18n.space_id  = @SpaceId
          AND  i18n.is_deleted = 0;

        -- Cascade: hard-delete schedule dates for all ads in this campaign
        DELETE s
        FROM   ad_schedule_dates s
        INNER JOIN advertiser_ad ad ON ad.id = s.ad_id
        WHERE  ad.campaign_id = @CampaignId AND ad.is_deleted = 0;

        UPDATE advertiser_ad
        SET    is_deleted = 1
        WHERE  campaign_id = @CampaignId AND is_deleted = 0;

        -- Soft-delete campaign i18n and campaign
        UPDATE i18n SET is_deleted = 1
        WHERE [key] = @NameKey AND space_id = @SpaceId AND is_deleted = 0;

        UPDATE advertiser_campaign SET is_deleted = 1 WHERE id = @CampaignId AND is_deleted = 0;
        IF @@ROWCOUNT = 0 BEGIN COMMIT TRANSACTION; SELECT 0 AS found; RETURN; END;

        COMMIT TRANSACTION;
        SELECT 1 AS found;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

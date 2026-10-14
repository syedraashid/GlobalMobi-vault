CREATE   PROCEDURE [dbo].[sp_Advertiser_Delete]
    @SpaceId      INT,
    @AdvertiserId INT,
    @Today        DATE = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    SET @Today = ISNULL(@Today, CAST(SYSDATETIMEOFFSET() AT TIME ZONE 'Eastern Standard Time' AS DATE));
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @NameKey UNIQUEIDENTIFIER;
        SELECT @NameKey = name_key
        FROM advertiser WITH (UPDLOCK, ROWLOCK, HOLDLOCK)
        WHERE id = @AdvertiserId AND space_id = @SpaceId AND is_deleted = 0;
        IF @NameKey IS NULL BEGIN COMMIT TRANSACTION; SELECT 0 AS found; RETURN; END;


        IF EXISTS (SELECT 1 FROM advertiser_campaign c
                   WHERE c.advertiser_id = @AdvertiserId AND c.is_deleted = 0
                     AND c.[status] = 'approved' AND c.start_date <= @Today)
        BEGIN
            THROW 52204, 'This advertiser has a campaign that has already started, so it can no longer be deleted.', 1;
        END;

        CREATE TABLE #AdPortalTargets (ad_id INT NOT NULL PRIMARY KEY);
        INSERT #AdPortalTargets (ad_id)
        SELECT ad.id FROM advertiser_ad ad INNER JOIN advertiser_campaign c ON c.id = ad.campaign_id AND c.advertiser_id = @AdvertiserId WHERE ad.is_deleted = 0;
        EXEC dbo.sp_AdPortal_RemoveForAds @ModifiedBy = 'system';


        UPDATE ml
        SET    ml.is_deleted = 1
        FROM   media_localization ml
        INNER JOIN advertiser_ad ad       ON ad.media_id   = ml.media_id AND ad.is_deleted = 0
        INNER JOIN advertiser_campaign c  ON c.id          = ad.campaign_id AND c.advertiser_id = @AdvertiserId
        WHERE  ml.is_deleted = 0;

        -- Cascade: soft-delete all ads' media
        UPDATE m
        SET    m.is_deleted = 1
        FROM   media m
        INNER JOIN advertiser_ad ad       ON ad.media_id   = m.id AND ad.is_deleted = 0
        INNER JOIN advertiser_campaign c  ON c.id          = ad.campaign_id AND c.advertiser_id = @AdvertiserId
        WHERE  m.is_deleted = 0;

        -- Cascade: soft-delete all ads' i18n names
        UPDATE i18n
        SET    is_deleted = 1
        FROM   i18n
        INNER JOIN advertiser_ad ad       ON ad.name_key   = i18n.[key] AND ad.is_deleted = 0
        INNER JOIN advertiser_campaign c  ON c.id          = ad.campaign_id AND c.advertiser_id = @AdvertiserId
        WHERE  i18n.space_id  = @SpaceId AND i18n.is_deleted = 0;

        -- Cascade: hard-delete schedule dates for all ads across all campaigns of this advertiser
        DELETE s
        FROM   ad_schedule_dates s
        INNER JOIN advertiser_ad ad      ON ad.id          = s.ad_id AND ad.is_deleted = 0
        INNER JOIN advertiser_campaign c ON c.id           = ad.campaign_id
                                       AND c.advertiser_id = @AdvertiserId;

        -- Cascade: soft-delete all ads
        UPDATE ad
        SET    ad.is_deleted = 1
        FROM   advertiser_ad ad
        INNER JOIN advertiser_campaign c  ON c.id = ad.campaign_id AND c.advertiser_id = @AdvertiserId
        WHERE  ad.is_deleted = 0;

        -- Cascade: soft-delete all campaigns' i18n names
        UPDATE i18n
        SET    is_deleted = 1
        FROM   i18n
        INNER JOIN advertiser_campaign c  ON c.name_key = i18n.[key] AND c.advertiser_id = @AdvertiserId AND c.is_deleted = 0
        WHERE  i18n.space_id  = @SpaceId AND i18n.is_deleted = 0;

        -- Cascade: soft-delete all campaigns
        UPDATE advertiser_campaign
        SET    is_deleted = 1
        WHERE  advertiser_id = @AdvertiserId AND is_deleted = 0;

        -- Soft-delete advertiser i18n and advertiser
        UPDATE i18n SET is_deleted = 1
        WHERE [key] = @NameKey AND space_id = @SpaceId AND is_deleted = 0;

        UPDATE advertiser SET is_deleted = 1
        WHERE id = @AdvertiserId AND space_id = @SpaceId AND is_deleted = 0;
        IF @@ROWCOUNT = 0 BEGIN COMMIT TRANSACTION; SELECT 0 AS found; RETURN; END;

        COMMIT TRANSACTION;
        SELECT 1 AS found;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

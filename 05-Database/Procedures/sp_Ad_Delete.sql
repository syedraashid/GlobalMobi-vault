CREATE   PROCEDURE [dbo].[sp_Ad_Delete]
    @SpaceId INT,
    @AdId    INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @NameKey UNIQUEIDENTIFIER; DECLARE @MediaId BIGINT;
        SELECT @NameKey = ad.name_key, @MediaId = ad.media_id
        FROM advertiser_ad ad WITH (UPDLOCK, ROWLOCK, HOLDLOCK)
        INNER JOIN advertiser_campaign c ON c.id = ad.campaign_id AND c.is_deleted = 0
        INNER JOIN advertiser a          ON a.id = c.advertiser_id AND a.space_id = @SpaceId AND a.is_deleted = 0
        WHERE ad.id = @AdId AND ad.is_deleted = 0;
        IF @NameKey IS NULL BEGIN COMMIT TRANSACTION; SELECT 0 AS found; RETURN; END;
        -- Hard-delete schedule dates before soft-deleting the ad
        DELETE FROM ad_schedule_dates WHERE ad_id = @AdId;
        UPDATE advertiser_ad SET is_deleted = 1 WHERE id = @AdId AND is_deleted = 0;
        IF @@ROWCOUNT = 0 BEGIN COMMIT TRANSACTION; SELECT 0 AS found; RETURN; END;
        UPDATE i18n SET is_deleted = 1 WHERE [key] = @NameKey AND space_id = @SpaceId AND is_deleted = 0;
        UPDATE media_localization SET is_deleted = 1 WHERE media_id = @MediaId AND is_deleted = 0;
        UPDATE media SET is_deleted = 1 WHERE id = @MediaId AND is_deleted = 0;
        -- 3D Ads: the ad's portal (links, thumbnails, title, main media) goes with it; the registry model stays
        IF EXISTS (SELECT 1 FROM portal WHERE ad_id = @AdId AND is_deleted = 0)
            EXEC dbo.sp_AdPortal_Remove @AdId = @AdId, @ModifiedBy = 'system';
        COMMIT TRANSACTION;
        SELECT 1 AS found;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

CREATE   PROCEDURE [dbo].[sp_ActiveAds_GetByDate]
    @SpaceId INT,
    @Date    DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @EffDate DATE = ISNULL(@Date, CAST(GETUTCDATE() AS DATE));
    -- RS1: active ad records with placement info
    SELECT ad.id, ap.placement_key, ap.is_3d, ad.duration_seconds, ad.media_id, m.media_type_id
    FROM   advertiser_ad       ad
    INNER JOIN ad_schedule_dates   sch ON sch.ad_id       = ad.id
                                     AND sch.run_date     = @EffDate
                                     AND sch.is_deleted   = 0   -- SOFT-DELETE
    INNER JOIN ad_placement        ap  ON ap.id           = ad.placement_id
                                     AND ap.space_id      = @SpaceId
                                     AND ap.is_deleted    = 0
    INNER JOIN advertiser_campaign c   ON c.id            = ad.campaign_id
                                     AND c.is_deleted     = 0
    INNER JOIN advertiser          a   ON a.id            = c.advertiser_id
                                     AND a.space_id       = @SpaceId
                                     AND a.is_active      = 1
                                     AND a.is_deleted     = 0
    LEFT  JOIN media               m   ON m.id            = ad.media_id
                                     AND m.is_deleted     = 0
    WHERE  ad.is_deleted  = 0
      AND  ad.[status]    = 'approved'
    ORDER BY ad.id;
    -- RS2: media links (ad_id for correlation)
    SELECT ad.id AS ad_id, ml.locale_id, ml.media_link
    FROM   advertiser_ad       ad
    INNER JOIN ad_schedule_dates   sch ON sch.ad_id       = ad.id
                                     AND sch.run_date     = @EffDate
                                     AND sch.is_deleted   = 0   -- SOFT-DELETE
    INNER JOIN ad_placement        ap  ON ap.id           = ad.placement_id
                                     AND ap.space_id      = @SpaceId
                                     AND ap.is_deleted    = 0
    INNER JOIN advertiser_campaign c   ON c.id            = ad.campaign_id
                                     AND c.is_deleted     = 0
    INNER JOIN advertiser          a   ON a.id            = c.advertiser_id
                                     AND a.space_id       = @SpaceId
                                     AND a.is_active      = 1
                                     AND a.is_deleted     = 0
    LEFT  JOIN media_localization  ml  ON ml.media_id     = ad.media_id
                                     AND ml.is_deleted    = 0
    WHERE  ad.is_deleted  = 0
      AND  ad.[status]    = 'approved'
    ORDER BY ad.id, ml.locale_id;
END;

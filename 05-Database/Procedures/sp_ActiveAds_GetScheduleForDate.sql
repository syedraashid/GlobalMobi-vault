CREATE   PROCEDURE [dbo].[sp_ActiveAds_GetScheduleForDate]
    @SpaceId      INT,
    @Date         DATE,
    @PlacementKey NVARCHAR(100) = NULL   -- NULL = all placements for this space
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @EffDate DATE = ISNULL(@Date, CAST(GETUTCDATE() AS DATE));

    -- RS1: ads + placement info + total_booked_days for priority calculation
    SELECT
        ad.id                                                        AS id,
        ad.media_id                                                  AS media_id,
        ad.duration_seconds                                          AS duration_seconds,
        ap.placement_key                                             AS placement_key,
        ap.label                                                     AS placement_label,
        ap.is_3d                                                     AS is_3d,
        m.media_type_id                                              AS media_type_id,
        mt.[type]                                                    AS media_type_name,
        ad.name_key                                                  AS name_key,
        ad.model_id                                                  AS model_id,
        mo.model_key                                                 AS model_key,
        mo.display_name                                              AS model_display_name,
        (SELECT COUNT(*)
         FROM   ad_schedule_dates s2
         WHERE  s2.ad_id = ad.id
           AND  s2.is_deleted = 0                                      -- SOFT-DELETE
           AND  s2.run_date BETWEEN c.start_date AND c.end_date)     AS total_booked_days   -- HISTORY: in-window dates only
    FROM   advertiser_ad        ad
    INNER JOIN ad_schedule_dates    sch ON sch.ad_id       = ad.id
                                      AND sch.run_date     = @EffDate
                                      AND sch.is_deleted   = 0   -- SOFT-DELETE
    INNER JOIN ad_placement         ap  ON ap.id           = ad.placement_id
                                      AND ap.space_id      = @SpaceId
                                      AND ap.is_deleted    = 0
    INNER JOIN advertiser_campaign  c   ON c.id            = ad.campaign_id
                                      AND c.is_deleted     = 0
    INNER JOIN advertiser           adv ON adv.id          = c.advertiser_id
                                      AND adv.space_id     = @SpaceId
                                      AND adv.is_active    = 1
                                      AND adv.is_deleted   = 0
    LEFT  JOIN media                m   ON m.id            = ad.media_id
                                      AND m.is_deleted     = 0
    LEFT  JOIN media_type           mt  ON mt.id           = m.media_type_id
    LEFT  JOIN ad_3d_model          mo  ON mo.id           = ad.model_id
    WHERE  ad.is_deleted         = 0
      AND  ad.[status]           = 'approved'
      AND  (@PlacementKey IS NULL OR ap.placement_key = @PlacementKey)
    ORDER BY ap.placement_key, ad.id;

    -- RS2: media links for those ads
    SELECT
        ad.id           AS ad_id,
        ad.media_id     AS media_id,
        ml.locale_id    AS locale_id,
        ml.media_link   AS media_link
    FROM   advertiser_ad        ad
    INNER JOIN ad_schedule_dates    sch ON sch.ad_id       = ad.id
                                      AND sch.run_date     = @EffDate
                                      AND sch.is_deleted   = 0   -- SOFT-DELETE
    INNER JOIN ad_placement         ap  ON ap.id           = ad.placement_id
                                      AND ap.space_id      = @SpaceId
                                      AND ap.is_deleted    = 0
    INNER JOIN advertiser_campaign  c   ON c.id            = ad.campaign_id
                                      AND c.is_deleted     = 0
    INNER JOIN advertiser           adv ON adv.id          = c.advertiser_id
                                      AND adv.is_active    = 1
                                      AND adv.is_deleted   = 0
    LEFT  JOIN media_localization   ml  ON ml.media_id     = ad.media_id
                                      AND ml.is_deleted    = 0
    WHERE  ad.is_deleted         = 0
      AND  ad.[status]           = 'approved'
      AND  (@PlacementKey IS NULL OR ap.placement_key = @PlacementKey)
    ORDER BY ad.id, ml.locale_id;

    -- RS3: the names of the scheduled 3D ads (a 3D slot shows the ad name; 2D slots carry no name)
    SELECT ad.id AS ad_id, i.locale_id AS locale_id, i.[value] AS name_value
    FROM   advertiser_ad        ad
    INNER JOIN ad_schedule_dates    sch ON sch.ad_id       = ad.id
                                      AND sch.run_date     = @EffDate
                                      AND sch.is_deleted   = 0
    INNER JOIN ad_placement         ap  ON ap.id           = ad.placement_id
                                      AND ap.space_id      = @SpaceId
                                      AND ap.is_deleted    = 0
                                      AND ap.is_3d         = 1
    INNER JOIN advertiser_campaign  c   ON c.id            = ad.campaign_id
                                      AND c.is_deleted     = 0
    INNER JOIN advertiser           adv ON adv.id          = c.advertiser_id
                                      AND adv.space_id     = @SpaceId
                                      AND adv.is_active    = 1
                                      AND adv.is_deleted   = 0
    INNER JOIN i18n                 i   ON i.[key]        = ad.name_key
                                      AND i.space_id      = @SpaceId
                                      AND i.is_deleted    = 0
    WHERE  ad.is_deleted         = 0
      AND  ad.[status]           = 'approved'
      AND  (@PlacementKey IS NULL OR ap.placement_key = @PlacementKey)
    ORDER BY ad.id, i.locale_id;

    -- 3D Ads: the ad portal
    DECLARE @AdIds TABLE (ad_id INT NOT NULL PRIMARY KEY);
    INSERT @AdIds (ad_id)
    SELECT ad.id
    FROM   advertiser_ad        ad
    INNER JOIN ad_schedule_dates    sch ON sch.ad_id       = ad.id
                                      AND sch.run_date     = @EffDate
                                      AND sch.is_deleted   = 0
    INNER JOIN ad_placement         ap  ON ap.id           = ad.placement_id
                                      AND ap.space_id      = @SpaceId
                                      AND ap.is_deleted    = 0
                                      AND ap.is_3d         = 1
    INNER JOIN advertiser_campaign  c   ON c.id            = ad.campaign_id
                                      AND c.is_deleted     = 0
    INNER JOIN advertiser           adv ON adv.id          = c.advertiser_id
                                      AND adv.space_id     = @SpaceId
                                      AND adv.is_active    = 1
                                      AND adv.is_deleted   = 0
    WHERE  ad.is_deleted         = 0
      AND  ad.[status]           = 'approved'
      AND  (@PlacementKey IS NULL OR ap.placement_key = @PlacementKey);
    -- portal row
    SELECT p.ad_id, p.id AS portal_id, p.portal_type_id, p.text_field_key AS text_key,
           cm.id AS corr_media_id, cm.media_type_id AS corr_media_type_id
    FROM   portal p
    INNER JOIN @AdIds x ON x.ad_id = p.ad_id
    LEFT JOIN media cm ON cm.id = p.corresponding_media_id AND cm.is_deleted = 0
    WHERE  p.is_deleted = 0 AND p.[status] = 'approved'
    ORDER BY p.ad_id;
    -- portal title
    SELECT p.ad_id, i.locale_id, i.[value] AS localized_text_value
    FROM   portal p
    INNER JOIN @AdIds x ON x.ad_id = p.ad_id
    INNER JOIN i18n i ON i.[key] = p.text_field_key AND i.space_id = p.space_id AND i.is_deleted = 0
    INNER JOIN supported_languages sl ON sl.space_id = p.space_id AND sl.locale_id = i.locale_id AND sl.is_deleted = 0 AND sl.event_id IS NULL
    WHERE  p.is_deleted = 0 AND p.[status] = 'approved'
    ORDER BY p.ad_id, i.locale_id;
    -- main media links
    SELECT p.ad_id, ml.locale_id, ml.media_link
    FROM   portal p
    INNER JOIN @AdIds x ON x.ad_id = p.ad_id
    INNER JOIN media_localization ml ON ml.media_id = p.corresponding_media_id AND ml.is_deleted = 0
    INNER JOIN supported_languages sl ON sl.space_id = p.space_id AND sl.locale_id = ml.locale_id AND sl.is_deleted = 0 AND sl.event_id IS NULL
    WHERE  p.is_deleted = 0 AND p.[status] = 'approved'
    ORDER BY p.ad_id, ml.locale_id;
    -- links
    SELECT p.ad_id, pl.id AS link_id, pl.position_id, pl.external_link,
           tm.id AS thumb_media_id, tm.media_type_id AS thumb_media_type_id
    FROM   portal p
    INNER JOIN @AdIds x ON x.ad_id = p.ad_id
    INNER JOIN portal_link pl ON pl.portal_id = p.id AND pl.is_deleted = 0 AND pl.[status] = 'approved'
    LEFT JOIN media tm ON tm.id = pl.thumbnail_media_id AND tm.is_deleted = 0
    WHERE  p.is_deleted = 0 AND p.[status] = 'approved'
    ORDER BY p.ad_id, pl.position_id, pl.id;
    -- link thumbnails
    SELECT p.ad_id, pl.id AS link_id, tl.locale_id, tl.media_link AS thumb_media_link
    FROM   portal p
    INNER JOIN @AdIds x ON x.ad_id = p.ad_id
    INNER JOIN portal_link pl ON pl.portal_id = p.id AND pl.is_deleted = 0 AND pl.[status] = 'approved'
    INNER JOIN media_localization tl ON tl.media_id = pl.thumbnail_media_id AND tl.is_deleted = 0
    INNER JOIN supported_languages sl ON sl.space_id = p.space_id AND sl.locale_id = tl.locale_id AND sl.is_deleted = 0 AND sl.event_id IS NULL
    WHERE  p.is_deleted = 0 AND p.[status] = 'approved'
    ORDER BY p.ad_id, pl.id, tl.locale_id;
END;

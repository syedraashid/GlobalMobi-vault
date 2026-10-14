CREATE   PROCEDURE [dbo].[sp_Ad_GetById_Unity]
    @SpaceId INT,
    @AdId    INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;

    -- RS1: ad + placement info + name translations
    SELECT
        ad.id,
        ad.campaign_id,
        ad.name_key,
        ad.placement_id,
        ap.placement_key,
        ap.is_3d,
        ad.duration_seconds,
        ad.media_id,
        m.media_type_id,
        mt.[type]       AS media_type_name,
        ad.model_id,
        mo.model_key,
        mo.display_name AS model_display_name,
        ad.modified_time,
        ad.modified_by,
        iname.locale_id AS locale_id,
        iname.[value]   AS name_value
    FROM advertiser_ad ad
    INNER JOIN ad_placement ap
           ON  ap.id        = ad.placement_id
          AND  ap.space_id  = @SpaceId
          AND  ap.is_deleted = 0
    INNER JOIN advertiser_campaign c
           ON  c.id         = ad.campaign_id
          AND  c.is_deleted = 0
    INNER JOIN advertiser a
           ON  a.id         = c.advertiser_id
          AND  a.space_id   = @SpaceId
          AND  a.is_active  = 1
          AND  a.is_deleted = 0
    LEFT JOIN media m
           ON  m.id         = ad.media_id
          AND  m.is_deleted = 0
    LEFT JOIN media_type mt ON mt.id = m.media_type_id
    LEFT JOIN ad_3d_model mo ON mo.id = ad.model_id
    LEFT JOIN i18n AS iname
           ON  iname.[key]      = ad.name_key
          AND  iname.space_id   = @SpaceId
          AND  iname.is_deleted = 0
    WHERE ad.id        = @AdId
      AND ad.is_deleted = 0
      AND ad.[status]  = 'approved'
    ORDER BY iname.locale_id;

    -- RS2: media links
    SELECT
        ml.locale_id,
        ml.media_link
    FROM advertiser_ad ad
    INNER JOIN ad_placement ap
           ON  ap.id        = ad.placement_id
          AND  ap.space_id  = @SpaceId
          AND  ap.is_deleted = 0
    INNER JOIN advertiser_campaign c
           ON  c.id         = ad.campaign_id
          AND  c.is_deleted = 0
    INNER JOIN advertiser a
           ON  a.id         = c.advertiser_id
          AND  a.space_id   = @SpaceId
          AND  a.is_active  = 1
          AND  a.is_deleted = 0
    LEFT JOIN media_localization ml
           ON  ml.media_id   = ad.media_id
          AND  ml.is_deleted = 0
    WHERE ad.id        = @AdId
      AND ad.is_deleted = 0
      AND ad.[status]  = 'approved'
    ORDER BY ml.locale_id;

    -- 3D Ads: the ad portal (appended result sets; the C# readers walk result sets by position)
    DECLARE @AdIds TABLE (ad_id INT NOT NULL PRIMARY KEY);
    INSERT @AdIds (ad_id)
    SELECT ad.id
    FROM advertiser_ad ad
    INNER JOIN ad_placement ap       ON ap.id = ad.placement_id AND ap.space_id = @SpaceId AND ap.is_deleted = 0
    INNER JOIN advertiser_campaign c ON c.id = ad.campaign_id AND c.is_deleted = 0
    INNER JOIN advertiser a          ON a.id = c.advertiser_id AND a.space_id = @SpaceId AND a.is_active = 1 AND a.is_deleted = 0
    WHERE ad.id = @AdId AND ad.is_deleted = 0 AND ad.[status] = 'approved';
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

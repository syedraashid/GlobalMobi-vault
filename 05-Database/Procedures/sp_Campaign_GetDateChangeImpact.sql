/* ----------------------------------------------------------------------------
   1. sp_Campaign_GetDateChangeImpact
   RS1: one row per live ad   (ad_id, ad_name, content_status, placement_key, has_pending_approval)
   RS2: one row per run date  (ad_id, run_date 'yyyy-MM-dd', in_range, is_history)
        is_history = the date is before @Today: it is kept, never a conflict.
   ---------------------------------------------------------------------------- */
CREATE   PROCEDURE [dbo].[sp_Campaign_GetDateChangeImpact]
    @SpaceId    INT,
    @CampaignId INT,
    @NewStart   DATE,
    @NewEnd     DATE,
    @Today      DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Today = ISNULL(@Today, CAST(SYSDATETIMEOFFSET() AT TIME ZONE 'Eastern Standard Time' AS DATE));

    SELECT ad.id                                              AS ad_id,
           nm.[value]                                         AS ad_name,
           ad.[status]                                        AS content_status,
           ap.placement_key                                   AS placement_key,
           CAST(CASE WHEN EXISTS (SELECT 1
                                  FROM   dbo.content_approval ca
                                  WHERE  ca.content_type = 'ad'
                                    AND  ca.content_id   = ad.id
                                    AND  ca.[status]     = 'pending')
                     THEN 1 ELSE 0 END AS BIT)                AS has_pending_approval
    FROM   dbo.advertiser_ad ad
    INNER JOIN dbo.advertiser_campaign c ON c.id = ad.campaign_id AND c.is_deleted = 0
    INNER JOIN dbo.advertiser a          ON a.id = c.advertiser_id AND a.space_id = @SpaceId AND a.is_deleted = 0
    LEFT  JOIN dbo.ad_placement ap       ON ap.id = ad.placement_id
    OUTER APPLY (SELECT TOP 1 i.[value]
                 FROM   dbo.i18n i
                 WHERE  i.[key] = ad.name_key AND i.space_id = @SpaceId AND i.is_deleted = 0
                 ORDER BY CASE WHEN i.locale_id LIKE 'en%' THEN 0 ELSE 1 END, i.locale_id) nm
    WHERE  ad.campaign_id = @CampaignId AND ad.is_deleted = 0
    ORDER BY ad.id;

    SELECT s.ad_id,
           CONVERT(VARCHAR(10), s.run_date, 120)                                        AS run_date,
           CAST(CASE WHEN s.run_date BETWEEN @NewStart AND @NewEnd THEN 1 ELSE 0 END AS BIT) AS in_range,
           CAST(CASE WHEN s.run_date < @Today THEN 1 ELSE 0 END AS BIT)                     AS is_history
    FROM   dbo.ad_schedule_dates s
    INNER JOIN dbo.advertiser_ad ad      ON ad.id = s.ad_id AND ad.campaign_id = @CampaignId AND ad.is_deleted = 0
    INNER JOIN dbo.advertiser_campaign c ON c.id = ad.campaign_id AND c.is_deleted = 0
    INNER JOIN dbo.advertiser a          ON a.id = c.advertiser_id AND a.space_id = @SpaceId AND a.is_deleted = 0
    WHERE  s.is_deleted = 0
    ORDER BY s.ad_id, s.run_date;
END;

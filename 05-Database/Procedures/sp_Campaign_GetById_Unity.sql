CREATE   PROCEDURE [dbo].[sp_Campaign_GetById_Unity]
    @SpaceId    INT,
    @CampaignId INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;

    SELECT
        c.id,
        c.advertiser_id,
        c.name_key,
        c.daily_rate,
        c.duration_modifier,
        c.cost_per_day,
        c.total_cost,
        c.start_date,
        c.end_date,
        c.modified_time,
        c.modified_by,
        CASE
            WHEN c.start_date > CAST(GETUTCDATE() AS date) THEN 'Upcoming'
            WHEN c.end_date   < CAST(GETUTCDATE() AS date) THEN 'Expired'
            ELSE 'Active'
        END AS campaign_schedule_status,
        iname.locale_id AS locale_id,
        iname.[value]   AS name_value
    FROM advertiser_campaign c
    INNER JOIN advertiser a
           ON  a.id        = c.advertiser_id
          AND  a.space_id  = @SpaceId
          AND  a.is_active = 1
          AND  a.is_deleted = 0
    LEFT JOIN i18n AS iname
           ON iname.[key]      = c.name_key
          AND iname.space_id   = @SpaceId
          AND iname.is_deleted = 0
    WHERE c.id         = @CampaignId
      AND c.is_deleted = 0
      AND c.[status]   = 'approved'
    ORDER BY iname.locale_id;
END;

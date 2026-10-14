CREATE   PROCEDURE [dbo].[sp_Campaign_GetById]
    @SpaceId    INT,
    @CampaignId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.id, c.advertiser_id, c.name_key, c.daily_rate, c.duration_modifier,
           c.cost_per_day, c.total_cost, c.start_date, c.end_date,
           c.modified_time, c.modified_by,
           CASE WHEN c.start_date > CAST(GETUTCDATE() AS date) THEN 'Upcoming'
                WHEN c.end_date   < CAST(GETUTCDATE() AS date) THEN 'Expired'
                ELSE 'Active' END AS campaign_schedule_status,
           iname.locale_id AS locale_id, iname.[value] AS name_value,
           COALESCE(ca.[status], c.[status]) AS approval_status, ca.id AS approval_id, ca.[action_type] AS approval_action_type,
           ca.[current_snapshot] AS current_snapshot, ca.[proposed_snapshot] AS proposed_snapshot,
           c.[status] AS content_status
    FROM advertiser_campaign c
    INNER JOIN advertiser a ON a.id = c.advertiser_id AND a.space_id = @SpaceId AND a.is_active = 1 AND a.is_deleted = 0
    LEFT JOIN i18n AS iname ON iname.[key] = c.name_key AND iname.space_id = @SpaceId AND iname.is_deleted = 0
    LEFT JOIN dbo.content_approval ca ON ca.content_type = 'campaign' AND ca.content_id = c.id AND ca.[status] != 'withdrawn'
    WHERE c.id = @CampaignId AND c.is_deleted = 0
    ORDER BY iname.locale_id;
END;

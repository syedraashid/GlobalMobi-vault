CREATE   PROCEDURE [dbo].[sp_Advertiser_GetBySpace]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT a.id, a.space_id, a.name_key, a.is_active, a.industry, a.modified_time, a.modified_by,
           iname.locale_id AS locale_id, iname.[value] AS name_value,
           COALESCE(ca.[status], a.[status]) AS approval_status, ca.id AS approval_id, ca.[action_type] AS approval_action_type,
           ca.[current_snapshot] AS current_snapshot, ca.[proposed_snapshot] AS proposed_snapshot,
           a.[status] AS content_status
    FROM advertiser a
    LEFT JOIN i18n AS iname ON iname.[key] = a.name_key AND iname.space_id = @SpaceId AND iname.is_deleted = 0
    LEFT JOIN dbo.content_approval ca ON ca.content_type = 'advertiser' AND ca.content_id = a.id AND ca.[status] != 'withdrawn'
    WHERE a.space_id = @SpaceId AND a.is_deleted = 0
    ORDER BY a.id, iname.locale_id;
END;

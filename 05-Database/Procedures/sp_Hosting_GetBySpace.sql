CREATE   PROCEDURE [dbo].[sp_Hosting_GetBySpace]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        h.id,
        h.space_id,
        h.name_key,
        h.stream_url,
        h.is_active,
        h.modified_time,
        h.modified_by,
        iname.locale_id  AS locale_id,
        iname.[value]    AS name_value,
        COALESCE(ca.[status], h.[status]) AS approval_status,
        ca.id            AS approval_id,
        ca.[action_type] AS approval_action_type,
        ca.[current_snapshot]  AS current_snapshot,
        ca.[proposed_snapshot] AS proposed_snapshot,
        h.[status]             AS content_status
    FROM hosting h
    LEFT JOIN i18n AS iname
           ON iname.[key]      = h.name_key
          AND iname.space_id   = @SpaceId
          AND iname.is_deleted = 0
    LEFT JOIN dbo.content_approval ca
           ON  ca.content_type = 'hosting'
          AND  ca.content_id   = h.id
          AND  ca.[status]    != 'withdrawn'
    WHERE h.space_id   = @SpaceId
      AND h.is_deleted = 0
    ORDER BY h.id, iname.locale_id;
END;

-- Marketing/CMS read — the space's one setting (zero or one row).
CREATE   PROCEDURE [dbo].[sp_FreeTrialSetting_SelectBySpace]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        fts.id,
        fts.space_id,
        fts.start_at,
        fts.end_at,
        fts.is_enabled,
        fts.created_time,
        fts.created_by,
        fts.modified_time,
        fts.modified_by,
        COALESCE(ca.[status], fts.[status]) AS approval_status,
        ca.id                                AS approval_id,
        ca.[action_type]                     AS approval_action_type,
        ca.[current_snapshot]                AS current_snapshot,
        ca.[proposed_snapshot]                AS proposed_snapshot,
        fts.[status]                          AS content_status
    FROM dbo.free_trial_settings fts
    LEFT JOIN dbo.content_approval ca
        ON ca.content_type = 'free_trial_setting' AND ca.content_id = fts.id AND ca.[status] != 'withdrawn'
    WHERE fts.space_id = @SpaceId AND fts.is_deleted = 0;
END

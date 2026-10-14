-- A5) sp_FreeTrialItem_SelectBySpace
CREATE   PROCEDURE [dbo].[sp_FreeTrialItem_SelectBySpace]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        fti.id,
        fti.space_id,
        fti.item_id,
        fti.package_id,
        fti.created_time,
        fti.created_by,
        fti.modified_time,
        fti.modified_by,
        COALESCE(ca.[status], fti.[status]) AS approval_status,
        ca.id                                AS approval_id,
        ca.[action_type]                     AS approval_action_type,
        ca.[current_snapshot]                AS current_snapshot,
        ca.[proposed_snapshot]                AS proposed_snapshot,
        fti.[status]                          AS content_status
    FROM dbo.free_trial_items fti
    LEFT JOIN dbo.content_approval ca
        ON ca.content_type = 'free_trial_item' AND ca.content_id = fti.id AND ca.[status] != 'withdrawn'
    WHERE fti.space_id = @SpaceId AND fti.is_deleted = 0
    ORDER BY fti.created_time;
END

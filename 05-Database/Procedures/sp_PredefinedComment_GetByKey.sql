-- =============================================================================
-- SP 3: sp_PredefinedComment_GetByKey
-- Used by : Internal reload after Create / Update
-- Notes   : INNER JOIN i18n -> Returns only if translation exists for the space.
-- =============================================================================
CREATE   PROCEDURE [dbo].[sp_PredefinedComment_GetByKey]
    @SpaceId    INT,
    @CommentKey NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        pc.id,
        pc.comment_key,
        pc.is_active,
        pc.[status]          AS content_status,
        i.locale_id,
        i.[value],
        ca.id                AS approval_id,
        ca.[status]          AS approval_status,
        ca.action_type       AS approval_action_type,
        ca.current_snapshot,
        ca.proposed_snapshot
    FROM [dbo].[predefined_comments] pc
    INNER JOIN [dbo].[i18n] i
        ON i.[key] = pc.comment_key
       AND i.space_id = @SpaceId
    LEFT JOIN [dbo].[content_approval] ca
        ON ca.content_type = 'recognition'
       AND ca.content_id = pc.id
       AND ca.space_id = @SpaceId
       AND ca.[status] IN ('pending', 'rejected')
    WHERE pc.comment_key = @CommentKey
    ORDER BY i.locale_id;
END;

-- =============================================================================
-- SP 2: sp_PredefinedComment_GetBySpace_Unity
-- Used by : Unity read path
-- =============================================================================
CREATE   PROCEDURE [dbo].[sp_PredefinedComment_GetBySpace_Unity]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        pc.id,
        pc.comment_key,
        pc.is_active,
        i.locale_id,
        i.[value]
    FROM [dbo].[predefined_comments] pc
    INNER JOIN [dbo].[i18n] i
        ON i.[key] = pc.comment_key
       AND i.space_id = @SpaceId
    WHERE pc.is_active = 1
      AND pc.[status] = 'approved'
    ORDER BY pc.id, i.locale_id;
END;

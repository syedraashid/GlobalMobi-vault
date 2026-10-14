-- ============================================================
-- usp_admin_get_user_spaces
-- Returns all active space memberships for a given user.
-- Used by frontend to determine which delete dialog to show.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_admin_get_user_spaces_for_delete]
    @UserId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        sm.space_id    AS SpaceId,
        s.display_name AS SpaceName
    FROM dbo.space_member sm
    INNER JOIN dbo.space s ON s.id = sm.space_id
    WHERE sm.user_id    = @UserId
      AND sm.is_deleted = 0
      AND s.is_deleted  = 0;
END

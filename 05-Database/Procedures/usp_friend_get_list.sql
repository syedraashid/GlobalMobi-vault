-- ============================================================
-- FRIEND SYSTEM — STORED PROCEDURES (13 total)
-- ============================================================

-- ============================================================
-- SP 1: usp_friend_get_list
-- Get all friends for a user in a space with online status
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_friend_get_list]
    @UserId  UNIQUEIDENTIFIER,
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        f.id           AS FriendshipId,
        u.id           AS UserId,
        u.username     AS Username,
        u.display_name AS DisplayName,
        u.avatar_id    AS AvatarId,
        CASE WHEN EXISTS (
            SELECT 1 FROM [dbo].[user_session_management] s
            WHERE s.user_id        = u.id
              AND s.status_id      = 1
              AND s.end_time       IS NULL
              AND s.expiration_time > SYSUTCDATETIME()
              AND s.space_id       = @SpaceId
              AND s.is_deleted     = 0
        ) THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsOnline,
        f.created_at   AS FriendsSince
    FROM [dbo].[friend] f
    JOIN [dbo].[user] u
        ON u.id = CASE WHEN f.user_id_a = @UserId THEN f.user_id_b ELSE f.user_id_a END
    WHERE (f.user_id_a = @UserId OR f.user_id_b = @UserId)
      AND f.space_id   = @SpaceId
      AND f.is_deleted = 0
      AND u.is_deleted = 0
    ORDER BY u.username ASC;
END;

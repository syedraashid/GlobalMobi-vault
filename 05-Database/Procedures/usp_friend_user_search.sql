CREATE   PROCEDURE [dbo].[usp_friend_user_search]
    @CallerId UNIQUEIDENTIFIER,
    @SpaceId  INT,
    @Query    VARCHAR(64) = '',
    @Limit    INT         = 20,
    @Offset   INT         = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        u.id           AS UserId,
        u.username     AS Username,
        u.display_name AS DisplayName,
        u.avatar_id    AS AvatarId,
        CASE WHEN EXISTS (
            SELECT 1 FROM [dbo].[user_session_management] s
            WHERE s.user_id         = u.id
              AND s.status_id       = 1
              AND s.end_time        IS NULL
              AND s.expiration_time  > SYSUTCDATETIME()
              AND s.space_id        = @SpaceId
              AND s.is_deleted      = 0
        ) THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsOnline,
        CASE
            WHEN EXISTS (
                SELECT 1 FROM [dbo].[friend] f
                WHERE ((f.user_id_a = @CallerId AND f.user_id_b = u.id)
                    OR (f.user_id_a = u.id      AND f.user_id_b = @CallerId))
                  AND f.space_id   = @SpaceId
                  AND f.is_deleted = 0
            ) THEN 'Friends'
            WHEN EXISTS (
                SELECT 1 FROM [dbo].[friend_request] fr
                JOIN [dbo].[friend_request_status] rs ON rs.id = fr.status_id
                WHERE fr.sender_id   = @CallerId
                  AND fr.receiver_id = u.id
                  AND fr.space_id    = @SpaceId
                  AND rs.status      = 'Pending'
                  AND fr.is_deleted  = 0
            ) THEN 'PendingOutgoing'
            WHEN EXISTS (
                SELECT 1 FROM [dbo].[friend_request] fr
                JOIN [dbo].[friend_request_status] rs ON rs.id = fr.status_id
                WHERE fr.sender_id   = u.id
                  AND fr.receiver_id = @CallerId
                  AND fr.space_id    = @SpaceId
                  AND rs.status      = 'Pending'
                  AND fr.is_deleted  = 0
            ) THEN 'PendingIncoming'
            ELSE 'None'
        END AS FriendshipStatus
    FROM [dbo].[user] u
    WHERE u.id            <> @CallerId
      AND ((u.oid IS NOT NULL AND u.tid IS NOT NULL) OR u.google_sub IS NOT NULL)
      AND u.is_deleted     = 0
      AND (@Query = '' OR u.username LIKE '%' + @Query + '%')
    ORDER BY IsOnline DESC, u.username ASC
    OFFSET @Offset ROWS FETCH NEXT @Limit ROWS ONLY;
END;

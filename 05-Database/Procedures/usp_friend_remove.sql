-- ============================================================
-- SP 2: usp_friend_remove
-- Soft-delete a friendship. Validates caller is one of the pair.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_friend_remove]
    @CallerId UNIQUEIDENTIFIER,
    @FriendId UNIQUEIDENTIFIER,
    @SpaceId  INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @A UNIQUEIDENTIFIER = CASE WHEN @CallerId < @FriendId THEN @CallerId ELSE @FriendId END;
    DECLARE @B UNIQUEIDENTIFIER = CASE WHEN @CallerId < @FriendId THEN @FriendId ELSE @CallerId END;

    IF NOT EXISTS (
        SELECT 1 FROM [dbo].[friend]
        WHERE user_id_a = @A AND user_id_b = @B AND space_id = @SpaceId AND is_deleted = 0
    )
    BEGIN
        RAISERROR('Friendship not found.', 16, 1);
        RETURN;
    END;

    UPDATE [dbo].[friend]
    SET is_deleted    = 1,
        modified_time = SYSUTCDATETIME(),
        modified_by   = CAST(@CallerId AS VARCHAR(36))
    WHERE user_id_a = @A AND user_id_b = @B AND space_id = @SpaceId AND is_deleted = 0;
END;

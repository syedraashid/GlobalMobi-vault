-- Atomically syncs the full role set for a space member.
-- @RoleIdsJson: JSON integer array e.g. [1,3]
-- Roles in the array not yet assigned are added.
-- Roles currently assigned but not in the array are removed.
-- Requires at least one valid (non-deleted) role in the array.
CREATE   PROCEDURE [dbo].[usp_admin_sync_member_roles]
    @SpaceId     INT,
    @UserId      UNIQUEIDENTIFIER,
    @RoleIdsJson NVARCHAR(MAX),
    @ModifiedBy  VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MemberId INT;
    SELECT @MemberId = [id]
    FROM   [dbo].[space_member]
    WHERE  [space_id] = @SpaceId AND [user_id] = @UserId AND [is_deleted] = 0;

    IF @MemberId IS NULL
    BEGIN
        RAISERROR('User is not a member of space %d.', 16, 1, @SpaceId);
        RETURN;
    END

    -- Require at least one supplied ID that maps to a live role record
    IF NOT EXISTS (
        SELECT 1
        FROM   OPENJSON(@RoleIdsJson) j
        JOIN   [dbo].[role] r ON r.[id] = CAST(j.[value] AS INT) AND r.[is_deleted] = 0
    )
    BEGIN
        RAISERROR('At least one valid role is required.', 16, 1);
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY
        -- Remove roles that are no longer in the desired set
        DELETE smr
        FROM   [dbo].[space_member_role] smr
        WHERE  smr.[space_member_id] = @MemberId
          AND  smr.[role_id] NOT IN (
                   SELECT CAST(j.[value] AS INT)
                   FROM   OPENJSON(@RoleIdsJson) j
                   JOIN   [dbo].[role] r ON r.[id] = CAST(j.[value] AS INT) AND r.[is_deleted] = 0
               );

        -- Add roles in the desired set that are not yet assigned
        INSERT INTO [dbo].[space_member_role] ([space_member_id], [role_id])
        SELECT @MemberId, CAST(j.[value] AS INT)
        FROM   OPENJSON(@RoleIdsJson) j
        JOIN   [dbo].[role] r ON r.[id] = CAST(j.[value] AS INT) AND r.[is_deleted] = 0
        WHERE  NOT EXISTS (
                   SELECT 1
                   FROM   [dbo].[space_member_role]
                   WHERE  [space_member_id] = @MemberId
                     AND  [role_id]         = CAST(j.[value] AS INT)
               );

        -- Touch the membership record so audit trails reflect the change
        UPDATE [dbo].[space_member]
        SET    [modified_time] = GETUTCDATE(),
               [modified_by]   = @ModifiedBy
        WHERE  [id] = @MemberId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END

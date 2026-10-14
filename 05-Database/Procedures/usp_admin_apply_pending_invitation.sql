CREATE   PROCEDURE [dbo].[usp_admin_apply_pending_invitation]
    @UserId     UNIQUEIDENTIFIER,
    @Email      VARCHAR(256),
    @ModifiedBy VARCHAR(36) = 'system'
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[user] WHERE [id] = @UserId AND [is_deleted] = 0)
        RETURN;

    DECLARE @IsGmsAccountant BIT = 0;
    DECLARE @CurrentEntityAdminEntityId INT = NULL;

    SELECT
        @IsGmsAccountant = CASE WHEN r.[name] = 'gms_accountant' THEN 1 ELSE 0 END,
        @CurrentEntityAdminEntityId = CASE WHEN r.[name] = 'entity_admin' THEN u.[entity_id] ELSE NULL END
    FROM [dbo].[user] u
    LEFT JOIN [dbo].[role] r ON r.[id] = u.[system_role_id] AND r.[is_deleted] = 0
    WHERE u.[id] = @UserId;

    DECLARE @HasActiveSpace BIT = CASE WHEN EXISTS (
        SELECT 1 FROM [dbo].[space_member] WHERE [user_id] = @UserId AND [is_deleted] = 0
    ) THEN 1 ELSE 0 END;

    -- Identity-level grant (gms_accountant / entity_admin — no space_id). The user
    -- row has only one system_role_id/entity_id slot, so if more than one of these
    -- is pending, the latest (highest id) still wins for this part only.
    DECLARE @IdentityInviteId INT, @IdentityEntityId INT, @IdentityRoleId INT, @IdentityRoleName VARCHAR(50);

    SELECT TOP 1
        @IdentityInviteId = pi.[id],
        @IdentityEntityId = pi.[entity_id],
        @IdentityRoleId   = pi.[role_id],
        @IdentityRoleName = r.[name]
    FROM  [dbo].[pending_invitation] pi
    JOIN  [dbo].[role] r ON r.[id] = pi.[role_id] AND r.[is_deleted] = 0
    WHERE pi.[email]       = @Email
      AND pi.[space_id]    IS NULL
      AND pi.[accepted_at] IS NULL
      AND pi.[is_deleted]  = 0
      AND pi.[expires_at]  > GETUTCDATE()
    ORDER BY pi.[id] DESC;

    IF @IdentityInviteId IS NOT NULL
    BEGIN
        -- gms_accountant: exclusive of ANY space membership, any entity.
        DECLARE @BlockGms BIT = CASE WHEN @IdentityRoleName = 'gms_accountant' AND @HasActiveSpace = 1 THEN 1 ELSE 0 END;

        -- entity_admin: blocked only by active space membership OUTSIDE the entity
        -- they're being promoted into — same-entity membership is fine.
        DECLARE @BlockEntityAdmin BIT = 0;
        IF @IdentityRoleName = 'entity_admin' AND EXISTS (
            SELECT 1
            FROM [dbo].[space_member] sm
            JOIN [dbo].[space] sp ON sp.[id] = sm.[space_id]
            WHERE sm.[user_id] = @UserId AND sm.[is_deleted] = 0
              AND sp.[entity_id] <> @IdentityEntityId
        )
            SET @BlockEntityAdmin = 1;

        IF @BlockGms = 0 AND @BlockEntityAdmin = 0
        BEGIN
            UPDATE [dbo].[user]
            SET [system_role_id] = @IdentityRoleId,
                [entity_id]      = @IdentityEntityId, -- NULL for gms_accountant, set for entity_admin
                [modified_time]  = GETUTCDATE(),
                [modified_by]    = @ModifiedBy
            WHERE [id] = @UserId;

            UPDATE [dbo].[pending_invitation]
            SET [accepted_at] = GETUTCDATE(), [modified_time] = GETUTCDATE()
            WHERE [id] = @IdentityInviteId;

            IF @IdentityRoleName = 'gms_accountant' SET @IsGmsAccountant = 1;
            IF @IdentityRoleName = 'entity_admin'    SET @CurrentEntityAdminEntityId = @IdentityEntityId;
        END
    END

    -- Space invites — apply EVERY open one EXCEPT any that would violate exclusivity:
    --   - skipped entirely (all of them) if the user is a gms_accountant
    --   - skipped for a specific space only if the user is an entity_admin of a
    --     DIFFERENT entity than that space belongs to — same-entity spaces still
    --     apply normally, one at a time, independent of each other
    IF @IsGmsAccountant = 0
    BEGIN
        DECLARE @SpaceInviteId INT, @SpaceId INT, @RoleId INT, @InvitedBy UNIQUEIDENTIFIER,
                @MemberId INT, @SpaceEntityId INT;

        DECLARE spaceCur CURSOR LOCAL FAST_FORWARD FOR
            SELECT pi.[id], pi.[space_id], pi.[role_id], pi.[invited_by]
            FROM  [dbo].[pending_invitation] pi
            WHERE pi.[email]       = @Email
              AND pi.[space_id]    IS NOT NULL
              AND pi.[accepted_at] IS NULL
              AND pi.[is_deleted]  = 0
              AND pi.[expires_at]  > GETUTCDATE()
            ORDER BY pi.[id] ASC;

        OPEN spaceCur;
        FETCH NEXT FROM spaceCur INTO @SpaceInviteId, @SpaceId, @RoleId, @InvitedBy;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @MemberId = NULL;
            SELECT @SpaceEntityId = [entity_id] FROM [dbo].[space] WHERE [id] = @SpaceId;

            IF @CurrentEntityAdminEntityId IS NULL OR @CurrentEntityAdminEntityId = @SpaceEntityId
            BEGIN
                UPDATE [dbo].[user]
                SET [entity_id]     = @SpaceEntityId,
                    [modified_time] = GETUTCDATE(),
                    [modified_by]   = @ModifiedBy
                WHERE [id] = @UserId AND [entity_id] IS NULL;

                SELECT @MemberId = [id] FROM [dbo].[space_member]
                WHERE [space_id] = @SpaceId AND [user_id] = @UserId;

                IF @MemberId IS NOT NULL
                BEGIN
                    UPDATE [dbo].[space_member]
                    SET [is_deleted]    = 0,
                        [invited_by]    = @InvitedBy,
                        [joined_at]     = GETUTCDATE(),
                        [modified_time] = GETUTCDATE(),
                        [modified_by]   = @ModifiedBy
                    WHERE [id] = @MemberId;

                    DELETE FROM [dbo].[space_member_role] WHERE [space_member_id] = @MemberId;
                    INSERT INTO [dbo].[space_member_role] ([space_member_id],[role_id]) VALUES (@MemberId,@RoleId);
                END
                ELSE
                BEGIN
                    INSERT INTO [dbo].[space_member]
                        ([space_id],[user_id],[invited_by],[joined_at],[is_deleted],[modified_time],[modified_by])
                    VALUES (@SpaceId,@UserId,@InvitedBy,GETUTCDATE(),0,GETUTCDATE(),@ModifiedBy);
                    SET @MemberId = CAST(SCOPE_IDENTITY() AS INT);
                    INSERT INTO [dbo].[space_member_role] ([space_member_id],[role_id]) VALUES (@MemberId,@RoleId);
                END

                UPDATE [dbo].[pending_invitation]
                SET [accepted_at] = GETUTCDATE(), [modified_time] = GETUTCDATE()
                WHERE [id] = @SpaceInviteId;
            END
            -- else: leave this specific space invitation pending — it conflicts with
            -- the user's entity_admin entity and is not applied.

            FETCH NEXT FROM spaceCur INTO @SpaceInviteId, @SpaceId, @RoleId, @InvitedBy;
        END

        CLOSE spaceCur;
        DEALLOCATE spaceCur;
    END
END;

-- =============================================================================
-- File   : Data/Scripts/NotInDB/SP/02_TeleportTableSP.sql
-- SPs    : sp_TeleportTable_AutoCreate
--          sp_TeleportTable_ButtonDuplicateCheck
-- Used by: SpaceSql.cs (AutoCreateTeleportTable)
--          TeleportTableSql.cs (ButtonDuplicateCheck)
--
-- Both SPs use CREATE OR ALTER — safe to re-run whether they exist or not.
-- =============================================================================


-- =============================================================================
-- SP: sp_TeleportTable_AutoCreate
-- Called inside SpaceRepository.CreateSpaceAsync within the same transaction.
-- Idempotent — if a teleport_table already exists for the space, returns its id.
-- Used by: SpaceSql.AutoCreateTeleportTable
-- =============================================================================
CREATE   PROCEDURE [dbo].[sp_TeleportTable_AutoCreate]
    @SpaceId   INT,
    @NameKey   UNIQUEIDENTIFIER,
    @CreatedBy VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.teleport_table
        WHERE space_id  = @SpaceId
          AND is_deleted = 0
    )
    BEGIN
        INSERT INTO dbo.teleport_table
            (space_id, name_key, is_active, is_deleted, modified_time, modified_by)
        VALUES
            (@SpaceId, @NameKey, 1, 0, GETUTCDATE(), @CreatedBy);

        SELECT SCOPE_IDENTITY() AS id;
    END
    ELSE
        SELECT id FROM dbo.teleport_table
        WHERE space_id  = @SpaceId
          AND is_deleted = 0;
END;

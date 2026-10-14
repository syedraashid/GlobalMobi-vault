-- =============================================================================
-- SECTION 14 — Stored Procedures: Space Config
-- =============================================================================

-- One row per space; SQL defaults handle all flags for new spaces.
CREATE   PROCEDURE [dbo].[usp_admin_seed_space_config]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM [dbo].[space_config] WHERE [space_id] = @SpaceId)
        INSERT INTO [dbo].[space_config] ([space_id]) VALUES (@SpaceId);
END

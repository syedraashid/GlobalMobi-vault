-- =============================================================================
-- File   : Data/Scripts/NotInDB/SP/01_MapSpotSPs.sql
-- SPs    : sp_MapSpot_GetAll, sp_MapSpot_Create
-- Used by: SpaceSql.cs (GetMapSpots → sp_MapSpot_GetAll, CreateMapSpot → sp_MapSpot_Create)
--
-- map_spot is GLOBAL — no space_id column. All spaces share the same set
-- of map spots. Creation and deletion is done via Unity admin APIs only.
--
-- Both SPs use CREATE OR ALTER — safe to re-run whether they exist or not.
-- =============================================================================


-- =============================================================================
-- SP: sp_MapSpot_GetAll
-- Returns all active map spots (global — not filtered by space).
-- Used by: SpaceRepository.GetMapSpotsAsync
--          GET /api/space/mapspots
-- =============================================================================
CREATE   PROCEDURE [dbo].[sp_MapSpot_GetAll]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT id, x, y, z
    FROM   dbo.map_spot
    WHERE  is_deleted = 0
    ORDER BY id;
END;

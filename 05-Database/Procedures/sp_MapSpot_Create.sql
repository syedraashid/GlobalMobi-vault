-- =============================================================================
-- SP: sp_MapSpot_Create
-- Inserts a new global map spot and returns its new id.
-- Used by: SpaceRepository.CreateMapSpotAsync
--          POST /api/space/{spaceId}/mapspots  (Unity admin only)
-- =============================================================================
CREATE   PROCEDURE [dbo].[sp_MapSpot_Create]
    @X FLOAT,
    @Y FLOAT,
    @Z FLOAT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.map_spot (x, y, z, is_deleted)
    VALUES (@X, @Y, @Z, 0);

    SELECT SCOPE_IDENTITY() AS id;
END;

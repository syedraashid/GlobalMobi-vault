-- ============================================================
-- SECTION 4 — Personality
-- ============================================================

-- Mirrors usp_Event_ExistsInSpace exactly. Used by PersonalityController when
-- creating/updating a personality with a given EntityId.
CREATE   PROCEDURE [dbo].[usp_Entity_ExistsInSpace]
    @EntityId INT,
    @SpaceId  INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) 1
    FROM entity
    WHERE id = @EntityId
      AND space_id  = @SpaceId
      AND is_deleted = 0;
END

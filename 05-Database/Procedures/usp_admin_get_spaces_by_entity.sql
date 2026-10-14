-- =============================================================================
-- SECTION 11 — Stored Procedures: Space Admin
-- =============================================================================

-- Returns: Id, EntityId, Name, MemberCount, EntityName
CREATE   PROCEDURE [dbo].[usp_admin_get_spaces_by_entity]
    @EntityId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        s.[id]                       AS Id,
        s.[entity_id]                AS EntityId,
        ISNULL(s.[display_name], '') AS Name,
        COUNT(sm.[id])               AS MemberCount,
        ISNULL(e.[name_key], '')     AS EntityName
    FROM  [dbo].[space] s
    JOIN  [dbo].[entity] e
        ON  e.[id]         = s.[entity_id]
        AND e.[is_deleted] = 0
    LEFT JOIN [dbo].[space_member] sm
        ON  sm.[space_id]   = s.[id]
        AND sm.[is_deleted] = 0
    WHERE s.[entity_id] = @EntityId
      AND s.[is_deleted] = 0
    GROUP BY s.[id], s.[entity_id], s.[display_name], e.[name_key]
    ORDER BY s.[id];
END

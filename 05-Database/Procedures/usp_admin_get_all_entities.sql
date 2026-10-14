-- =============================================================================
-- SECTION 10 — Stored Procedures: Entity Admin
-- =============================================================================

-- Returns: Id, Name, SpaceCount, MemberCount, SpaceId, SpaceName
-- One row per entity-space pair (LEFT JOIN). SpaceId/SpaceName are NULL when entity has no spaces.
-- C# groups by Id to build the nested spaces list.
CREATE   PROCEDURE [dbo].[usp_admin_get_all_entities]
AS
BEGIN
    SET NOCOUNT ON;

    WITH EntityStats AS (
        SELECT
            e.[id]                       AS Id,
            e.[name_key]                 AS Name,
            COUNT(DISTINCT s.[id])       AS SpaceCount,
            COUNT(DISTINCT sm.[user_id]) AS MemberCount
        FROM  [dbo].[entity] e
        LEFT JOIN [dbo].[space]        s  ON s.[entity_id] = e.[id]  AND s.[is_deleted]  = 0
        LEFT JOIN [dbo].[space_member] sm ON sm.[space_id] = s.[id]  AND sm.[is_deleted] = 0
        WHERE e.[is_deleted] = 0
        GROUP BY e.[id], e.[name_key]
    )
    SELECT
        es.Id,
        es.Name,
        es.SpaceCount,
        es.MemberCount,
        s.[id]                       AS SpaceId,
        ISNULL(s.[display_name], '') AS SpaceName
    FROM EntityStats es
    LEFT JOIN [dbo].[space] s ON s.[entity_id] = es.Id AND s.[is_deleted] = 0
    ORDER BY es.Id, s.[id];
END

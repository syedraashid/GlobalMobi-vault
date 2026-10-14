-- =============================================================================
-- File   : Data/Scripts/NotInDB/SP/04_AdminEntitySPs.sql
-- SPs    : 6 Admin Entity + GMS Accountant stored procedures
-- Used by: AdminSql.cs
--
-- All 6 SPs use CREATE OR ALTER — safe to re-run whether they exist or not.
-- No schema changes — table structure assumed to exist.
--
-- PREREQUISITE: pending_invitation.space_id must be nullable.
--   Run Alter/01_PendingInvitation_SpaceId_Nullable.sql before this file.
-- =============================================================================


-- =============================================================================
-- 1. usp_admin_get_entity_admins
-- Returns all active entity_admin users for a given entity.
-- AdminSql.cs: GetEntityAdmins
-- =============================================================================
CREATE   PROCEDURE [dbo].[usp_admin_get_entity_admins]
    @EntityId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        u.[id]            AS UserId,
        u.[display_name]  AS Name,
        u.[email]         AS Email,
        u.[entity_id]     AS EntityId,
        u.[modified_time] AS AssignedAt
    FROM  [dbo].[user] u
    JOIN  [dbo].[role] r
        ON  r.[id]         = u.[system_role_id]
        AND r.[name]       = 'entity_admin'
        AND r.[is_deleted] = 0
    WHERE u.[entity_id]  = @EntityId
      AND u.[is_deleted] = 0
    ORDER BY u.[modified_time] DESC;
END;

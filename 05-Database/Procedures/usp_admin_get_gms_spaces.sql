-- ---------------------------------------------------------------------
-- dbo.usp_admin_get_gms_spaces
-- ---------------------------------------------------------------------
-- Returns all active spaces (system-wide), regardless of the calling
-- gms_accountant's space_member assignments.
-- Used by the Finance Portal space picker.
-- ---------------------------------------------------------------------
CREATE PROCEDURE [dbo].[usp_admin_get_gms_spaces]
    @UserId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        s.[id]           AS SpaceId,
        s.[display_name] AS SpaceName,
        s.[entity_id]    AS EntityId,
        e.[name_key]     AS EntityName
    FROM  [dbo].[space]  s
    JOIN  [dbo].[entity] e ON e.[id] = s.[entity_id]
    WHERE s.[is_deleted] = 0
      AND e.[is_deleted] = 0
    ORDER BY EntityId, SpaceId;
END

CREATE PROCEDURE [dbo].[usp_admin_get_user_spaces]
    @UserId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        sm.[space_id]     AS SpaceId,
        s.[display_name]  AS SpaceName,
        s.[entity_id]     AS EntityId,
        e.[name_key]      AS EntityName,
        r.[name]          AS Role
    FROM  [dbo].[space_member]      sm
    JOIN  [dbo].[space]             s   ON s.[id]                = sm.[space_id]
    JOIN  [dbo].[entity]            e   ON e.[id]                = s.[entity_id]
    JOIN  [dbo].[space_member_role] smr ON smr.[space_member_id] = sm.[id]
    JOIN  [dbo].[role]              r   ON r.[id]                = smr.[role_id]
                                       AND r.[is_deleted]        = 0
    WHERE sm.[user_id]    = @UserId
      AND sm.[is_deleted] = 0
    ORDER BY sm.[space_id], r.[name];
END

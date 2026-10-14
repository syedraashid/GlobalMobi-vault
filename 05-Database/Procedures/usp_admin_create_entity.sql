-- Returns: Id, Name, SpaceCount(0), MemberCount(0)
CREATE   PROCEDURE [dbo].[usp_admin_create_entity]
    @Name VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EntityTypeId INT = (SELECT TOP 1 [id] FROM [dbo].[entity_type] ORDER BY [id]);

    INSERT INTO [dbo].[entity]
        ([entity_type_id], [name_key], [description_key], [is_deleted], [modified_time], [modified_by])
    VALUES
        (@EntityTypeId, @Name, CAST(NEWID() AS CHAR(36)), 0, GETUTCDATE(), 'admin');

    DECLARE @NewId INT = CAST(SCOPE_IDENTITY() AS INT);

    SELECT
        @NewId AS Id,
        @Name  AS Name,
        0      AS SpaceCount,
        0      AS MemberCount;
END

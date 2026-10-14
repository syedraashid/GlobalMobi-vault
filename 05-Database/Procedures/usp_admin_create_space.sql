-- Returns: Id, EntityId, Name, MemberCount(0)
CREATE   PROCEDURE [dbo].[usp_admin_create_space]
    @EntityId   INT,
    @Name       VARCHAR(255),
    @ModifiedBy VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PlatformTypeId INT = (SELECT TOP 1 [id] FROM [dbo].[platform_type] ORDER BY [id]);

    INSERT INTO [dbo].[space]
        ([platform_type_id], [entity_id], [name_key], [description_key], [link],
         [display_name], [is_published], [is_live], [is_deleted],
         [modified_time], [modified_by])
    VALUES
        (@PlatformTypeId, @EntityId, CAST(NEWID() AS CHAR(36)), CAST(NEWID() AS CHAR(36)), '',
         @Name, 0, 0, 0,
         GETUTCDATE(), @ModifiedBy);

    DECLARE @NewSpaceId INT = CAST(SCOPE_IDENTITY() AS INT);

    SELECT
        @NewSpaceId AS Id,
        @EntityId   AS EntityId,
        @Name       AS Name,
        0           AS MemberCount;
END

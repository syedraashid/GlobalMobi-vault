-- ============================================================
-- usp_Shop_InsertDefault
-- Inserts a new shop row and returns the new identity id.
-- Called only when no default shop exists for the space.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Shop_InsertDefault]
    @SpaceId        INT,
    @PlatformTypeId INT,
    @EntityId       INT           = NULL,
    @NameKey        CHAR(36),
    @ModifiedBy     NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO shop (space_id, platform_type_id, entity_id, name_key, modified_by)
    VALUES (@SpaceId, @PlatformTypeId, @EntityId, @NameKey, @ModifiedBy);
    SELECT SCOPE_IDENTITY() AS id;
END

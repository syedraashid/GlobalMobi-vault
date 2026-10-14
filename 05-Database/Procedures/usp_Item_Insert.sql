-- ============================================================
-- usp_Item_Insert
-- Inserts one item row and returns the new identity id.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Item_Insert]
    @ItemTypeId     INT,
    @EntityId       INT           = NULL,
    @SpaceId        INT,
    @NameKey        CHAR(36),
    @DescriptionKey CHAR(36)      = NULL,
    @IsAvailable    BIT,
    @TaxCategoryId  INT           = NULL,
    @TaxIsInclusive BIT           = NULL,
    @ModifiedBy     NVARCHAR(255),
    @CreatedBy      NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO item (item_type_id, entity_id, space_id, name_key, description_key,
                      is_available, tax_category_id, tax_is_inclusive, modified_by,
                      created_by, created_time, [status])
    VALUES (@ItemTypeId, @EntityId, @SpaceId, @NameKey, @DescriptionKey,
            @IsAvailable, @TaxCategoryId, @TaxIsInclusive, @ModifiedBy,
            ISNULL(@CreatedBy, 'system'), SYSUTCDATETIME(), 'draft');
    SELECT SCOPE_IDENTITY() AS id;
END

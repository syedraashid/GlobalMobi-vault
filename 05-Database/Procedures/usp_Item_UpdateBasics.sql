-- ============================================================
-- usp_Item_UpdateBasics
-- Updates the item's availability, tax fields, and optionally
-- its description_key (when a new desc key is assigned in UpdateAsync).
-- @IsAvailable: NULL = keep current; non-NULL = set to value.
-- @DescriptionKey: NULL = keep current; non-NULL = set to value.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Item_UpdateBasics]
    @ItemId         INT,
    @SpaceId        INT,
    @IsAvailable    BIT           = NULL,
    @TaxCategoryId  INT           = NULL,
    @TaxIsInclusive BIT           = NULL,
    @DescriptionKey CHAR(36)      = NULL,
    @ModifiedBy     NVARCHAR(255),
    @ForceStatus    VARCHAR(20)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE item
    SET
        is_available     = COALESCE(@IsAvailable, is_available),
        tax_category_id  = @TaxCategoryId,
        tax_is_inclusive = @TaxIsInclusive,
        description_key  = COALESCE(@DescriptionKey, description_key),
        modified_by      = @ModifiedBy,
        modified_time    = SYSUTCDATETIME(),
        [status]         = ISNULL(@ForceStatus, [status])
    WHERE id = @ItemId AND space_id = @SpaceId;
END

-- ============================================================
-- usp_Merchandise_Update
-- Updates merchandise subtype fields for an item.
-- @ThumbMediaId: explicit pass — NULL clears the thumbnail.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Merchandise_Update]
    @ItemId        INT,
    @MerchTypeId   INT           = NULL,
    @MerchCategoryId INT         = NULL,
    @AssetUrl      NVARCHAR(MAX) = NULL,
    @ThumbMediaId  BIGINT        = NULL,
    @ModifiedBy    NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE merchandise
    SET
        merchandise_type_id     = COALESCE(@MerchTypeId, merchandise_type_id),
        merchandise_category_id = COALESCE(@MerchCategoryId, merchandise_category_id),
        asset_url               = @AssetUrl,
        thumbnail_media_id      = @ThumbMediaId,
        modified_by             = @ModifiedBy
    WHERE id = @ItemId;
END

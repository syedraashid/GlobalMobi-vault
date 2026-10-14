-- ============================================================
-- usp_Merchandise_Insert
-- Inserts the merchandise subtype row (id = item.id, no identity).
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Merchandise_Insert]
    @ItemId      INT,
    @MerchTypeId INT,
    @MerchCatId  INT           = NULL,
    @AssetUrl    NVARCHAR(MAX) = NULL,
    @ThumbMediaId BIGINT       = NULL,
    @ModifiedBy  NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO merchandise (id, merchandise_type_id, merchandise_category_id,
                             asset_url, thumbnail_media_id, modified_by)
    VALUES (@ItemId, @MerchTypeId, @MerchCatId, @AssetUrl, @ThumbMediaId, @ModifiedBy);
END

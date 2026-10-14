CREATE   PROCEDURE [dbo].[usp_Avatar_Update]
    @ItemId       INT,
    @AssetUrl     NVARCHAR(MAX) = NULL,
    @ThumbMediaId BIGINT        = NULL,
    @ModifiedBy   NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.avatar
    SET
        asset_url          = COALESCE(@AssetUrl, asset_url),
        thumbnail_media_id = COALESCE(@ThumbMediaId, thumbnail_media_id),
        modified_by        = @ModifiedBy
    WHERE id = @ItemId;
END

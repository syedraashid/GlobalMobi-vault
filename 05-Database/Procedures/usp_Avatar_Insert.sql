-- ------------------------------------------------------------
-- 3) usp_Avatar_Insert / usp_Avatar_Update / usp_Avatar_GetCurrent
--    Modeled on usp_Merchandise_Insert/Update (closest shape) and
--    usp_Badge_GetCurrent (closest "read current for diffing" pattern).
-- ------------------------------------------------------------
CREATE   PROCEDURE [dbo].[usp_Avatar_Insert]
    @ItemId       INT,
    @AssetUrl     NVARCHAR(MAX),
    @ThumbMediaId BIGINT,
    @ModifiedBy   NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.avatar (id, asset_url, thumbnail_media_id, modified_by)
    VALUES (@ItemId, @AssetUrl, @ThumbMediaId, @ModifiedBy);
END

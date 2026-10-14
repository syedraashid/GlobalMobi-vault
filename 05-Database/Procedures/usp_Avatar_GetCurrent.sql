CREATE   PROCEDURE [dbo].[usp_Avatar_GetCurrent]
    @ItemId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) asset_url, thumbnail_media_id
    FROM dbo.avatar
    WHERE id = @ItemId
    ORDER BY id;
END

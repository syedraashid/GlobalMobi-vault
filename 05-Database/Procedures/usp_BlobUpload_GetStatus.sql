-- ------------------------------------------------------------
-- 4) usp_BlobUpload_GetStatus — looks up an asset by id regardless of
--    is_deleted, returning both its blob path and whether it's already
--    deleted. Lets the API return a precise 404 ("Asset not found" vs
--    "Asset already deleted") and, for a live asset, delete the actual
--    blob BEFORE marking the DB row deleted (see usp_BlobUpload_SoftDelete
--    below for why that ordering matters).
-- ------------------------------------------------------------
CREATE   PROCEDURE [dbo].[usp_BlobUpload_GetStatus]
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT blob_path, is_deleted FROM dbo.blob_upload WHERE id = @Id;
END

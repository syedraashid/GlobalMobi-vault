-- ------------------------------------------------------------
-- 3) usp_BlobUpload_ListAll — paginated, newest first, excludes
--    soft-deleted rows. Returns two result sets: total count, then
--    the requested page of rows (same shape the API's repository
--    layer expects for its Page/PageSize/TotalCount/TotalPages response).
-- ------------------------------------------------------------
CREATE   PROCEDURE [dbo].[usp_BlobUpload_ListAll]
    @Page     INT,
    @PageSize INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(*) AS TotalCount
    FROM dbo.blob_upload
    WHERE is_deleted = 0;

    SELECT id, blob_path, file_name, content_type, size_bytes, uploaded_by, uploaded_at
    FROM dbo.blob_upload
    WHERE is_deleted = 0
    ORDER BY uploaded_at DESC
    OFFSET (@Page - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END

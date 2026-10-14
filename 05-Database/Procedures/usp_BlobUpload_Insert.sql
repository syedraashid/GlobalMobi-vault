-- ------------------------------------------------------------
-- 2) usp_BlobUpload_Insert — one row per successful upload.
--    Returns the inserted row so the API can build its response DTO
--    from a single round trip.
-- ------------------------------------------------------------
CREATE   PROCEDURE [dbo].[usp_BlobUpload_Insert]
    @BlobPath    NVARCHAR(500),
    @FileName    NVARCHAR(260),
    @ContentType NVARCHAR(200),
    @SizeBytes   BIGINT,
    @UploadedBy  VARCHAR(64)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.blob_upload (blob_path, file_name, content_type, size_bytes, uploaded_by, uploaded_at, is_deleted)
    VALUES (@BlobPath, @FileName, @ContentType, @SizeBytes, @UploadedBy, SYSUTCDATETIME(), 0);

    DECLARE @NewId INT = SCOPE_IDENTITY();

    SELECT id, blob_path, file_name, content_type, size_bytes, uploaded_by, uploaded_at
    FROM dbo.blob_upload
    WHERE id = @NewId;
END

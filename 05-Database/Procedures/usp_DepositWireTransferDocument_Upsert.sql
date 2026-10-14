CREATE   PROCEDURE [dbo].[usp_DepositWireTransferDocument_Upsert]
    @SpaceId          INT,
    @DepositId        VARCHAR(64),
    @BlobPath         VARCHAR(500),
    @OriginalFileName VARCHAR(255),
    @ContentType      VARCHAR(100),
    @FileExtension    VARCHAR(10),
    @FileSizeBytes    BIGINT,
    @ModifiedBy       VARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Now DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @PreviousBlobPath VARCHAR(500);

    -- Single-row UPDATE on the parent — no MERGE/child-table needed, the relationship is
    -- 1:1. Capturing the pre-update blob_path into a variable in the same UPDATE (standard
    -- T-SQL "grab the old value" pattern) is what lets the caller clean up an orphaned
    -- blob if the extension changed on replace.
    UPDATE [dbo].[payment_deposit]
    SET    @PreviousBlobPath             = [document_blob_path],
           [document_blob_path]          = @BlobPath,
           [document_original_file_name] = @OriginalFileName,
           [document_content_type]       = @ContentType,
           [document_file_extension]     = @FileExtension,
           [document_file_size_bytes]    = @FileSizeBytes,
           [document_uploaded_by]        = @ModifiedBy,
           [document_uploaded_at]        = @Now,
           [modified_time]               = @Now,
           [modified_by]                 = @ModifiedBy
    WHERE  [space_id] = @SpaceId AND [deposit_id] = @DepositId;

    SELECT @PreviousBlobPath AS previous_blob_path, @Now AS uploaded_at;
END

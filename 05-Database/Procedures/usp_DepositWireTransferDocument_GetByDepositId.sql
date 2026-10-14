CREATE   PROCEDURE [dbo].[usp_DepositWireTransferDocument_GetByDepositId]
    @SpaceId   INT,
    @DepositId VARCHAR(64)
AS
BEGIN
    SET NOCOUNT ON;
    -- document_blob_path IS NOT NULL preserves the "no row = not found" contract for a
    -- deposit that exists but has no document uploaded yet.
    SELECT
        [document_blob_path]          AS blob_path,
        [document_original_file_name] AS original_file_name,
        [document_content_type]       AS content_type,
        [document_file_size_bytes]    AS file_size_bytes,
        [document_uploaded_by]        AS uploaded_by,
        [document_uploaded_at]        AS uploaded_at
    FROM   [dbo].[payment_deposit]
    WHERE  [space_id] = @SpaceId AND [deposit_id] = @DepositId AND [is_deleted] = 0
      AND  [document_blob_path] IS NOT NULL;
END

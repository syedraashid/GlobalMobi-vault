-- ------------------------------------------------------------
-- 5) usp_BlobUpload_SoftDelete — marks the DB row deleted (hides it
--    from the list). The caller (BlobUploadController.Delete) deletes
--    the actual blob FIRST, via usp_BlobUpload_GetStatus above, and
--    only calls this once that succeeds — so a failed blob delete
--    never leaves a DB row marked "deleted" while the blob still exists.
--    This script itself contains no blob-deletion logic; that has to
--    happen from the application (Azure.Storage.Blobs), not SQL.
--
--    No RAISERROR for "not found" — the caller checks the affected
--    row count instead (0 = not found/already deleted, 1 = success),
--    same pattern already used by usp_Intent_UpdateProvideId's caller
--    (OrderRepository.Payments.cs.UpdatePaymentIntentProviderIdAsync).
--
--    BUG FIXED — found via a live repro, not caught by unit tests:
--    this proc originally had SET NOCOUNT ON, same as every other proc
--    in this script. That's wrong specifically here: SET NOCOUNT ON
--    suppresses the DONE_IN_PROC row-count token that
--    ExecuteNonQueryAsync() reads, so it returned -1 instead of the
--    real affected-row count — `rows > 0` was always false, so every
--    delete reported "Asset already deleted." (404) even when the
--    UPDATE had just succeeded and set is_deleted = 1. Confirmed by
--    querying the live table directly: the row really was updated, but
--    the API still returned 404. usp_Intent_UpdateProvideId already
--    documents this exact gotcha with an explicit comment — SET NOCOUNT
--    ON is deliberately omitted below for the same reason. FakeDbProvider
--    can't catch this class of bug: it just returns whatever row count a
--    test enqueues, so this only ever surfaces against a real SQL Server.
-- ------------------------------------------------------------
CREATE   PROCEDURE [dbo].[usp_BlobUpload_SoftDelete]
    @Id INT
AS
BEGIN
    UPDATE dbo.blob_upload
    SET is_deleted = 1
    WHERE id = @Id AND is_deleted = 0;
END

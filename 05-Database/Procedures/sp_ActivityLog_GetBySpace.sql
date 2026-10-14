-- ------------------------------------------------------------
-- 2. PAGED FETCH — called by ActivityLogController
--    GET /api/space/{spaceId}/activity?limit=10&cursor=0
--
--    Cursor pagination:
--      @Cursor = 0  → first page  (no id filter applied)
--      @Cursor > 0  → subsequent pages (id < @Cursor)
--
--    @Fetch = requested limit + 1.
--    The extra row lets the caller detect hasMore without
--    a separate COUNT query. The caller removes it before
--    returning the result to the client.
--
--    ORDER BY id DESC — id is IDENTITY and performed_at is
--    DEFAULT GETDATE(), so they are always in the same order.
--    Sorting by id keeps the cursor axis and sort axis on the
--    same column, guaranteeing no page skips or duplicates.
--    (ORDER BY performed_at DESC with an id-based cursor would
--    require a compound cursor to be correct.)
--
--    WITH (NOLOCK) — activity_log receives concurrent INSERTs
--    from the filter. NOLOCK prevents any shared-lock contention
--    with those writes. A slightly stale log view is acceptable.
-- ------------------------------------------------------------
CREATE   PROCEDURE [dbo].[sp_ActivityLog_GetBySpace]
    @SpaceId INT,
    @Fetch   INT,
    @Cursor  BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT TOP (@Fetch)
            id,
            space_id,
            entity_type,
            entity_id,
            entity_name,
            action,
            performed_by,
            performed_at,
            correlation_id
        FROM  activity_log WITH (NOLOCK)
        WHERE space_id = @SpaceId
          AND (@Cursor = 0 OR id < @Cursor)
        ORDER BY id DESC;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

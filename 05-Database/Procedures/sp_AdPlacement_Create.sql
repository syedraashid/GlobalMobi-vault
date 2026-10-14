-- Always returns exactly one row:
--   status, id, space_id, placement_key, label, is_3d, key_changed, affects_today_schedule, blocking_ad_count
-- (placement columns are NULL unless status = 0)
CREATE   PROCEDURE [dbo].[sp_AdPlacement_Create]
    @SpaceId      INT,
    @PlacementKey VARCHAR(50),
    @Label        VARCHAR(100),
    @Is3d         BIT,
    @ModifiedBy   VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        DECLARE @Status INT = 0, @RowId INT = NULL;

        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.space WHERE id = @SpaceId AND is_deleted = 0)
            SET @Status = 1;
        ELSE IF EXISTS (SELECT 1 FROM dbo.ad_placement WITH (UPDLOCK, HOLDLOCK)
                        WHERE space_id = @SpaceId AND placement_key = @PlacementKey AND is_deleted = 0)
            SET @Status = 2;
        ELSE
        BEGIN
            INSERT INTO dbo.ad_placement (space_id, placement_key, label, is_3d, is_deleted, modified_time, modified_by)
            VALUES (@SpaceId, @PlacementKey, @Label, @Is3d, 0, SYSUTCDATETIME(), @ModifiedBy);
            SET @RowId = CAST(SCOPE_IDENTITY() AS INT);
        END;

        -- Nothing is written unless @Status = 0, so committing in every case just releases the locks.
        -- (Unlike ROLLBACK, this keeps the procedure usable with INSERT ... EXEC and inside a
        -- caller's transaction.)
        COMMIT TRANSACTION;

        SELECT @Status AS [status], p.id, p.space_id, p.placement_key, p.label, p.is_3d,
               CAST(0 AS BIT) AS key_changed, CAST(0 AS BIT) AS affects_today_schedule, 0 AS blocking_ad_count
        FROM   (SELECT 1 AS one) d
        LEFT JOIN dbo.ad_placement p ON p.id = @RowId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

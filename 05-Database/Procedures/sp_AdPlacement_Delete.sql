-- Soft delete. Blocked (status 4) while an "active or upcoming" ad uses the placement:
--   * it has a schedule date on/after @Today, OR
--   * it has no schedule dates at all and its campaign has not ended (end_date >= @Today).
-- All ad statuses count (a pending ad may still be approved); advertiser.is_active is ignored
-- (a reactivated advertiser keeps its placement).
CREATE   PROCEDURE [dbo].[sp_AdPlacement_Delete]
    @SpaceId    INT,
    @Id         INT,
    @ModifiedBy VARCHAR(36),
    @Today      DATE
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        DECLARE @Status INT = 0, @Blocking INT = 0, @Found INT = NULL;

        BEGIN TRANSACTION;

        SELECT @Found = id
        FROM   dbo.ad_placement WITH (XLOCK, ROWLOCK, HOLDLOCK)
        WHERE  id = @Id AND space_id = @SpaceId AND is_deleted = 0;

        IF @Found IS NULL
            SET @Status = 1;
        ELSE
        BEGIN
            SELECT @Blocking = COUNT(*)
            FROM   dbo.advertiser_ad ad
            INNER JOIN dbo.advertiser_campaign c ON c.id = ad.campaign_id AND c.is_deleted = 0
            INNER JOIN dbo.advertiser a          ON a.id = c.advertiser_id AND a.space_id = @SpaceId AND a.is_deleted = 0
            WHERE  ad.placement_id = @Id AND ad.is_deleted = 0
              AND ( EXISTS (SELECT 1 FROM dbo.ad_schedule_dates s
                            WHERE s.ad_id = ad.id AND s.is_deleted = 0 AND s.run_date >= @Today)
                 OR ( NOT EXISTS (SELECT 1 FROM dbo.ad_schedule_dates s
                                  WHERE s.ad_id = ad.id AND s.is_deleted = 0)
                      AND c.end_date >= @Today ) );

            IF @Blocking > 0
                SET @Status = 4;
            ELSE
                UPDATE dbo.ad_placement
                SET    is_deleted    = 1,
                       modified_time = SYSUTCDATETIME(),
                       modified_by   = @ModifiedBy
                WHERE  id = @Id;
        END;

        -- Nothing is written unless @Status = 0, so committing in every case just releases the locks.
        -- (Unlike ROLLBACK, this keeps the procedure usable with INSERT ... EXEC and inside a
        -- caller's transaction.)
        COMMIT TRANSACTION;

        SELECT @Status AS [status], CAST(NULL AS INT) AS id, CAST(NULL AS INT) AS space_id,
               CAST(NULL AS VARCHAR(50)) AS placement_key, CAST(NULL AS VARCHAR(100)) AS label,
               CAST(NULL AS BIT) AS is_3d,
               CAST(0 AS BIT) AS key_changed, CAST(0 AS BIT) AS affects_today_schedule,
               @Blocking AS blocking_ad_count;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

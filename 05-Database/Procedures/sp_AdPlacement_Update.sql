CREATE   PROCEDURE [dbo].[sp_AdPlacement_Update]
    @SpaceId      INT,
    @Id           INT,
    @PlacementKey VARCHAR(50),
    @Label        VARCHAR(100),
    @Is3d         BIT,
    @ModifiedBy   VARCHAR(36),
    @Today        DATE
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        DECLARE @Status INT = 0, @RowId INT = NULL;
        DECLARE @KeyChanged BIT = 0, @AffectsToday BIT = 0;
        DECLARE @OldKey VARCHAR(50), @OldIs3d BIT;

        BEGIN TRANSACTION;

        SELECT @OldKey = placement_key, @OldIs3d = is_3d
        FROM   dbo.ad_placement WITH (XLOCK, ROWLOCK, HOLDLOCK)
        WHERE  id = @Id AND space_id = @SpaceId AND is_deleted = 0;

        IF @OldKey IS NULL
            SET @Status = 1;
        ELSE IF EXISTS (SELECT 1 FROM dbo.ad_placement WITH (UPDLOCK, HOLDLOCK)
                        WHERE space_id = @SpaceId AND placement_key = @PlacementKey
                          AND is_deleted = 0 AND id <> @Id)
            SET @Status = 2;
        -- A-1: is3d may only change while no ad uses the placement
        ELSE IF @OldIs3d <> @Is3d
            AND EXISTS (SELECT 1
                        FROM   dbo.advertiser_ad ad
                        INNER JOIN dbo.advertiser_campaign c ON c.id = ad.campaign_id AND c.is_deleted = 0
                        INNER JOIN dbo.advertiser a          ON a.id = c.advertiser_id AND a.space_id = @SpaceId AND a.is_deleted = 0
                        WHERE  ad.placement_id = @Id AND ad.is_deleted = 0)
            SET @Status = 3;
        ELSE
        BEGIN
            -- Binary compare: Unity matches the key case-sensitively, so 'Foo' -> 'foo' IS a change.
            SET @KeyChanged = CASE WHEN @OldKey COLLATE Latin1_General_BIN2 <> @PlacementKey COLLATE Latin1_General_BIN2
                                   THEN 1 ELSE 0 END;

            UPDATE dbo.ad_placement
            SET    placement_key = @PlacementKey,
                   label         = @Label,
                   is_3d         = @Is3d,
                   modified_time = SYSUTCDATETIME(),
                   modified_by   = @ModifiedBy
            WHERE  id = @Id;

            -- Same predicate as sp_ActiveAds_GetScheduleForDate: does today's published schedule
            -- contain an ad on this placement? Only then does a key rename need a blob republish.
            IF @KeyChanged = 1
               AND EXISTS (SELECT 1
                           FROM   dbo.advertiser_ad ad
                           INNER JOIN dbo.ad_schedule_dates s   ON s.ad_id = ad.id AND s.run_date = @Today AND s.is_deleted = 0   -- SOFT-DELETE
                           INNER JOIN dbo.advertiser_campaign c ON c.id = ad.campaign_id AND c.is_deleted = 0
                           INNER JOIN dbo.advertiser a          ON a.id = c.advertiser_id AND a.space_id = @SpaceId
                                                               AND a.is_active = 1 AND a.is_deleted = 0
                           WHERE  ad.placement_id = @Id AND ad.is_deleted = 0 AND ad.[status] = 'approved')
                SET @AffectsToday = 1;

            SET @RowId = @Id;
        END;

        -- Nothing is written unless @Status = 0, so committing in every case just releases the locks.
        -- (Unlike ROLLBACK, this keeps the procedure usable with INSERT ... EXEC and inside a
        -- caller's transaction.)
        COMMIT TRANSACTION;

        SELECT @Status AS [status], p.id, p.space_id, p.placement_key, p.label, p.is_3d,
               @KeyChanged AS key_changed, @AffectsToday AS affects_today_schedule, 0 AS blocking_ad_count
        FROM   (SELECT 1 AS one) d
        LEFT JOIN dbo.ad_placement p ON p.id = @RowId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

-- ============================================================
-- CAMPAIGN
-- ============================================================

-- Returns -1 as new_id when advertiser not found/inactive.
CREATE   PROCEDURE [dbo].[sp_Campaign_Create]
    @SpaceId          INT,
    @AdvertiserId     INT,
    @NameKey          UNIQUEIDENTIFIER,
    @DailyRate        DECIMAL(18,2),
    @DurationModifier DECIMAL(5,2)  = 1.0,
    @StartDate        DATE,
    @EndDate          DATE,
    @ModifiedBy       NVARCHAR(255) = NULL,
    @CreatedBy        NVARCHAR(255) = NULL,
    @I18nName         NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (
            SELECT 1 FROM advertiser
            WHERE id = @AdvertiserId AND space_id = @SpaceId AND is_active = 1 AND is_deleted = 0
        )
        BEGIN
            COMMIT TRANSACTION;
            SELECT -1 AS new_id; RETURN;
        END;
        DECLARE @CostPerDay DECIMAL(18,2) = @DailyRate * @DurationModifier;
        DECLARE @TotalCost  DECIMAL(18,2) = @CostPerDay * (DATEDIFF(day, @StartDate, @EndDate) + 1);
        INSERT INTO advertiser_campaign
            (advertiser_id, name_key, daily_rate, duration_modifier, cost_per_day, total_cost, start_date, end_date, modified_time, modified_by,
             created_by, created_time, [status])
        VALUES
            (@AdvertiserId, @NameKey, @DailyRate, @DurationModifier, @CostPerDay, @TotalCost, @StartDate, @EndDate, SYSUTCDATETIME(), ISNULL(@ModifiedBy, 'system'),
             ISNULL(@CreatedBy, 'system'), SYSUTCDATETIME(), 'draft');
        DECLARE @NewId INT = CAST(SCOPE_IDENTITY() AS INT);
        IF @I18nName IS NOT NULL
        BEGIN
            INSERT INTO i18n ([key], locale_id, [value], space_id)
            SELECT @NameKey, j.locale_id, j.[value], @SpaceId
            FROM OPENJSON(@I18nName) WITH (locale_id NVARCHAR(20) '$.locale_id', [value] NVARCHAR(MAX) '$.value') j;
        END;
        COMMIT TRANSACTION;
        SELECT @NewId AS new_id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

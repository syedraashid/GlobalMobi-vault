CREATE   PROCEDURE [dbo].[sp_Ad3dModel_Update]
    @SpaceId      INT,
    @Id           INT,
    @ModelKey     VARCHAR(64),
    @DisplayName  NVARCHAR(100),
    @Description  NVARCHAR(500) = NULL,
    @IsActive     BIT           = 1,
    @PreviewLinks NVARCHAR(MAX) = NULL,
    @ModifiedBy   VARCHAR(36)   = 'system',
    @Today        DATE          = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        DECLARE @Status INT = 0, @RowId INT = NULL, @Changed BIT = 0, @AffectsToday BIT = 0;
        DECLARE @OldKey VARCHAR(64), @OldName NVARCHAR(100), @PreviewId BIGINT, @HasPreview BIT = 0;
        SET @ModifiedBy = ISNULL(NULLIF(@ModifiedBy, ''), 'system');
        SET @Today = ISNULL(@Today, CAST(SYSDATETIMEOFFSET() AT TIME ZONE 'Eastern Standard Time' AS DATE));
        IF @PreviewLinks IS NOT NULL AND EXISTS (SELECT 1 FROM OPENJSON(@PreviewLinks)) SET @HasPreview = 1;

        BEGIN TRANSACTION;

        SELECT @OldKey = m.model_key, @OldName = m.display_name, @PreviewId = m.preview_media_id
        FROM   dbo.ad_3d_model m WITH (XLOCK, ROWLOCK, HOLDLOCK)
        INNER JOIN dbo.space s ON s.id = m.space_id AND s.is_deleted = 0
        WHERE  m.id = @Id AND m.space_id = @SpaceId AND m.is_deleted = 0;

        IF @OldKey IS NULL
            SET @Status = 1;

        ELSE IF @OldKey COLLATE Latin1_General_BIN2 <> @ModelKey COLLATE Latin1_General_BIN2
                AND EXISTS (SELECT 1 FROM dbo.advertiser_ad ad WHERE ad.model_id = @Id AND ad.is_deleted = 0)
            SET @Status = 3;
        ELSE IF EXISTS (SELECT 1 FROM dbo.ad_3d_model WITH (UPDLOCK, HOLDLOCK)
                        WHERE space_id = @SpaceId AND model_key = @ModelKey AND is_deleted = 0 AND id <> @Id)
            SET @Status = 2;
        ELSE
        BEGIN
            SET @Changed = CASE WHEN @OldKey  COLLATE Latin1_General_BIN2 <> @ModelKey    COLLATE Latin1_General_BIN2
                                  OR @OldName COLLATE Latin1_General_BIN2 <> @DisplayName COLLATE Latin1_General_BIN2
                                THEN 1 ELSE 0 END;

            IF @HasPreview = 1
            BEGIN
                IF @PreviewId IS NULL
                BEGIN
                    INSERT INTO dbo.media (space_id, media_type_id, created_by, modified_by) VALUES (@SpaceId, 1, @ModifiedBy, @ModifiedBy);
                    SET @PreviewId = CAST(SCOPE_IDENTITY() AS BIGINT);
                END;
                EXEC dbo.sp_AdPortal_SetMediaLinks @MediaId = @PreviewId, @Links = @PreviewLinks, @ModifiedBy = @ModifiedBy;
            END
            ELSE IF @PreviewId IS NOT NULL
            BEGIN
                EXEC dbo.sp_AdPortal_SoftDeleteMedia @MediaId = @PreviewId, @ModifiedBy = @ModifiedBy;
                SET @PreviewId = NULL;
            END;

            UPDATE dbo.ad_3d_model
            SET    model_key        = @ModelKey,
                   display_name     = @DisplayName,
                   [description]    = @Description,
                   is_active        = ISNULL(@IsActive, is_active),
                   preview_media_id = @PreviewId,
                   modified_by      = @ModifiedBy,
                   modified_time    = SYSUTCDATETIME()
            WHERE  id = @Id;

            IF @Changed = 1
               AND EXISTS (SELECT 1
                           FROM   dbo.advertiser_ad ad
                           INNER JOIN dbo.ad_schedule_dates s   ON s.ad_id = ad.id AND s.run_date = @Today AND s.is_deleted = 0
                           INNER JOIN dbo.ad_placement ap       ON ap.id = ad.placement_id AND ap.space_id = @SpaceId AND ap.is_deleted = 0
                           INNER JOIN dbo.advertiser_campaign c ON c.id = ad.campaign_id AND c.is_deleted = 0
                           INNER JOIN dbo.advertiser a          ON a.id = c.advertiser_id AND a.space_id = @SpaceId
                                                              AND a.is_active = 1 AND a.is_deleted = 0
                           WHERE  ad.model_id = @Id AND ad.is_deleted = 0 AND ad.[status] = 'approved')
                SET @AffectsToday = 1;

            SET @RowId = @Id;
        END;

        COMMIT TRANSACTION;

        SELECT @Status AS [status], m.id, m.space_id, m.model_key, m.display_name, m.[description], m.preview_media_id, m.is_active,
               @Changed AS key_or_name_changed, @AffectsToday AS affects_today_schedule
        FROM   (SELECT 1 AS one) d
        LEFT JOIN dbo.ad_3d_model m ON m.id = @RowId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END

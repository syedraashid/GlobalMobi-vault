CREATE   PROCEDURE [dbo].[sp_Ad3dModel_Create]
    @SpaceId      INT,
    @ModelKey     VARCHAR(64),
    @DisplayName  NVARCHAR(100),
    @Description  NVARCHAR(500) = NULL,
    @IsActive     BIT           = 1,
    @PreviewLinks NVARCHAR(MAX) = NULL,
    @CreatedBy    VARCHAR(36)   = 'system'
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        DECLARE @Status INT = 0, @RowId INT = NULL, @PreviewId BIGINT = NULL;
        SET @CreatedBy = ISNULL(NULLIF(@CreatedBy, ''), 'system');

        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.space WHERE id = @SpaceId AND is_deleted = 0)
            SET @Status = 1;
        ELSE IF EXISTS (SELECT 1 FROM dbo.ad_3d_model WITH (UPDLOCK, HOLDLOCK)
                        WHERE space_id = @SpaceId AND model_key = @ModelKey AND is_deleted = 0)
            SET @Status = 2;
        ELSE
        BEGIN
            IF @PreviewLinks IS NOT NULL AND EXISTS (SELECT 1 FROM OPENJSON(@PreviewLinks))
            BEGIN
                INSERT INTO dbo.media (space_id, media_type_id, created_by, modified_by) VALUES (@SpaceId, 1, @CreatedBy, @CreatedBy);
                SET @PreviewId = CAST(SCOPE_IDENTITY() AS BIGINT);
                EXEC dbo.sp_AdPortal_SetMediaLinks @MediaId = @PreviewId, @Links = @PreviewLinks, @ModifiedBy = @CreatedBy;
            END;

            INSERT INTO dbo.ad_3d_model (space_id, model_key, display_name, [description], preview_media_id, is_active, is_deleted,
                                         created_by, created_time, modified_by, modified_time)
            VALUES (@SpaceId, @ModelKey, @DisplayName, @Description, @PreviewId, ISNULL(@IsActive, 1), 0,
                    @CreatedBy, SYSUTCDATETIME(), @CreatedBy, SYSUTCDATETIME());
            SET @RowId = CAST(SCOPE_IDENTITY() AS INT);
        END;

        COMMIT TRANSACTION;

        SELECT @Status AS [status], m.id, m.space_id, m.model_key, m.display_name, m.[description], m.preview_media_id, m.is_active,
               CAST(0 AS BIT) AS key_or_name_changed, CAST(0 AS BIT) AS affects_today_schedule
        FROM   (SELECT 1 AS one) d
        LEFT JOIN dbo.ad_3d_model m ON m.id = @RowId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END

CREATE   PROCEDURE [dbo].[sp_Ad3dModel_Delete]
    @SpaceId    INT,
    @Id         INT,
    @ModifiedBy VARCHAR(36) = 'system'
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        DECLARE @Status INT = 0, @Found INT = NULL, @PreviewId BIGINT = NULL;
        SET @ModifiedBy = ISNULL(NULLIF(@ModifiedBy, ''), 'system');

        BEGIN TRANSACTION;

        SELECT @Found = m.id, @PreviewId = m.preview_media_id
        FROM   dbo.ad_3d_model m WITH (XLOCK, ROWLOCK, HOLDLOCK)
        INNER JOIN dbo.space s ON s.id = m.space_id AND s.is_deleted = 0
        WHERE  m.id = @Id AND m.space_id = @SpaceId AND m.is_deleted = 0;

        IF @Found IS NULL
            SET @Status = 1;
        ELSE IF EXISTS (SELECT 1 FROM dbo.advertiser_ad ad WHERE ad.model_id = @Id AND ad.is_deleted = 0)
            SET @Status = 3;
        ELSE
        BEGIN
            IF @PreviewId IS NOT NULL
                EXEC dbo.sp_AdPortal_SoftDeleteMedia @MediaId = @PreviewId, @ModifiedBy = @ModifiedBy;
            UPDATE dbo.ad_3d_model
            SET    is_deleted = 1, modified_by = @ModifiedBy, modified_time = SYSUTCDATETIME()
            WHERE  id = @Id;
        END;

        COMMIT TRANSACTION;

        SELECT @Status AS [status], CAST(NULL AS INT) AS id, CAST(NULL AS INT) AS space_id, CAST(NULL AS VARCHAR(64)) AS model_key,
               CAST(NULL AS NVARCHAR(100)) AS display_name, CAST(NULL AS NVARCHAR(500)) AS [description], CAST(NULL AS BIGINT) AS preview_media_id,
               CAST(NULL AS BIT) AS is_active, CAST(0 AS BIT) AS key_or_name_changed, CAST(0 AS BIT) AS affects_today_schedule;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END

-- ============================================================
-- Ads / Advertiser — Stored Procedures (Final — already clean, no versioning conflicts)
-- Source: sp_Ads.sql
-- ============================================================
-- ============================================================
-- ADVERTISER
-- ============================================================

CREATE   PROCEDURE [dbo].[sp_Advertiser_Create]
    @SpaceId    INT,
    @NameKey    UNIQUEIDENTIFIER,
    @IsActive   BIT           = 1,
    @Industry   VARCHAR(100)  = NULL,
    @ModifiedBy NVARCHAR(255) = NULL,
    @CreatedBy  NVARCHAR(255) = NULL,
    @I18nName   NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO advertiser (space_id, name_key, is_active, industry, modified_time, modified_by,
                                created_by, created_time, [status])
        VALUES (@SpaceId, @NameKey, ISNULL(@IsActive, 1), @Industry, SYSUTCDATETIME(), ISNULL(@ModifiedBy, 'system'),
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

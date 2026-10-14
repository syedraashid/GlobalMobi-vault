CREATE   PROCEDURE [dbo].[sp_Hosting_Create]
    @SpaceId    INT,
    @NameKey    UNIQUEIDENTIFIER,
    @StreamUrl  NVARCHAR(2048),
    @IsActive   BIT            = 1,
    @ModifiedBy NVARCHAR(255)  = NULL,
    @CreatedBy  NVARCHAR(255)  = NULL,
    @I18nName   NVARCHAR(MAX)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- ── 1. Insert hosting ─────────────────────────────────────────
        INSERT INTO hosting (space_id, name_key, stream_url, is_active, modified_time, modified_by,
                             created_by, created_time, [status])
        VALUES (@SpaceId, @NameKey, @StreamUrl, ISNULL(@IsActive, 1), SYSUTCDATETIME(), ISNULL(@ModifiedBy, 'system'),
                ISNULL(@CreatedBy, 'system'), SYSUTCDATETIME(), 'draft');

        DECLARE @NewId INT = CAST(SCOPE_IDENTITY() AS INT);

        -- ── 2. i18n — name ───────────────────────────────────────────
        -- Plain INSERT...SELECT: no prior rows exist for @NameKey since
        -- it was freshly minted by the caller.
        IF @I18nName IS NOT NULL
        BEGIN
            INSERT INTO i18n ([key], locale_id, [value], space_id)
            SELECT @NameKey, j.locale_id, j.[value], @SpaceId
            FROM OPENJSON(@I18nName) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j;
        END;

        COMMIT TRANSACTION;
        SELECT @NewId AS new_id;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

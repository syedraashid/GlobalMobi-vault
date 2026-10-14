CREATE   PROCEDURE [dbo].[sp_Game_Create]
    @NameKey         UNIQUEIDENTIFIER,
    @DescriptionKey  UNIQUEIDENTIFIER = NULL,
    @GameCode        VARCHAR(50),
    @SortOrder       SMALLINT      = NULL,
    @IsActive        BIT           = 1,
    @ModifiedBy      VARCHAR(36)   = NULL,
    @I18nName        NVARCHAR(MAX) = NULL,
    @I18nDescription NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @ResolvedSortOrder SMALLINT =
            ISNULL(@SortOrder, (SELECT ISNULL(MAX(sort_order), 0) + 1 FROM dbo.game));

        INSERT INTO dbo.game (name_key, description_key, game_code, sort_order, is_active, is_deleted, modified_time, modified_by)
        VALUES (@NameKey, @DescriptionKey, @GameCode, @ResolvedSortOrder, @IsActive, 0, SYSUTCDATETIME(), ISNULL(@ModifiedBy, 'system'));

        DECLARE @NewId INT = CAST(SCOPE_IDENTITY() AS INT);

        -- games are a global catalog (no space_id column on dbo.game) — i18n rows use
        -- space_id = NULL, since i18n.space_id is nullable and no real space id 0 exists.
        IF @I18nName IS NOT NULL
            INSERT INTO i18n ([key], locale_id, [value], space_id)
            SELECT @NameKey, j.locale_id, j.[value], NULL
            FROM OPENJSON(@I18nName) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j;

        IF @I18nDescription IS NOT NULL AND @DescriptionKey IS NOT NULL
            INSERT INTO i18n ([key], locale_id, [value], space_id)
            SELECT @DescriptionKey, j.locale_id, j.[value], NULL
            FROM OPENJSON(@I18nDescription) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j;

        COMMIT TRANSACTION;
        SELECT @NewId AS new_id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

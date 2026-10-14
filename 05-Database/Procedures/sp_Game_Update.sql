CREATE   PROCEDURE [dbo].[sp_Game_Update]
    @Id              INT,
    @GameCode        VARCHAR(50)   = NULL,
    @SortOrder       SMALLINT      = NULL,
    @IsActive        BIT           = NULL,
    @ModifiedBy      VARCHAR(36)   = NULL,
    @I18nName        NVARCHAR(MAX) = NULL,
    @I18nDescription NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Lock and load the existing keys — names/description keys never change on
        -- update, only their i18n Values do (same rule as sp_Event_Update).
        DECLARE @ExistingNameKey UNIQUEIDENTIFIER, @ExistingDescKey UNIQUEIDENTIFIER;

        SELECT @ExistingNameKey = name_key, @ExistingDescKey = description_key
        FROM dbo.game WITH (UPDLOCK, ROWLOCK, HOLDLOCK)
        WHERE id = @Id AND is_deleted = 0;

        IF @ExistingNameKey IS NULL
        BEGIN
            COMMIT TRANSACTION;
            SELECT 0 AS found;
            RETURN;
        END;

        -- i18n — name (3-step soft-delete pattern, mirrors sp_Event_Update)
        IF @I18nName IS NOT NULL
        BEGIN
            UPDATE i18n SET is_deleted = 1 WHERE [key] = @ExistingNameKey AND is_deleted = 0;

            UPDATE i18n
            SET is_deleted = 0, [value] = j.[value]
            FROM i18n
            INNER JOIN OPENJSON(@I18nName) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j ON i18n.locale_id = j.locale_id
            WHERE i18n.[key] = @ExistingNameKey;

            INSERT INTO i18n ([key], locale_id, [value], space_id)
            SELECT @ExistingNameKey, j.locale_id, j.[value], NULL
            FROM OPENJSON(@I18nName) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j
            LEFT JOIN i18n x ON x.[key] = @ExistingNameKey AND x.locale_id = j.locale_id
            WHERE x.locale_id IS NULL;
        END;

        -- i18n — description, same pattern, only if a description key already exists
        IF @I18nDescription IS NOT NULL AND @ExistingDescKey IS NOT NULL
        BEGIN
            UPDATE i18n SET is_deleted = 1 WHERE [key] = @ExistingDescKey AND is_deleted = 0;

            UPDATE i18n
            SET is_deleted = 0, [value] = j.[value]
            FROM i18n
            INNER JOIN OPENJSON(@I18nDescription) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j ON i18n.locale_id = j.locale_id
            WHERE i18n.[key] = @ExistingDescKey;

            INSERT INTO i18n ([key], locale_id, [value], space_id)
            SELECT @ExistingDescKey, j.locale_id, j.[value], NULL
            FROM OPENJSON(@I18nDescription) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j
            LEFT JOIN i18n x ON x.[key] = @ExistingDescKey AND x.locale_id = j.locale_id
            WHERE x.locale_id IS NULL;
        END;

        UPDATE dbo.game
        SET game_code     = COALESCE(@GameCode, game_code),
            sort_order    = COALESCE(@SortOrder, sort_order),
            is_active     = COALESCE(@IsActive, is_active),
            modified_time = SYSUTCDATETIME(),
            modified_by   = ISNULL(@ModifiedBy, 'system')
        WHERE id = @Id AND is_deleted = 0;

        COMMIT TRANSACTION;
        SELECT 1 AS found;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

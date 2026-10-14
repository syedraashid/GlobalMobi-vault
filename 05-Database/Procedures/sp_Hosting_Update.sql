CREATE   PROCEDURE [dbo].[sp_Hosting_Update]
    @SpaceId     INT,
    @HostingId   INT,
    @StreamUrl   NVARCHAR(2048) = NULL,
    @IsActive    BIT            = NULL,
    @ModifiedBy  NVARCHAR(255)  = NULL,
    @I18nName    NVARCHAR(MAX)  = NULL,
    @ForceStatus VARCHAR(20)    = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- ── 1. Lock and load ──────────────────────────────────────────
        DECLARE @NameKey UNIQUEIDENTIFIER;

        SELECT @NameKey = name_key
        FROM hosting WITH (UPDLOCK, ROWLOCK, HOLDLOCK)
        WHERE id         = @HostingId
          AND space_id   = @SpaceId
          AND is_deleted = 0;

        IF @NameKey IS NULL
        BEGIN
            COMMIT TRANSACTION;
            SELECT 0 AS found;
            RETURN;
        END;

        -- ── 2. i18n — name (3-step soft-delete pattern) ──────────────
        -- NULL  = caller omitted this field; leave i18n untouched.
        -- '[]'  = wipe all name translations (step a runs, b-1/b-2 produce 0 rows).
        IF @I18nName IS NOT NULL
        BEGIN
            -- Step a: soft-delete all active translations for this key
            UPDATE i18n
            SET    is_deleted = 1
            WHERE  [key]      = @NameKey
              AND  space_id   = @SpaceId
              AND  is_deleted = 0;

            -- Step b-1: re-activate rows whose locale is in the payload
            UPDATE i18n
            SET    is_deleted = 0,
                   [value]    = j.[value]
            FROM   i18n
            INNER JOIN OPENJSON(@I18nName) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j ON i18n.locale_id = j.locale_id
            WHERE  i18n.[key]    = @NameKey
              AND  i18n.space_id = @SpaceId;

            -- Step b-2: insert locales that have never had a physical row.
            -- LEFT JOIN anti-join avoids correlated-subquery binding issues
            -- with OPENJSON aliases inside NOT EXISTS.
            INSERT INTO i18n ([key], locale_id, [value], space_id)
            SELECT @NameKey, j.locale_id, j.[value], @SpaceId
            FROM   OPENJSON(@I18nName) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j
            LEFT JOIN i18n x
                ON  x.[key]     = @NameKey
                AND x.locale_id = j.locale_id
                AND x.space_id  = @SpaceId
            WHERE x.locale_id IS NULL;
        END;

        -- ── 3. Update hosting row ─────────────────────────────────────
        -- COALESCE: NULL parameter = leave column unchanged.
        UPDATE hosting
        SET
            stream_url    = COALESCE(@StreamUrl, stream_url),
            is_active     = COALESCE(@IsActive,  is_active),
            modified_time = SYSUTCDATETIME(),
            modified_by   = ISNULL(@ModifiedBy, modified_by),
            [status]      = ISNULL(@ForceStatus, [status])
        WHERE id         = @HostingId
          AND space_id   = @SpaceId
          AND is_deleted = 0;

        COMMIT TRANSACTION;
        SELECT 1 AS found;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

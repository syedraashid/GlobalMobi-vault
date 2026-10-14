CREATE   PROCEDURE [dbo].[sp_Advertiser_Update]
    @SpaceId      INT,
    @AdvertiserId INT,
    @IsActive     BIT           = NULL,
    @Industry     VARCHAR(100)  = NULL,
    @ModifiedBy   NVARCHAR(255) = NULL,
    @I18nName     NVARCHAR(MAX) = NULL,
    @ForceStatus  VARCHAR(20)   = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @NameKey UNIQUEIDENTIFIER;
        SELECT @NameKey = name_key
        FROM advertiser WITH (UPDLOCK, ROWLOCK, HOLDLOCK)
        WHERE id = @AdvertiserId AND space_id = @SpaceId AND is_deleted = 0;
        IF @NameKey IS NULL BEGIN COMMIT TRANSACTION; SELECT 0 AS found; RETURN; END;
        IF @I18nName IS NOT NULL
        BEGIN
            UPDATE i18n SET is_deleted = 1
            WHERE [key] = @NameKey AND space_id = @SpaceId AND is_deleted = 0;
            UPDATE i18n SET is_deleted = 0, [value] = j.[value]
            FROM i18n
            INNER JOIN OPENJSON(@I18nName) WITH (locale_id NVARCHAR(20) '$.locale_id', [value] NVARCHAR(MAX) '$.value') j
                ON i18n.locale_id = j.locale_id
            WHERE i18n.[key] = @NameKey AND i18n.space_id = @SpaceId;
            INSERT INTO i18n ([key], locale_id, [value], space_id)
            SELECT @NameKey, j.locale_id, j.[value], @SpaceId
            FROM OPENJSON(@I18nName) WITH (locale_id NVARCHAR(20) '$.locale_id', [value] NVARCHAR(MAX) '$.value') j
            LEFT JOIN i18n x ON x.[key] = @NameKey AND x.locale_id = j.locale_id AND x.space_id = @SpaceId
            WHERE x.locale_id IS NULL;
        END;
        UPDATE advertiser
        SET is_active     = COALESCE(@IsActive, is_active),
            industry      = COALESCE(@Industry, industry),
            modified_time = SYSUTCDATETIME(),
            modified_by   = ISNULL(@ModifiedBy, modified_by),
            [status]      = ISNULL(@ForceStatus, [status])
        WHERE id = @AdvertiserId AND space_id = @SpaceId AND is_deleted = 0;
        COMMIT TRANSACTION;
        SELECT 1 AS found;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

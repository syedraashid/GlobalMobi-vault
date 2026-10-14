CREATE   PROCEDURE [dbo].[sp_Charity_Delete]
    @SpaceId   INT,
    @CharityId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- ── 1. Lock and load ──────────────────────────────────────────
        -- UPDLOCK prevents a concurrent update or delete from racing
        -- with this SP between the existence check and the writes below.
        DECLARE @NameKey UNIQUEIDENTIFIER;
        DECLARE @DescKey UNIQUEIDENTIFIER;
        DECLARE @MediaId BIGINT;

        SELECT
            @NameKey = name_key,
            @DescKey = description_key,
            @MediaId = logo_media_id
        FROM charity WITH (UPDLOCK, ROWLOCK, HOLDLOCK)
        WHERE id        = @CharityId
          AND space_id  = @SpaceId
          AND is_deleted = 0;

        -- name_key is NOT NULL in a valid charity row; NULL here means
        -- the charity was not found or is already soft-deleted.
        IF @NameKey IS NULL
        BEGIN
            COMMIT TRANSACTION;
            SELECT 0 AS found;
            RETURN;
        END;

        -- ── 2. Soft-delete charity ────────────────────────────────────
        UPDATE charity
        SET    is_deleted = 1
        WHERE  id        = @CharityId
          AND  space_id  = @SpaceId
          AND  is_deleted = 0;

        IF @@ROWCOUNT = 0
        BEGIN
            COMMIT TRANSACTION;
            SELECT 0 AS found;
            RETURN;
        END;

        -- ── 3. Soft-delete media_localization and media ───────────────
        -- Only runs when the charity had a logo; skipped otherwise.
        IF @MediaId IS NOT NULL
        BEGIN
            UPDATE media_localization
            SET    is_deleted = 1
            WHERE  media_id   = @MediaId
              AND  is_deleted = 0;

            UPDATE media
            SET    is_deleted = 1
            WHERE  id         = @MediaId
              AND  space_id   = @SpaceId
              AND  is_deleted = 0;
        END;

        -- ── 4. Soft-delete i18n — name ────────────────────────────────
        UPDATE i18n
        SET    is_deleted = 1
        WHERE  [key]      = @NameKey
          AND  space_id   = @SpaceId
          AND  is_deleted = 0;

        -- ── 5. Soft-delete i18n — description ────────────────────────
        IF @DescKey IS NOT NULL
            UPDATE i18n
            SET    is_deleted = 1
            WHERE  [key]      = @DescKey
              AND  space_id   = @SpaceId
              AND  is_deleted = 0;

        COMMIT TRANSACTION;
        SELECT 1 AS found;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

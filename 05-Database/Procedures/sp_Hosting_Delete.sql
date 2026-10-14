CREATE   PROCEDURE [dbo].[sp_Hosting_Delete]
    @SpaceId   INT,
    @HostingId INT
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

        -- ── 2. Soft-delete hosting ────────────────────────────────────
        UPDATE hosting
        SET    is_deleted = 1
        WHERE  id         = @HostingId
          AND  space_id   = @SpaceId
          AND  is_deleted = 0;

        IF @@ROWCOUNT = 0
        BEGIN
            COMMIT TRANSACTION;
            SELECT 0 AS found;
            RETURN;
        END;

        -- ── 3. Soft-delete i18n — name ────────────────────────────────
        UPDATE i18n
        SET    is_deleted = 1
        WHERE  [key]      = @NameKey
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

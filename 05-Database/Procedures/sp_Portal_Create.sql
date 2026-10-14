-- ============================================================
-- sp_Portal_Create
-- Inserts one portal row and returns the new portal_id.
-- Called within the caller's transaction — no internal
-- BEGIN/COMMIT so the caller's transaction wraps the full
-- create operation (media + portal + i18n + links).
-- ============================================================
CREATE   PROCEDURE [dbo].[sp_Portal_Create]
    @SpaceId      INT,
    @BoothId      INT           = NULL,
    @PortalTypeId INT           = NULL,
    @EventId      INT           = NULL,
    @CorrId       BIGINT        = NULL,
    @TextFieldKey UNIQUEIDENTIFIER,
    @ModifiedBy   NVARCHAR(255),
    @CreatedBy    NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [dbo].[portal]
        (space_id, booth_id, portal_type_id, event_id,
         corresponding_media_id, text_field_key,
         modified_by, created_by, created_time, [status])
    VALUES
        (@SpaceId, @BoothId, @PortalTypeId, @EventId,
         @CorrId, @TextFieldKey,
         @ModifiedBy, @CreatedBy, SYSUTCDATETIME(), 'draft');

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS portal_id;
END

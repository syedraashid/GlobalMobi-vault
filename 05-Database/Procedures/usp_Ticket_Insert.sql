-- ============================================================
-- SECTION 3 — Ticket item subtype
-- ============================================================

-- Inserts the ticket subtype row (id = item.id, no identity).
CREATE   PROCEDURE [dbo].[usp_Ticket_Insert]
    @ItemId         INT,
    @EventId        INT           = NULL,
    @TicketTypeId   INT           = NULL,
    @Seat           NVARCHAR(255) = NULL,
    @Section        NVARCHAR(255) = NULL,
    @ValidFrom      DATETIME2     = NULL,
    @ValidTo        DATETIME2     = NULL,
    @IsTransferable BIT           = NULL,
    @ThumbMediaId   BIGINT        = NULL,
    @ModifiedBy     NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO ticket (id, event_id, ticket_type_id, seat, section,
                        valid_from, valid_to, is_transferable, thumbnail_media_id, modified_by)
    VALUES (@ItemId, @EventId, @TicketTypeId, @Seat, @Section,
            @ValidFrom, @ValidTo, @IsTransferable, @ThumbMediaId, @ModifiedBy);
END

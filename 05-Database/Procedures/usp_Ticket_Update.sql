CREATE   PROCEDURE [dbo].[usp_Ticket_Update]
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
    UPDATE ticket
    SET
        event_id           = COALESCE(@EventId, event_id),
        ticket_type_id     = COALESCE(@TicketTypeId, ticket_type_id),
        seat               = COALESCE(@Seat, seat),
        section            = COALESCE(@Section, section),
        valid_from         = COALESCE(@ValidFrom, valid_from),
        valid_to           = COALESCE(@ValidTo, valid_to),
        is_transferable    = COALESCE(@IsTransferable, is_transferable),
        thumbnail_media_id = @ThumbMediaId,
        modified_by        = @ModifiedBy
    WHERE id = @ItemId;
END

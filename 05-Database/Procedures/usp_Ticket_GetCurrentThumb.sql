-- Returns the ticket's current thumbnail media id (or NULL). Used by ItemRepository
-- to resolve "keep current thumbnail" during a patch update, same role as
-- usp_Merchandise_GetThumb plays for Merchandise.
CREATE   PROCEDURE [dbo].[usp_Ticket_GetCurrentThumb]
    @ItemId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT thumbnail_media_id FROM ticket WHERE id = @ItemId;
END

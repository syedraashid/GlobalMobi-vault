-- Returns 1 row if the ticket type exists and is not soft-deleted.
CREATE   PROCEDURE [dbo].[usp_TicketType_Exists]
    @TicketTypeId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) 1
    FROM ticket_type
    WHERE id = @TicketTypeId
      AND is_deleted = 0;
END

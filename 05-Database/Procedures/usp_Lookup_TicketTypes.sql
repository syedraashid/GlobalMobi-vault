CREATE   PROCEDURE [dbo].[usp_Lookup_TicketTypes]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id, type AS Type
    FROM ticket_type
    WHERE is_deleted = 0
    ORDER BY id;
END

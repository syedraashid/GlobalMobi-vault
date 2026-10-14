CREATE   PROCEDURE [dbo].[usp_Currency_SelectIsoById]
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1 ISO FROM currency WHERE id = @Id;
END

CREATE   PROCEDURE [dbo].[sp_Space_GetCurrencyId]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT currency_id FROM dbo.space WHERE id = @SpaceId;
END

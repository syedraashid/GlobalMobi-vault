CREATE   PROCEDURE [dbo].[usp_Space_GetActiveCcu]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT active_ccu AS ActiveCcu
    FROM [dbo].[space]
    WHERE id = @SpaceId AND is_deleted = 0;
END

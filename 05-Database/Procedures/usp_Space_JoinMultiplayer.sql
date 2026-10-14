CREATE   PROCEDURE [dbo].[usp_Space_JoinMultiplayer]
    @SpaceId INT,
    @MaxCcu INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Allowed BIT = 0;

    UPDATE [dbo].[space]
    SET active_ccu = active_ccu + 1
    WHERE id = @SpaceId AND is_deleted = 0 AND active_ccu < @MaxCcu;

    IF @@ROWCOUNT = 1
        SET @Allowed = 1;

    SELECT @Allowed AS Allowed, active_ccu AS ActiveCcu
    FROM [dbo].[space]
    WHERE id = @SpaceId AND is_deleted = 0;
END

CREATE   PROCEDURE [dbo].[usp_Order_ExistsInSpace]
    @OrderId UNIQUEIDENTIFIER,
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 1
    FROM orders
    WHERE id = @OrderId
      AND space_id = @SpaceId;
END

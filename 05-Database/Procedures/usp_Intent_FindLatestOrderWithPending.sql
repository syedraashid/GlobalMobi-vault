-- Returns the most recent order that has a pending intent for a given user + item.
-- Used to surface an existing checkout URL instead of creating a new order.
-- NOTE: @UserId is UNIQUEIDENTIFIER — Auth0 sub IDs (auth0|abc123) will not match.
-- TODO: change @UserId to VARCHAR(36) to support non-GUID identity providers.
CREATE   PROCEDURE [dbo].[usp_Intent_FindLatestOrderWithPending]
    @SpaceId    INT,
    @UserId     UNIQUEIDENTIFIER,
    @ItemTypeId INT,
    @ItemRefId  VARCHAR(36),
    @GatewayId  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CAST(o.id AS NVARCHAR(36)) AS id
    FROM orders o
    JOIN order_line_item ol ON ol.order_id = o.id
    JOIN payment_intent pi  ON pi.order_id = o.id AND pi.status_id IN (1, 2)
    WHERE o.space_id      = @SpaceId
      AND o.user_id       = @UserId
      AND ol.item_type_id = @ItemTypeId
      AND ol.item_ref_id  = @ItemRefId
      AND (@GatewayId IS NULL OR pi.payment_gateway_id = @GatewayId)
    ORDER BY pi.modified_time DESC
    OFFSET 0 ROWS FETCH NEXT 1 ROW ONLY;
END

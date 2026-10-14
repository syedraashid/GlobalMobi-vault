-- ── 5. usp_ContentApproval_IsTeleportSpotLocked ──────────────
-- Changed: @MapSpotId → @PositionId, reads proposed_data '$.positionId'
CREATE   PROCEDURE [dbo].[usp_ContentApproval_IsTeleportSpotLocked]
    @SpaceId         INT,
    @PositionId      INT,
    @ExcludeButtonId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT COUNT(1) AS LockedCount
    FROM [dbo].[content_approval]
    WHERE [content_type] = 'teleport_button'
      AND [status]       = 'pending'
      AND [space_id]     = @SpaceId
      AND [content_id]  <> @ExcludeButtonId
      AND TRY_CAST(JSON_VALUE([proposed_data], '$.positionId') AS INT) = @PositionId;
END

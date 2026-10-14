CREATE PROCEDURE [dbo].[sp_BumpContentVersion]
    @SpaceId     INT,
    @ContentType NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    MERGE content_version AS t
    USING (SELECT @SpaceId AS space_id, @ContentType AS content_type) AS s
    ON t.space_id = s.space_id AND t.content_type = s.content_type
    WHEN MATCHED THEN
        UPDATE SET version    = version + 1,
                   updated_at = GETUTCDATE()
    WHEN NOT MATCHED THEN
        INSERT (space_id, content_type, version, updated_at)
        VALUES (@SpaceId, @ContentType, 1, GETUTCDATE());

    SELECT version
    FROM   content_version
    WHERE  space_id     = @SpaceId
      AND  content_type = @ContentType;
END;

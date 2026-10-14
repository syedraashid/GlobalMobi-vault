CREATE   PROCEDURE [dbo].[sp_UpsertContentVersion]
    @SpaceId     INT,
    @ContentType NVARCHAR(50),
    @Version     INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OldVersion  INT  = NULL;
    DECLARE @WasUpdated  BIT  = 0;

    SELECT @OldVersion = version
    FROM   content_version WITH (UPDLOCK, HOLDLOCK)
    WHERE  space_id     = @SpaceId
      AND  content_type = @ContentType;

    IF @OldVersion IS NULL
    BEGIN
        INSERT INTO content_version (space_id, content_type, version, updated_at)
        VALUES (@SpaceId, @ContentType, @Version, GETUTCDATE());
        SET @WasUpdated = 1;
    END
    ELSE IF @Version > @OldVersion
    BEGIN
        UPDATE content_version
        SET    version    = @Version,
               updated_at = GETUTCDATE()
        WHERE  space_id     = @SpaceId
          AND  content_type = @ContentType;
        SET @WasUpdated = 1;
    END;
    -- else: same version or downgrade — no DB change

    SELECT
        @OldVersion  AS old_version,
        CASE WHEN @WasUpdated = 1 THEN @Version ELSE @OldVersion END AS current_version,
        @WasUpdated  AS was_updated;
END;

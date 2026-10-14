CREATE   PROCEDURE [dbo].[usp_admin_get_user_analytics]
    @EntityIds       VARCHAR(MAX) = NULL,
    @SpaceIds        VARCHAR(MAX) = NULL,
    @UserType        VARCHAR(16)  = NULL,
    @FromDate        DATE         = NULL,
    @ToDate          DATE         = NULL,
    @TzOffsetMinutes INT          = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @SpaceIds IS NOT NULL SET @EntityIds = NULL;

    IF @FromDate IS NULL OR @ToDate IS NULL
    BEGIN
        SET @FromDate = NULL;
        SET @ToDate   = NULL;
    END

    IF @TzOffsetMinutes IS NULL SET @TzOffsetMinutes = 0;

    DECLARE @FromUtc DATETIME2(3) =
        DATEADD(minute, -@TzOffsetMinutes, CAST(@FromDate AS DATETIME2(3)));
    DECLARE @ToUtc   DATETIME2(3) =
        DATEADD(minute, -@TzOffsetMinutes, DATEADD(day, 1, CAST(@ToDate AS DATETIME2(3))));

    DECLARE @Entities TABLE (id INT PRIMARY KEY);
    DECLARE @Spaces   TABLE (id INT PRIMARY KEY);

    IF @EntityIds IS NOT NULL
        INSERT INTO @Entities (id)
        SELECT DISTINCT TRY_CAST(value AS INT)
        FROM STRING_SPLIT(@EntityIds, ',')
        WHERE TRY_CAST(value AS INT) IS NOT NULL;

    IF @SpaceIds IS NOT NULL
        INSERT INTO @Spaces (id)
        SELECT DISTINCT TRY_CAST(value AS INT)
        FROM STRING_SPLIT(@SpaceIds, ',')
        WHERE TRY_CAST(value AS INT) IS NOT NULL;

    CREATE TABLE #scoped (
        id         UNIQUEIDENTIFIER PRIMARY KEY,
        is_deleted BIT         NOT NULL,
        login_type VARCHAR(64) NOT NULL,
        has_cms    BIT         NOT NULL,
        has_imm    BIT         NOT NULL
    );

    INSERT INTO #scoped (id, is_deleted, login_type, has_cms, has_imm)
    SELECT
        u.id,
        u.is_deleted,
        ISNULL(lt.[type], 'unknown'),
        CASE WHEN u.cms_oid IS NOT NULL THEN 1 ELSE 0 END,
        CASE WHEN u.oid     IS NOT NULL THEN 1 ELSE 0 END
    FROM dbo.[user] u
    LEFT JOIN dbo.login_type lt ON lt.id = u.login_type_id
    WHERE (@FromDate IS NULL
           OR (u.created_time >= @FromUtc AND u.created_time < @ToUtc))
      AND (@UserType IS NULL OR @UserType = 'all'
           OR ISNULL(lt.[type], 'unknown') = @UserType);

    SELECT
        ISNULL(SUM(CASE WHEN is_deleted = 0 THEN 1 ELSE 0 END), 0) AS ActiveUsers,
        ISNULL(SUM(CASE WHEN is_deleted = 1 THEN 1 ELSE 0 END), 0) AS DeletedUsers,
        ISNULL(SUM(CASE WHEN is_deleted = 0 AND login_type = 'microsoft' THEN 1 ELSE 0 END), 0) AS Microsoft,
        ISNULL(SUM(CASE WHEN is_deleted = 0 AND login_type = 'guest'     THEN 1 ELSE 0 END), 0) AS Guest,
        ISNULL(SUM(CASE WHEN is_deleted = 0 AND login_type = 'unknown'   THEN 1 ELSE 0 END), 0) AS UnknownLoginType,
        ISNULL(SUM(CASE WHEN is_deleted = 0 AND login_type = 'microsoft' AND has_cms = 1 AND has_imm = 0 THEN 1 ELSE 0 END), 0) AS CmsOnly,
        ISNULL(SUM(CASE WHEN is_deleted = 0 AND login_type = 'microsoft' AND has_cms = 0 AND has_imm = 1 THEN 1 ELSE 0 END), 0) AS ImmersiveOnly,
        ISNULL(SUM(CASE WHEN is_deleted = 0 AND login_type = 'microsoft' AND has_cms = 1 AND has_imm = 1 THEN 1 ELSE 0 END), 0) AS BothProducts,
        ISNULL(SUM(CASE WHEN is_deleted = 0 AND login_type = 'microsoft' AND has_cms = 0 AND has_imm = 0 THEN 1 ELSE 0 END), 0) AS NoProductIdentity
    FROM #scoped;

    SELECT e.id AS EntityId, e.name_key AS EntityName, COUNT(DISTINCT sc.id) AS Users
    FROM #scoped sc
    JOIN dbo.space_member sm ON sm.user_id  = sc.id AND sm.is_deleted = 0
    JOIN dbo.space        sp ON sp.id       = sm.space_id AND sp.is_deleted = 0
    JOIN dbo.entity       e  ON e.id        = sp.entity_id AND e.is_deleted = 0
    WHERE sc.is_deleted = 0
      AND (@EntityIds IS NULL OR sp.entity_id IN (SELECT id FROM @Entities))
      AND (@SpaceIds  IS NULL OR sm.space_id  IN (SELECT id FROM @Spaces))
    GROUP BY e.id, e.name_key
    ORDER BY Users DESC, EntityName;

    SELECT sp.id AS SpaceId, sp.display_name AS SpaceName, sp.entity_id AS EntityId,
           COUNT(DISTINCT sc.id) AS Users
    FROM #scoped sc
    JOIN dbo.space_member sm ON sm.user_id = sc.id AND sm.is_deleted = 0
    JOIN dbo.space        sp ON sp.id      = sm.space_id AND sp.is_deleted = 0
    WHERE sc.is_deleted = 0
      AND (@EntityIds IS NULL OR sp.entity_id IN (SELECT id FROM @Entities))
      AND (@SpaceIds  IS NULL OR sm.space_id  IN (SELECT id FROM @Spaces))
    GROUP BY sp.id, sp.display_name, sp.entity_id
    ORDER BY Users DESC, SpaceName;

    DROP TABLE #scoped;
END

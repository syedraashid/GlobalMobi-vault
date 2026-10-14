/* ---------------------------------------------------------------------------
   3. dbo.usp_admin_get_user_analytics_cms — CMS tab
   --------------------------------------------------------------------------- */
CREATE   PROCEDURE [dbo].[usp_admin_get_user_analytics_cms]
    @EntityIds       VARCHAR(MAX) = NULL,
    @SpaceIds        VARCHAR(MAX) = NULL,
    @FromDate        DATE         = NULL,
    @ToDate          DATE         = NULL,
    @EmailDomain     VARCHAR(255) = NULL,
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
    IF LTRIM(RTRIM(ISNULL(@EmailDomain, ''))) = '' SET @EmailDomain = NULL;

    DECLARE @FromUtc DATETIME2(3) =
        DATEADD(minute, -@TzOffsetMinutes, CAST(@FromDate AS DATETIME2(3)));
    DECLARE @ToUtc   DATETIME2(3) =
        DATEADD(minute, -@TzOffsetMinutes, DATEADD(day, 1, CAST(@ToDate AS DATETIME2(3))));

    DECLARE @Entities TABLE (id INT PRIMARY KEY);
    DECLARE @Spaces   TABLE (id INT PRIMARY KEY);

    IF @EntityIds IS NOT NULL
        INSERT INTO @Entities (id)
        SELECT DISTINCT TRY_CAST(value AS INT) FROM STRING_SPLIT(@EntityIds, ',')
        WHERE TRY_CAST(value AS INT) IS NOT NULL;

    IF @SpaceIds IS NOT NULL
        INSERT INTO @Spaces (id)
        SELECT DISTINCT TRY_CAST(value AS INT) FROM STRING_SPLIT(@SpaceIds, ',')
        WHERE TRY_CAST(value AS INT) IS NOT NULL;

    -- #cms is ACTIVE-ONLY (u.is_deleted = 0 below) — TotalUsers (COUNT(*)) means "active CMS
    -- members", matching every breakdown of it, and matching its own drill-down popup's count.
    -- Population is CUMULATIVE as of @ToDate (no lower bound).
    CREATE TABLE #cms (id UNIQUEIDENTIFIER PRIMARY KEY, has_imm BIT NOT NULL);

    INSERT INTO #cms (id, has_imm)
    SELECT u.id, CASE WHEN u.oid IS NOT NULL THEN 1 ELSE 0 END
    FROM dbo.[user] u
    WHERE u.cms_oid IS NOT NULL
      AND u.is_deleted = 0
      AND (@ToDate IS NULL OR u.created_time < @ToUtc)
      AND (@EntityIds IS NULL OR EXISTS (
              SELECT 1 FROM dbo.space_member sm
              JOIN dbo.space sp ON sp.id = sm.space_id AND sp.is_deleted = 0
              WHERE sm.user_id = u.id AND sm.is_deleted = 0
                AND sp.entity_id IN (SELECT id FROM @Entities)))
      AND (@SpaceIds IS NULL OR EXISTS (
              SELECT 1 FROM dbo.space_member sm
              WHERE sm.user_id = u.id AND sm.is_deleted = 0
                AND sm.space_id IN (SELECT id FROM @Spaces)));

    -- Result set 1: available email domains, computed before @EmailDomain is applied.
    SELECT DISTINCT LOWER(SUBSTRING(u.email, CHARINDEX('@', u.email) + 1, 255)) AS Domain
    FROM #cms c
    JOIN dbo.[user] u ON u.id = c.id
    WHERE u.email IS NOT NULL AND CHARINDEX('@', u.email) > 0
    ORDER BY Domain;

    IF @EmailDomain IS NOT NULL
        DELETE c FROM #cms c
        JOIN dbo.[user] u ON u.id = c.id
        WHERE u.email IS NULL OR u.email NOT LIKE '%' + @EmailDomain + '%';

    -- Result set 2: headline. TotalUsers/CmsOnly/CmsAndImmersive/NewUsers are all active-only —
    -- #cms's population already excludes deleted accounts, so no per-field is_deleted check
    -- is needed here.
    SELECT
        ISNULL(COUNT(*), 0) AS TotalUsers,
        ISNULL(SUM(CASE WHEN c.has_imm = 0 THEN 1 ELSE 0 END), 0) AS CmsOnly,
        ISNULL(SUM(CASE WHEN c.has_imm = 1 THEN 1 ELSE 0 END), 0) AS CmsAndImmersive,
        ISNULL(SUM(CASE WHEN @FromDate IS NOT NULL
                           AND u.created_time >= @FromUtc AND u.created_time < @ToUtc
                      THEN 1 ELSE 0 END), 0) AS NewUsers
    FROM #cms c
    JOIN dbo.[user] u ON u.id = c.id;

    -- Result set 3: by entity. #cms is already active-only, so no extra filter needed here.
    SELECT e.id AS EntityId, e.name_key AS EntityName, ISNULL(COUNT(DISTINCT c.id), 0) AS Users
    FROM dbo.entity e
    LEFT JOIN dbo.space        sp ON sp.entity_id = e.id AND sp.is_deleted = 0
    LEFT JOIN dbo.space_member sm ON sm.space_id  = sp.id AND sm.is_deleted = 0
                                   AND (@SpaceIds IS NULL OR sm.space_id IN (SELECT id FROM @Spaces))
    LEFT JOIN #cms c ON c.id = sm.user_id
    WHERE e.is_deleted = 0
      AND (@EntityIds IS NULL OR e.id IN (SELECT id FROM @Entities))
      AND (@SpaceIds  IS NULL OR EXISTS (
              SELECT 1 FROM dbo.space s2
              WHERE s2.entity_id = e.id AND s2.id IN (SELECT id FROM @Spaces)))
    GROUP BY e.id, e.name_key
    ORDER BY Users DESC, EntityName;

    -- Result set 4: by space. Same — #cms is already active-only.
    SELECT sp.id AS SpaceId, sp.display_name AS SpaceName, sp.entity_id AS EntityId,
           ISNULL(COUNT(DISTINCT c.id), 0) AS Users
    FROM dbo.space sp
    LEFT JOIN dbo.space_member sm ON sm.space_id = sp.id AND sm.is_deleted = 0
    LEFT JOIN #cms c ON c.id = sm.user_id
    WHERE sp.is_deleted = 0
      AND (@EntityIds IS NULL OR sp.entity_id IN (SELECT id FROM @Entities))
      AND (@SpaceIds  IS NULL OR sp.id IN (SELECT id FROM @Spaces))
    GROUP BY sp.id, sp.display_name, sp.entity_id
    ORDER BY Users DESC, SpaceName;

    -- Result set 5: New CMS Users per calendar day. Scoped to the already active-only #cms
    -- population.
    SELECT CAST(u.created_time AS DATE) AS Day, COUNT(*) AS NewUsers
    FROM #cms c
    JOIN dbo.[user] u ON u.id = c.id
    WHERE (@FromDate IS NULL OR (u.created_time >= @FromUtc AND u.created_time < @ToUtc))
    GROUP BY CAST(u.created_time AS DATE)
    ORDER BY Day;

    DROP TABLE #cms;
END

/* ---------------------------------------------------------------------------
   4. dbo.usp_admin_get_user_analytics_immersive — Immersive tab
   --------------------------------------------------------------------------- */
CREATE   PROCEDURE [dbo].[usp_admin_get_user_analytics_immersive]
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

    -- #imm is ACTIVE-ONLY (u.is_deleted = 0 below) — TotalUsers (COUNT(*)) means "active
    -- Immersive users (registered or guest)", matching every breakdown of it. Population is
    -- CUMULATIVE as of @ToDate (no lower bound).
    CREATE TABLE #imm (id UNIQUEIDENTIFIER PRIMARY KEY, is_guest BIT NOT NULL,
                        has_cms BIT NOT NULL, is_immersive BIT NOT NULL);

    INSERT INTO #imm (id, is_guest, has_cms, is_immersive)
    SELECT u.id,
           CASE WHEN ISNULL(lt.[type], 'unknown') = 'guest' THEN 1 ELSE 0 END,
           CASE WHEN u.cms_oid IS NOT NULL THEN 1 ELSE 0 END,
           CASE WHEN u.oid     IS NOT NULL THEN 1 ELSE 0 END
    FROM dbo.[user] u
    LEFT JOIN dbo.login_type lt ON lt.id = u.login_type_id
    WHERE (u.oid IS NOT NULL OR ISNULL(lt.[type], 'unknown') = 'guest')
      AND u.is_deleted = 0
      AND (@ToDate IS NULL OR u.created_time < @ToUtc)
      AND (@EntityIds IS NULL OR EXISTS (
              SELECT 1 FROM dbo.user_session_management usm
              JOIN dbo.space sp ON sp.id = usm.space_id AND sp.is_deleted = 0
              WHERE usm.user_id = u.id AND usm.is_deleted = 0 AND usm.space_id IS NOT NULL
                AND sp.entity_id IN (SELECT id FROM @Entities)))
      AND (@SpaceIds IS NULL OR EXISTS (
              SELECT 1 FROM dbo.user_session_management usm
              WHERE usm.user_id = u.id AND usm.is_deleted = 0
                AND usm.space_id IN (SELECT id FROM @Spaces)));

    -- Result set 1: available email domains.
    SELECT DISTINCT LOWER(SUBSTRING(u.email, CHARINDEX('@', u.email) + 1, 255)) AS Domain
    FROM #imm i
    JOIN dbo.[user] u ON u.id = i.id
    WHERE u.email IS NOT NULL AND CHARINDEX('@', u.email) > 0
    ORDER BY Domain;

    IF @EmailDomain IS NOT NULL
        DELETE i FROM #imm i
        JOIN dbo.[user] u ON u.id = i.id
        WHERE u.email IS NULL OR u.email NOT LIKE '%' + @EmailDomain + '%';

    -- #firstSession: each active user's first-ever session, all-time — independently
    -- active-only via its own join to dbo.[user] (u9.is_deleted = 0), unrelated to #imm's
    -- population.
    CREATE TABLE #firstSession (user_id UNIQUEIDENTIFIER PRIMARY KEY, first_start DATETIME2(3) NOT NULL);
    INSERT INTO #firstSession (user_id, first_start)
    SELECT usm.user_id, MIN(usm.start_time)
    FROM dbo.user_session_management usm
    JOIN dbo.[user] u9 ON u9.id = usm.user_id AND u9.is_deleted = 0
    WHERE usm.is_deleted = 0
    GROUP BY usm.user_id;

    -- Result set 2: headline. TotalUsers/ImmersiveOnly/ImmersiveAndCms/GuestUsers are all
    -- active-only — #imm's population already excludes deleted accounts, so no per-field
    -- is_deleted check is needed here. ReturningUsers/NewUsersActivity are 0 under All Time
    -- (@FromDate NULL) — "new"/"returning" aren't meaningful without a specific window.
    SELECT
        ISNULL(COUNT(*), 0) AS TotalUsers,
        ISNULL(SUM(CASE WHEN is_immersive = 1 AND has_cms = 0 THEN 1 ELSE 0 END), 0) AS ImmersiveOnly,
        ISNULL(SUM(CASE WHEN is_immersive = 1 AND has_cms = 1 THEN 1 ELSE 0 END), 0) AS ImmersiveAndCms,
        ISNULL(SUM(CASE WHEN is_guest = 1 THEN 1 ELSE 0 END), 0) AS GuestUsers,
        ISNULL((SELECT COUNT(DISTINCT fs.user_id)
                FROM #firstSession fs
                JOIN dbo.[user] uN ON uN.id = fs.user_id AND uN.is_deleted = 0
                WHERE @FromDate IS NOT NULL
                  AND fs.first_start >= @FromUtc AND fs.first_start < @ToUtc
                  AND (@EmailDomain IS NULL OR uN.email LIKE '%' + @EmailDomain + '%')
                  AND (@EntityIds IS NULL OR EXISTS (
                          SELECT 1 FROM dbo.user_session_management usmE
                          JOIN dbo.space spE ON spE.id = usmE.space_id AND spE.is_deleted = 0
                          WHERE usmE.user_id = fs.user_id AND usmE.is_deleted = 0
                            AND spE.entity_id IN (SELECT id FROM @Entities)))
                  AND (@SpaceIds IS NULL OR EXISTS (
                          SELECT 1 FROM dbo.user_session_management usmS
                          WHERE usmS.user_id = fs.user_id AND usmS.is_deleted = 0
                            AND usmS.space_id IN (SELECT id FROM @Spaces)))
               ), 0) AS NewUsersActivity,
        ISNULL((SELECT COUNT(DISTINCT usmR.user_id)
                FROM dbo.user_session_management usmR
                JOIN #firstSession fsR ON fsR.user_id = usmR.user_id
                JOIN dbo.[user] uR ON uR.id = usmR.user_id AND uR.is_deleted = 0
                WHERE @FromDate IS NOT NULL AND usmR.is_deleted = 0
                  AND usmR.start_time >= @FromUtc AND usmR.start_time < @ToUtc
                  AND fsR.first_start < @FromUtc
                  AND (@EmailDomain IS NULL OR uR.email LIKE '%' + @EmailDomain + '%')
                  AND (@EntityIds IS NULL OR EXISTS (
                          SELECT 1 FROM dbo.user_session_management usmE2
                          JOIN dbo.space spE2 ON spE2.id = usmE2.space_id AND spE2.is_deleted = 0
                          WHERE usmE2.user_id = usmR.user_id AND usmE2.is_deleted = 0
                            AND spE2.entity_id IN (SELECT id FROM @Entities)))
                  AND (@SpaceIds IS NULL OR EXISTS (
                          SELECT 1 FROM dbo.user_session_management usmS2
                          WHERE usmS2.user_id = usmR.user_id AND usmS2.is_deleted = 0
                            AND usmS2.space_id IN (SELECT id FROM @Spaces)))
               ), 0) AS ReturningUsers
    FROM #imm;

    -- Result set 3: DAU / WAU / MAU. "As of now" — independent of @FromDate/@ToDate, still
    -- entity/space/email-scoped.
    DECLARE @TodayStart    DATETIME2(3) = CAST(CAST(GETUTCDATE() AS DATE) AS DATETIME2(3));
    DECLARE @TomorrowStart DATETIME2(3) = DATEADD(day, 1, @TodayStart);
    DECLARE @Wau7Start     DATETIME2(3) = DATEADD(day, -6, @TodayStart);
    DECLARE @Mau30Start    DATETIME2(3) = DATEADD(day, -29, @TodayStart);
    DECLARE @Trend14Start  DATETIME2(3) = DATEADD(day, -13, @TodayStart);

    SELECT
        ISNULL((SELECT COUNT(DISTINCT usm.user_id)
                FROM dbo.user_session_management usm
                JOIN dbo.[user] u4 ON u4.id = usm.user_id AND u4.is_deleted = 0
                WHERE usm.is_deleted = 0
                  AND usm.start_time >= @TodayStart AND usm.start_time < @TomorrowStart
                  AND (@EmailDomain IS NULL OR u4.email LIKE '%' + @EmailDomain + '%')
                  AND (@EntityIds IS NULL OR EXISTS (
                          SELECT 1 FROM dbo.space sp WHERE sp.id = usm.space_id
                            AND sp.is_deleted = 0 AND sp.entity_id IN (SELECT id FROM @Entities)))
                  AND (@SpaceIds IS NULL OR usm.space_id IN (SELECT id FROM @Spaces))
               ), 0) AS Dau,
        ISNULL((SELECT COUNT(DISTINCT usm.user_id)
                FROM dbo.user_session_management usm
                JOIN dbo.[user] u6 ON u6.id = usm.user_id AND u6.is_deleted = 0
                WHERE usm.is_deleted = 0
                  AND usm.start_time >= @Wau7Start AND usm.start_time < @TomorrowStart
                  AND (@EmailDomain IS NULL OR u6.email LIKE '%' + @EmailDomain + '%')
                  AND (@EntityIds IS NULL OR EXISTS (
                          SELECT 1 FROM dbo.space sp WHERE sp.id = usm.space_id
                            AND sp.is_deleted = 0 AND sp.entity_id IN (SELECT id FROM @Entities)))
                  AND (@SpaceIds IS NULL OR usm.space_id IN (SELECT id FROM @Spaces))
               ), 0) AS Wau,
        ISNULL((SELECT COUNT(DISTINCT usm.user_id)
                FROM dbo.user_session_management usm
                JOIN dbo.[user] u5 ON u5.id = usm.user_id AND u5.is_deleted = 0
                WHERE usm.is_deleted = 0
                  AND usm.start_time >= @Mau30Start AND usm.start_time < @TomorrowStart
                  AND (@EmailDomain IS NULL OR u5.email LIKE '%' + @EmailDomain + '%')
                  AND (@EntityIds IS NULL OR EXISTS (
                          SELECT 1 FROM dbo.space sp WHERE sp.id = usm.space_id
                            AND sp.is_deleted = 0 AND sp.entity_id IN (SELECT id FROM @Entities)))
                  AND (@SpaceIds IS NULL OR usm.space_id IN (SELECT id FROM @Spaces))
               ), 0) AS Mau;

    -- Result set 4: by entity. #imm is already active-only, so no extra filter needed here.
    SELECT e.id AS EntityId, e.name_key AS EntityName, ISNULL(COUNT(DISTINCT i.id), 0) AS Users
    FROM dbo.entity e
    LEFT JOIN dbo.space sp ON sp.entity_id = e.id AND sp.is_deleted = 0
    LEFT JOIN dbo.user_session_management usm ON usm.space_id = sp.id AND usm.is_deleted = 0
                                                AND (@SpaceIds IS NULL OR usm.space_id IN (SELECT id FROM @Spaces))
    LEFT JOIN #imm i ON i.id = usm.user_id
    WHERE e.is_deleted = 0
      AND (@EntityIds IS NULL OR e.id IN (SELECT id FROM @Entities))
      AND (@SpaceIds  IS NULL OR EXISTS (
              SELECT 1 FROM dbo.space s2
              WHERE s2.entity_id = e.id AND s2.id IN (SELECT id FROM @Spaces)))
    GROUP BY e.id, e.name_key
    ORDER BY Users DESC, EntityName;

    -- Result set 5: by space. Same — #imm is already active-only.
    SELECT sp.id AS SpaceId, sp.display_name AS SpaceName, sp.entity_id AS EntityId,
           ISNULL(COUNT(DISTINCT i.id), 0) AS Users
    FROM dbo.space sp
    LEFT JOIN dbo.user_session_management usm ON usm.space_id = sp.id AND usm.is_deleted = 0
    LEFT JOIN #imm i ON i.id = usm.user_id
    WHERE sp.is_deleted = 0
      AND (@EntityIds IS NULL OR sp.entity_id IN (SELECT id FROM @Entities))
      AND (@SpaceIds  IS NULL OR sp.id IN (SELECT id FROM @Spaces))
    GROUP BY sp.id, sp.display_name, sp.entity_id
    ORDER BY Users DESC, SpaceName;

    -- Result set 6: Dau per calendar day over the trailing 14 days. "As of now", already
    -- independently active-only via its own join to dbo.[user].
    SELECT CAST(usm.start_time AS DATE) AS Day, COUNT(DISTINCT usm.user_id) AS Dau
    FROM dbo.user_session_management usm
    JOIN dbo.[user] u8 ON u8.id = usm.user_id AND u8.is_deleted = 0
    WHERE usm.is_deleted = 0
      AND usm.start_time >= @Trend14Start AND usm.start_time < @TomorrowStart
      AND (@EmailDomain IS NULL OR u8.email LIKE '%' + @EmailDomain + '%')
      AND (@EntityIds IS NULL OR EXISTS (
              SELECT 1 FROM dbo.space sp WHERE sp.id = usm.space_id
                AND sp.is_deleted = 0 AND sp.entity_id IN (SELECT id FROM @Entities)))
      AND (@SpaceIds IS NULL OR usm.space_id IN (SELECT id FROM @Spaces))
    GROUP BY CAST(usm.start_time AS DATE)
    ORDER BY Day;

    DROP TABLE #imm;
    DROP TABLE #firstSession;
END

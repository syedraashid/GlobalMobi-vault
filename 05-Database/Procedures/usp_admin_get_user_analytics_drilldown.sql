/* ---------------------------------------------------------------------------
   5. dbo.usp_admin_get_user_analytics_drilldown — shared KPI-card popup
   One procedure for all 22 buckets — @Bucket selects the population predicate;
   paging and enrichment (email, joined date, last login, spaces) are identical
   regardless of which card was clicked.
   --------------------------------------------------------------------------- */
CREATE   PROCEDURE [dbo].[usp_admin_get_user_analytics_drilldown]
    @Bucket          VARCHAR(32),
    @EntityIds       VARCHAR(MAX) = NULL,
    @SpaceIds        VARCHAR(MAX) = NULL,
    @FromDate        DATE         = NULL,
    @ToDate          DATE         = NULL,
    @EmailDomain     VARCHAR(255) = NULL,
    @Page            INT          = 1,
    @PageSize        INT          = 20,
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
    IF @Page     IS NULL OR @Page     < 1   SET @Page     = 1;
    IF @PageSize IS NULL OR @PageSize < 1   SET @PageSize = 20;
    IF @PageSize > 100 SET @PageSize = 100;
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

    DECLARE @TodayStart    DATETIME2(3) = CAST(CAST(GETUTCDATE() AS DATE) AS DATETIME2(3));
    DECLARE @TomorrowStart DATETIME2(3) = DATEADD(day, 1, @TodayStart);
    DECLARE @Wau7Start     DATETIME2(3) = DATEADD(day, -6, @TodayStart);
    DECLARE @Mau30Start    DATETIME2(3) = DATEADD(day, -29, @TodayStart);

    /* Population predicate per bucket — the identical checks the three main procedures
       already use for each KPI card, applied directly against dbo.[user] here.
       @Bucket is compared with plain string equality throughout — never concatenated into
       dynamic SQL — so there is no injection surface from it. */
    CREATE TABLE #matched (id UNIQUEIDENTIFIER PRIMARY KEY);

    INSERT INTO #matched (id)
    SELECT u.id
    FROM dbo.[user] u
    LEFT JOIN dbo.login_type lt ON lt.id = u.login_type_id
    WHERE (
            @Bucket IN ('immersive.dau', 'immersive.mau', 'immersive.wau', 'immersive.new', 'immersive.returning')
        OR  (@Bucket IN ('overview.new', 'cms.new')
               AND @FromDate IS NOT NULL AND u.created_time >= @FromUtc AND u.created_time < @ToUtc)
        OR  (@Bucket NOT IN ('immersive.dau', 'immersive.mau', 'immersive.wau', 'immersive.new',
                              'immersive.returning', 'overview.new', 'cms.new')
               AND (@ToDate IS NULL OR u.created_time < @ToUtc))
          )
      AND (
            (@Bucket = 'overview.total')
        OR  (@Bucket = 'overview.active'     AND u.is_deleted = 0)
        OR  (@Bucket = 'overview.deleted'    AND u.is_deleted = 1)
        OR  (@Bucket = 'overview.new'        AND u.is_deleted = 0)
        OR  (@Bucket = 'overview.cms'        AND u.is_deleted = 0 AND u.cms_oid IS NOT NULL)
        OR  (@Bucket = 'overview.immersive'  AND u.is_deleted = 0 AND u.oid     IS NOT NULL)
        OR  (@Bucket = 'overview.both'       AND u.is_deleted = 0 AND u.cms_oid IS NOT NULL AND u.oid IS NOT NULL)
        OR  (@Bucket = 'overview.guest'      AND u.is_deleted = 0 AND ISNULL(lt.[type], 'unknown') = 'guest')

        OR  (@Bucket = 'cms.total'           AND u.cms_oid IS NOT NULL AND u.is_deleted = 0)
        OR  (@Bucket = 'cms.new'             AND u.cms_oid IS NOT NULL AND u.is_deleted = 0)
        OR  (@Bucket = 'cms.cmsOnly'         AND u.cms_oid IS NOT NULL AND u.oid IS NULL AND u.is_deleted = 0)
        OR  (@Bucket = 'cms.cmsAndImmersive' AND u.cms_oid IS NOT NULL AND u.oid IS NOT NULL AND u.is_deleted = 0)

        OR  (@Bucket = 'immersive.total'
                AND (u.oid IS NOT NULL OR ISNULL(lt.[type], 'unknown') = 'guest') AND u.is_deleted = 0)
        -- Everyone with a real Immersive identity, active — the sum of immersiveOnly and
        -- immersiveAndCms below, backing the "Registered Users" card (which replaced those
        -- two separate cards on the Immersive tab).
        OR  (@Bucket = 'immersive.registered' AND u.oid IS NOT NULL AND u.is_deleted = 0)
        OR  (@Bucket = 'immersive.immersiveOnly'
                AND u.oid IS NOT NULL AND u.cms_oid IS NULL AND u.is_deleted = 0)
        OR  (@Bucket = 'immersive.immersiveAndCms'
                AND u.oid IS NOT NULL AND u.cms_oid IS NOT NULL AND u.is_deleted = 0)
        OR  (@Bucket = 'immersive.guest'
                AND ISNULL(lt.[type], 'unknown') = 'guest' AND u.is_deleted = 0)

        -- Every activity bucket below re-adds u.is_deleted = 0 explicitly — a since-deleted
        -- account's own session EXISTS-checks true regardless of usmD/usmM's `is_deleted = 0`
        -- (that only excludes soft-deleted SESSION rows, not sessions belonging to a
        -- soft-deleted USER), so this must be re-checked here to agree with the headline
        -- Dau/Mau/Wau cards (which join dbo.[user] with is_deleted = 0).
        OR  (@Bucket = 'immersive.dau' AND u.is_deleted = 0 AND EXISTS (
                SELECT 1 FROM dbo.user_session_management usmD
                WHERE usmD.user_id = u.id AND usmD.is_deleted = 0
                  AND usmD.start_time >= @TodayStart AND usmD.start_time < @TomorrowStart))
        OR  (@Bucket = 'immersive.mau' AND u.is_deleted = 0 AND EXISTS (
                SELECT 1 FROM dbo.user_session_management usmM
                WHERE usmM.user_id = u.id AND usmM.is_deleted = 0
                  AND usmM.start_time >= @Mau30Start AND usmM.start_time < @TomorrowStart))
        OR  (@Bucket = 'immersive.wau' AND u.is_deleted = 0 AND EXISTS (
                SELECT 1 FROM dbo.user_session_management usmW
                WHERE usmW.user_id = u.id AND usmW.is_deleted = 0
                  AND usmW.start_time >= @Wau7Start AND usmW.start_time < @TomorrowStart))

        -- Session-based: first-ever session falls in [@FromUtc,@ToUtc) — "has a session in
        -- the window" AND "has none before it" together mean the window session is the first.
        -- @FromDate NULL (All Time) makes both EXISTS checks compare against NULL bounds,
        -- which SQL Server never satisfies (ANSI_NULLS ON) — naturally empty, no extra guard.
        OR  (@Bucket = 'immersive.new' AND u.is_deleted = 0 AND EXISTS (
                SELECT 1 FROM dbo.user_session_management usmN
                WHERE usmN.user_id = u.id AND usmN.is_deleted = 0
                  AND usmN.start_time >= @FromUtc AND usmN.start_time < @ToUtc
                  AND NOT EXISTS (
                      SELECT 1 FROM dbo.user_session_management usmNPrior
                      WHERE usmNPrior.user_id = u.id AND usmNPrior.is_deleted = 0
                        AND usmNPrior.start_time < @FromUtc)))

        -- Session-based: has a session in the window AND had one before it too.
        OR  (@Bucket = 'immersive.returning' AND u.is_deleted = 0
                AND EXISTS (
                    SELECT 1 FROM dbo.user_session_management usmR
                    WHERE usmR.user_id = u.id AND usmR.is_deleted = 0
                      AND usmR.start_time >= @FromUtc AND usmR.start_time < @ToUtc)
                AND EXISTS (
                    SELECT 1 FROM dbo.user_session_management usmRPrior
                    WHERE usmRPrior.user_id = u.id AND usmRPrior.is_deleted = 0
                      AND usmRPrior.start_time < @FromUtc))
      )
      /* Entity/space scoping applies only to cms.% and immersive.% buckets — the service layer
         rejects entityIds/spaceIds on overview.* buckets before this proc is ever called, but
         the predicate is written defensively here too (LIKE against a fixed, non-user-supplied
         prefix — @Bucket itself is still never concatenated). */
      AND (
            @EntityIds IS NULL
        OR  (@Bucket LIKE 'cms.%' AND EXISTS (
                SELECT 1 FROM dbo.space_member sm
                JOIN dbo.space sp ON sp.id = sm.space_id AND sp.is_deleted = 0
                WHERE sm.user_id = u.id AND sm.is_deleted = 0
                  AND sp.entity_id IN (SELECT id FROM @Entities)))
        OR  (@Bucket LIKE 'immersive.%' AND EXISTS (
                SELECT 1 FROM dbo.user_session_management usm
                JOIN dbo.space sp ON sp.id = usm.space_id AND sp.is_deleted = 0
                WHERE usm.user_id = u.id AND usm.is_deleted = 0
                  AND sp.entity_id IN (SELECT id FROM @Entities)))
      )
      AND (
            @SpaceIds IS NULL
        OR  (@Bucket LIKE 'cms.%' AND EXISTS (
                SELECT 1 FROM dbo.space_member sm
                WHERE sm.user_id = u.id AND sm.is_deleted = 0
                  AND sm.space_id IN (SELECT id FROM @Spaces)))
        OR  (@Bucket LIKE 'immersive.%' AND EXISTS (
                SELECT 1 FROM dbo.user_session_management usm
                WHERE usm.user_id = u.id AND usm.is_deleted = 0
                  AND usm.space_id IN (SELECT id FROM @Spaces)))
      );

    -- Result set 1: distinct email domains available for THIS bucket, computed BEFORE
    -- @EmailDomain is applied below — the dropdown's option list must stay complete
    -- regardless of what's currently typed/selected.
    SELECT DISTINCT LOWER(SUBSTRING(u.email, CHARINDEX('@', u.email) + 1, 255)) AS Domain
    FROM dbo.[user] u
    WHERE u.id IN (SELECT id FROM #matched)
      AND u.email IS NOT NULL AND CHARINDEX('@', u.email) > 0
    ORDER BY Domain;

    -- Email-domain filter narrows #matched itself, so every result set from here on (total
    -- count, the page, its spaces) reflects it consistently.
    IF @EmailDomain IS NOT NULL
        DELETE m FROM #matched m
        JOIN dbo.[user] u ON u.id = m.id
        WHERE u.email IS NULL OR u.email NOT LIKE '%' + @EmailDomain + '%';

    -- Result set 2: total match count (drives the popup's pagination controls).
    SELECT COUNT(*) AS TotalCount FROM #matched;

    -- Page of ids, computed once and reused by both enrichment queries below so the users
    -- result set and the spaces result set can never disagree on who's on this page.
    CREATE TABLE #pageIds (id UNIQUEIDENTIFIER PRIMARY KEY);
    INSERT INTO #pageIds (id)
    SELECT u.id
    FROM dbo.[user] u
    WHERE u.id IN (SELECT id FROM #matched)
    ORDER BY u.email
    OFFSET (@Page - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    -- Result set 3: the page's users. CreatedTime is the account's "joined" date, rendered
    -- date-only by the frontend. IsDeleted is the row-level tag the popup shows alongside the
    -- existing IsGuest tag (a row can carry both — a deleted guest). LastLoginAt is NULL for
    -- any user with no recorded Immersive session — every CMS-only user, since CMS has no
    -- login instrumentation. SessionCount is only meaningful for immersive.dau/mau/wau
    -- (sessions within that window); every other bucket returns NULL, not 0 — "not
    -- applicable" is not "zero sessions".
    SELECT u.id AS UserId, u.email AS Email, u.display_name AS DisplayName,
           CASE WHEN ISNULL(lt.[type], 'unknown') = 'guest' THEN 1 ELSE 0 END AS IsGuest,
           u.is_deleted AS IsDeleted,
           u.created_time AS CreatedTime,
           (SELECT MAX(usm.start_time) FROM dbo.user_session_management usm
            WHERE usm.user_id = u.id AND usm.is_deleted = 0) AS LastLoginAt,
           CASE
               WHEN @Bucket = 'immersive.dau' THEN
                   (SELECT COUNT(*) FROM dbo.user_session_management usmD2
                    WHERE usmD2.user_id = u.id AND usmD2.is_deleted = 0
                      AND usmD2.start_time >= @TodayStart AND usmD2.start_time < @TomorrowStart)
               WHEN @Bucket = 'immersive.mau' THEN
                   (SELECT COUNT(*) FROM dbo.user_session_management usmM2
                    WHERE usmM2.user_id = u.id AND usmM2.is_deleted = 0
                      AND usmM2.start_time >= @Mau30Start AND usmM2.start_time < @TomorrowStart)
               WHEN @Bucket = 'immersive.wau' THEN
                   (SELECT COUNT(*) FROM dbo.user_session_management usmW2
                    WHERE usmW2.user_id = u.id AND usmW2.is_deleted = 0
                      AND usmW2.start_time >= @Wau7Start AND usmW2.start_time < @TomorrowStart)
               ELSE NULL
           END AS SessionCount
    FROM #pageIds pi
    JOIN dbo.[user] u ON u.id = pi.id
    LEFT JOIN dbo.login_type lt ON lt.id = u.login_type_id
    ORDER BY u.email;

    -- Result set 4: space memberships for exactly this page — union of both attribution
    -- paths (CMS membership, Immersive sessions), deduped.
    SELECT DISTINCT pi.id AS UserId, sp.id AS SpaceId, sp.display_name AS SpaceName
    FROM #pageIds pi
    JOIN dbo.space_member sm ON sm.user_id = pi.id AND sm.is_deleted = 0
    JOIN dbo.space sp ON sp.id = sm.space_id AND sp.is_deleted = 0
    UNION
    SELECT DISTINCT pi.id, sp.id, sp.display_name
    FROM #pageIds pi
    JOIN dbo.user_session_management usm ON usm.user_id = pi.id AND usm.is_deleted = 0
    JOIN dbo.space sp ON sp.id = usm.space_id AND sp.is_deleted = 0;

    DROP TABLE #pageIds;
    DROP TABLE #matched;
END

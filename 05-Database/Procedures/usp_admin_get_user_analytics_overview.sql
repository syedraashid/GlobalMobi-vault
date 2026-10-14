/* ---------------------------------------------------------------------------
   2. dbo.usp_admin_get_user_analytics_overview — Overall tab
   --------------------------------------------------------------------------- */
CREATE   PROCEDURE [dbo].[usp_admin_get_user_analytics_overview]
    @FromDate        DATE         = NULL,
    @ToDate          DATE         = NULL,
    @EmailDomain     VARCHAR(255) = NULL,
    @TzOffsetMinutes INT          = 0
AS
BEGIN
    SET NOCOUNT ON;

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

    -- Result set 1: available email domains — CUMULATIVE as of @ToDate (created_time <
    -- @ToUtc), matching Total's semantics, not New Users' window.
    SELECT DISTINCT LOWER(SUBSTRING(u.email, CHARINDEX('@', u.email) + 1, 255)) AS Domain
    FROM dbo.[user] u
    WHERE (@ToDate IS NULL OR u.created_time < @ToUtc)
      AND u.email IS NOT NULL AND CHARINDEX('@', u.email) > 0
    ORDER BY Domain;

    -- Result set 2: headline. TotalUsers/ActiveUsers/DeletedUsers/CmsUsers/ImmersiveUsers/
    -- BothProducts/GuestUsers are CUMULATIVE (created_time < @ToUtc, no lower bound).
    -- CmsUsers/ImmersiveUsers/BothProducts/GuestUsers keep their own is_deleted = 0 check.
    -- NewUsers is the only field using the windowed predicate.
    SELECT
        ISNULL(COUNT(*), 0) AS TotalUsers,
        ISNULL(SUM(CASE WHEN u.is_deleted = 0 THEN 1 ELSE 0 END), 0) AS ActiveUsers,
        ISNULL(SUM(CASE WHEN u.is_deleted = 1 THEN 1 ELSE 0 END), 0) AS DeletedUsers,
        ISNULL(SUM(CASE WHEN u.is_deleted = 0 AND u.cms_oid IS NOT NULL THEN 1 ELSE 0 END), 0) AS CmsUsers,
        ISNULL(SUM(CASE WHEN u.is_deleted = 0 AND u.oid     IS NOT NULL THEN 1 ELSE 0 END), 0) AS ImmersiveUsers,
        ISNULL(SUM(CASE WHEN u.is_deleted = 0 AND u.cms_oid IS NOT NULL AND u.oid IS NOT NULL THEN 1 ELSE 0 END), 0) AS BothProducts,
        ISNULL(SUM(CASE WHEN u.is_deleted = 0 AND ISNULL(lt.[type], 'unknown') = 'guest' THEN 1 ELSE 0 END), 0) AS GuestUsers,
        ISNULL(SUM(CASE WHEN @FromDate IS NOT NULL AND u.is_deleted = 0
                           AND u.created_time >= @FromUtc AND u.created_time < @ToUtc
                      THEN 1 ELSE 0 END), 0) AS NewUsers
    FROM dbo.[user] u
    LEFT JOIN dbo.login_type lt ON lt.id = u.login_type_id
    WHERE (@ToDate IS NULL OR u.created_time < @ToUtc)
      AND (@EmailDomain IS NULL OR u.email LIKE '%' + @EmailDomain + '%');

    -- Result set 3: New Users per calendar day. Under a specific window, scoped to
    -- [@FromDate,@ToDate) exactly like the NewUsers scalar above. Under All Time (@FromDate
    -- NULL), returns every day across the account's full history instead of nothing — the
    -- repository zero-fills gaps and auto-buckets to weekly for long spans.
    SELECT CAST(u.created_time AS DATE) AS Day, COUNT(*) AS NewUsers
    FROM dbo.[user] u
    WHERE u.is_deleted = 0
      AND (@FromDate IS NULL OR (u.created_time >= @FromUtc AND u.created_time < @ToUtc))
      AND (@EmailDomain IS NULL OR u.email LIKE '%' + @EmailDomain + '%')
    GROUP BY CAST(u.created_time AS DATE)
    ORDER BY Day;
END

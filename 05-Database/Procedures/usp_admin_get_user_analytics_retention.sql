--------------------------------------------------------------------------- */
CREATE   PROCEDURE [dbo].[usp_admin_get_user_analytics_retention]
    @CohortMonthStart DATE,
    @EntityIds        VARCHAR(MAX) = NULL,
    @SpaceIds         VARCHAR(MAX) = NULL,
    @EmailDomain      VARCHAR(255) = NULL,
    @TzOffsetMinutes  INT          = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @SpaceIds IS NOT NULL SET @EntityIds = NULL;
    IF @TzOffsetMinutes IS NULL SET @TzOffsetMinutes = 0;
    IF LTRIM(RTRIM(ISNULL(@EmailDomain, ''))) = '' SET @EmailDomain = NULL;

    DECLARE @MonthStart          DATE = DATEFROMPARTS(YEAR(@CohortMonthStart), MONTH(@CohortMonthStart), 1);
    DECLARE @MonthEndExclusive   DATE = DATEADD(month, 1, @MonthStart);
    DECLARE @MonthStartUtc DATETIME2(3) = DATEADD(minute, -@TzOffsetMinutes, CAST(@MonthStart        AS DATETIME2(3)));
    DECLARE @MonthEndUtc   DATETIME2(3) = DATEADD(minute, -@TzOffsetMinutes, CAST(@MonthEndExclusive AS DATETIME2(3)));

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

    -- Cohort: distinct users whose first-ever session (all-time, across all history — not
    -- bounded to the cohort month on the far side) falls within [@MonthStartUtc,@MonthEndUtc).
    CREATE TABLE #cohort (user_id UNIQUEIDENTIFIER PRIMARY KEY, first_day DATE NOT NULL);

    INSERT INTO #cohort (user_id, first_day)
    SELECT fs.user_id, CAST(fs.first_start AS DATE)
    FROM (
        SELECT usm.user_id, MIN(usm.start_time) AS first_start
        FROM dbo.user_session_management usm
        WHERE usm.is_deleted = 0
        GROUP BY usm.user_id
    ) fs
    JOIN dbo.[user] u ON u.id = fs.user_id
    WHERE fs.first_start >= @MonthStartUtc AND fs.first_start < @MonthEndUtc
      AND (@EmailDomain IS NULL OR u.email LIKE '%' + @EmailDomain + '%')
      AND (@EntityIds IS NULL OR EXISTS (
              SELECT 1 FROM dbo.user_session_management usmE
              JOIN dbo.space spE ON spE.id = usmE.space_id AND spE.is_deleted = 0
              WHERE usmE.user_id = fs.user_id AND usmE.is_deleted = 0
                AND spE.entity_id IN (SELECT id FROM @Entities)))
      AND (@SpaceIds IS NULL OR EXISTS (
              SELECT 1 FROM dbo.user_session_management usmS
              WHERE usmS.user_id = fs.user_id AND usmS.is_deleted = 0
                AND usmS.space_id IN (SELECT id FROM @Spaces)));

    DECLARE @CohortSize INT = (SELECT COUNT(*) FROM #cohort);

    -- Dn = % of the cohort with a session on EXACTLY (their own first_day + n) — the classic
    -- day-N retention curve, not "any session within the first n days". Null (not 0) when the
    -- cohort is empty — a divide-by-zero guard, not a real 0% rate.
    SELECT
        @MonthStart  AS CohortMonth,
        @CohortSize  AS CohortSize,
        CASE WHEN @CohortSize > 0 THEN
            CAST(100.0 * (SELECT COUNT(DISTINCT c.user_id)
                          FROM #cohort c
                          WHERE EXISTS (
                              SELECT 1 FROM dbo.user_session_management usmD1
                              WHERE usmD1.user_id = c.user_id AND usmD1.is_deleted = 0
                                AND CAST(usmD1.start_time AS DATE) = DATEADD(day, 1, c.first_day)))
                 / @CohortSize AS DECIMAL(5,1))
        END AS D1Pct,
        CASE WHEN @CohortSize > 0 THEN
            CAST(100.0 * (SELECT COUNT(DISTINCT c.user_id)
                          FROM #cohort c
                          WHERE EXISTS (
                              SELECT 1 FROM dbo.user_session_management usmD7
                              WHERE usmD7.user_id = c.user_id AND usmD7.is_deleted = 0
                                AND CAST(usmD7.start_time AS DATE) = DATEADD(day, 7, c.first_day)))
                 / @CohortSize AS DECIMAL(5,1))
        END AS D7Pct,
        CASE WHEN @CohortSize > 0 THEN
            CAST(100.0 * (SELECT COUNT(DISTINCT c.user_id)
                          FROM #cohort c
                          WHERE EXISTS (
                              SELECT 1 FROM dbo.user_session_management usmD30
                              WHERE usmD30.user_id = c.user_id AND usmD30.is_deleted = 0
                                AND CAST(usmD30.start_time AS DATE) = DATEADD(day, 30, c.first_day)))
                 / @CohortSize AS DECIMAL(5,1))
        END AS D30Pct;

    DROP TABLE #cohort;
END

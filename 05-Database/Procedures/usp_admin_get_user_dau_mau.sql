CREATE   PROCEDURE [dbo].[usp_admin_get_user_dau_mau]
    @Date            DATE = NULL,
    @EntityIds       VARCHAR(MAX) = NULL,
    @SpaceIds        VARCHAR(MAX) = NULL,
    @TzOffsetMinutes INT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @SpaceIds IS NOT NULL SET @EntityIds = NULL;
    IF @Date IS NULL SET @Date = CAST(GETUTCDATE() AS DATE);
    IF @TzOffsetMinutes IS NULL SET @TzOffsetMinutes = 0;

    DECLARE @DayStartUtc   DATETIME2(3) = DATEADD(minute, -@TzOffsetMinutes, CAST(@Date AS DATETIME2(3)));
    DECLARE @DayEndUtc     DATETIME2(3) = DATEADD(day, 1, @DayStartUtc);

    DECLARE @MonthStartUtc DATETIME2(3) = DATEADD(minute, -@TzOffsetMinutes,
        CAST(DATEFROMPARTS(YEAR(@Date), MONTH(@Date), 1) AS DATETIME2(3)));
    DECLARE @MonthEndUtc   DATETIME2(3) = DATEADD(month, 1, @MonthStartUtc);

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

    SELECT
        @Date AS ReportDate,
        COUNT(DISTINCT usm.user_id) AS DAU
    FROM dbo.user_session_management usm
    LEFT JOIN dbo.space sp ON sp.id = usm.space_id AND sp.is_deleted = 0
    WHERE usm.is_deleted = 0
      AND usm.last_active_time >= @DayStartUtc
      AND usm.last_active_time <  @DayEndUtc
      AND (@EntityIds IS NULL OR sp.entity_id IN (SELECT id FROM @Entities))
      AND (@SpaceIds  IS NULL OR usm.space_id  IN (SELECT id FROM @Spaces));

    SELECT
        DATEFROMPARTS(YEAR(@Date), MONTH(@Date), 1) AS ReportMonth,
        COUNT(DISTINCT usm.user_id) AS MAU
    FROM dbo.user_session_management usm
    LEFT JOIN dbo.space sp ON sp.id = usm.space_id AND sp.is_deleted = 0
    WHERE usm.is_deleted = 0
      AND usm.last_active_time >= @MonthStartUtc
      AND usm.last_active_time <  @MonthEndUtc
      AND (@EntityIds IS NULL OR sp.entity_id IN (SELECT id FROM @Entities))
      AND (@SpaceIds  IS NULL OR usm.space_id  IN (SELECT id FROM @Spaces));

    SELECT
        e.id AS EntityId,
        e.name_key AS EntityName,
        COUNT(DISTINCT CASE WHEN usm.last_active_time >= @DayStartUtc
                              AND usm.last_active_time <  @DayEndUtc
                             THEN usm.user_id END) AS DAU,
        COUNT(DISTINCT CASE WHEN usm.last_active_time >= @MonthStartUtc
                              AND usm.last_active_time <  @MonthEndUtc
                             THEN usm.user_id END) AS MAU
    FROM dbo.user_session_management usm
    JOIN dbo.space  sp ON sp.id = usm.space_id AND sp.is_deleted = 0
    JOIN dbo.entity e  ON e.id  = sp.entity_id AND e.is_deleted = 0
    WHERE usm.is_deleted = 0
      AND usm.last_active_time >= @MonthStartUtc
      AND usm.last_active_time <  @MonthEndUtc
      AND (@EntityIds IS NULL OR sp.entity_id IN (SELECT id FROM @Entities))
      AND (@SpaceIds  IS NULL OR usm.space_id  IN (SELECT id FROM @Spaces))
    GROUP BY e.id, e.name_key
    ORDER BY MAU DESC, EntityName;
END

CREATE   PROCEDURE [dbo].[sp_Event_GetBySpace_Unity]
    @SpaceId INT,
    -- "Today" per the business timezone (Eastern), computed in C# (BusinessClock.TodayEastern())
    -- and passed in — same convention as the Ad schedule feature's @Date (AdScheduleRepository).
    -- Deliberately NOT computed here via SYSUTCDATETIME(): that would silently reintroduce a
    -- UTC day-boundary that doesn't match the business's actual "today".
    @Today DATE
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        e.id, e.space_id, e.platform_type_id, e.event_type_id, e.personality_id,
        e.event_url, e.is_live, e.subtitle_enabled, e.scheduled_length,
        e.scheduled_start_datetime, e.scheduled_end_datetime,
        e.actual_start_datetime, e.actual_end_datetime, e.rating,
        e.capacity, e.event_format_id,
        et.type AS event_type_name, pt.platform_name AS platform_type_name, ef.name AS event_format_name,
        e.localized_name_id AS name_key, e.description_id AS description_key,
        e.modified_time, e.modified_by,
        ln.locale_id AS name_locale_id, ln.[value] AS name_value,
        ld.locale_id AS desc_locale_id,  ld.[value] AS desc_value,
        h.stream_url AS hosting_stream_url, h.is_active AS hosting_is_active,
        p.full_name AS personality_name, p.sport_id AS personality_sport_id, p.entity_id AS personality_entity_id,
        p.bio_data_key AS personality_bio_key,
        pb.locale_id AS personality_bio_locale_id, pb.[value] AS personality_bio_value,
        ppm.locale_id AS personality_photo_locale_id, ppm.media_link AS personality_photo_link
    FROM [event] e
    LEFT JOIN hosting h ON h.event_id = e.id AND h.is_deleted = 0
    LEFT JOIN personality p ON p.id = e.personality_id
    LEFT JOIN event_type et ON et.id = e.event_type_id
    LEFT JOIN platform_type pt ON pt.id = e.platform_type_id
    LEFT JOIN event_format ef ON ef.id = e.event_format_id

    OUTER APPLY (
        SELECT locale_id FROM i18n WHERE [key] = e.localized_name_id
        UNION
        SELECT locale_id FROM i18n WHERE [key] = e.description_id
        UNION
        SELECT locale_id FROM i18n WHERE [key] = p.bio_data_key
        UNION
        SELECT locale_id FROM media_localization WHERE media_id = p.media_id
    ) locs
    LEFT JOIN i18n ln ON ln.[key] = e.localized_name_id AND ln.locale_id = locs.locale_id
    LEFT JOIN i18n ld ON ld.[key] = e.description_id AND ld.locale_id = locs.locale_id
    LEFT JOIN i18n pb ON pb.[key] = p.bio_data_key AND pb.locale_id = locs.locale_id
    LEFT JOIN media_localization ppm ON ppm.media_id = p.media_id AND ppm.locale_id = locs.locale_id
    -- Unity's list should only ever show non-expired events (active or upcoming) — compared
    -- by DATE only, not exact time. A same-day event stays visible all day regardless of
    -- what time it is right now.
    WHERE e.space_id = @SpaceId AND e.is_deleted = 0 AND e.[status] = 'approved'
      AND CAST(e.scheduled_end_datetime AS DATE) >= @Today
    ORDER BY e.id, locs.locale_id;
END;

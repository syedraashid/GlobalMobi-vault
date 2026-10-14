CREATE   PROCEDURE [dbo].[sp_Event_GetBySpace]
    @SpaceId INT
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
        e.modified_time, e.modified_by, e.[status] AS content_status,
        ln.locale_id AS name_locale_id, ln.[value] AS name_value,
        ld.locale_id AS desc_locale_id,  ld.[value] AS desc_value,
        h.stream_url AS hosting_stream_url, h.is_active AS hosting_is_active, h.id AS hosting_id,
        p.full_name AS personality_name, p.sport_id AS personality_sport_id, p.entity_id AS personality_entity_id,
        p.bio_data_key AS personality_bio_key,
        pb.locale_id AS personality_bio_locale_id, pb.[value] AS personality_bio_value,
        ppm.locale_id AS personality_photo_locale_id, ppm.media_link AS personality_photo_link,
        ca.status AS approval_status, ca.id AS approval_id,
        ca.action_type AS approval_action_type,
        ca.current_snapshot, ca.proposed_snapshot
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
    OUTER APPLY (
        SELECT TOP (1) ca2.id, ca2.status, ca2.action_type, ca2.current_snapshot, ca2.proposed_snapshot
        FROM content_approval ca2
        WHERE ca2.content_type = 'event' AND ca2.content_id = e.id AND ca2.status <> 'withdrawn'
        ORDER BY ca2.submitted_at DESC
    ) ca
    WHERE e.space_id = @SpaceId AND e.is_deleted = 0
    ORDER BY e.id, locs.locale_id;
END;

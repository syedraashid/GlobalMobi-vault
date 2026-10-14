CREATE   PROCEDURE [dbo].[sp_Booth_GetById]
    @SpaceId INT,
    @BoothId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        b.id,
        b.space_id,
        b.name_key,
        b.map_spot_id,
        ms.x,
        ms.y,
        ms.z,
        i.locale_id,
        i.[value],
        COALESCE(ca.[status], b.[status]) AS approval_status,
        ca.id         AS approval_id,
        ca.[action_type] AS approval_action_type,
        ca.[current_snapshot]  AS current_snapshot,
        ca.[proposed_snapshot] AS proposed_snapshot,
        b.[status]             AS content_status,
        b.icon_key             AS icon_key -- NEW
    FROM   booth b
    LEFT JOIN i18n i
           ON  i.[key]      = b.name_key
           AND i.space_id   = b.space_id
           AND i.is_deleted = 0
    LEFT JOIN map_spot ms
           ON  ms.id = b.map_spot_id
    LEFT JOIN dbo.content_approval ca
           ON  ca.content_type = 'booth'
           AND ca.content_id   = b.id
           AND ca.[status]    != 'withdrawn'
    WHERE  b.space_id = @SpaceId
      AND  b.id       = @BoothId
    ORDER BY i.locale_id;
END;

CREATE   PROCEDURE [dbo].[sp_PortalLinks_GetApproved_Unity]
    @SpaceId   INT,
    @PortalIds NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;

    SELECT
        pl.id                  AS link_id,
        pl.portal_id,
        pl.position_id,
        pl.external_link,
        pl.thumbnail_media_id  AS thumb_media_id,
        tm.media_type_id       AS thumb_media_type_id,
        sl.locale_id,
        tl.media_link          AS thumb_media_link
    FROM portal_link pl
    JOIN (SELECT CAST([value] AS INT) AS id FROM OPENJSON(@PortalIds)) ids
        ON ids.id = pl.portal_id
    LEFT JOIN media tm
           ON tm.id         = pl.thumbnail_media_id
          AND tm.space_id   = @SpaceId
          AND tm.is_deleted = 0
    LEFT JOIN supported_languages sl
           ON sl.space_id = @SpaceId
    LEFT JOIN media_localization tl
           ON tl.media_id   = pl.thumbnail_media_id
          AND tl.locale_id  = sl.locale_id
          AND tl.is_deleted = 0
    WHERE pl.is_deleted = 0
      AND pl.[status]   = 'approved'
    ORDER BY pl.portal_id, pl.id, sl.locale_id;
END;

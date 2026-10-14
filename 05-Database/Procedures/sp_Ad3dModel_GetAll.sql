CREATE   PROCEDURE [dbo].[sp_Ad3dModel_GetAll]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT m.id, m.space_id, m.model_key, m.display_name, m.[description], m.is_active,
           m.preview_media_id, pm.media_type_id AS preview_media_type_id, pmt.[type] AS preview_media_type_name
    FROM   dbo.ad_3d_model m
    INNER JOIN dbo.space s       ON s.id = m.space_id AND s.is_deleted = 0
    LEFT JOIN  dbo.media pm      ON pm.id = m.preview_media_id AND pm.is_deleted = 0
    LEFT JOIN  dbo.media_type pmt ON pmt.id = pm.media_type_id
    WHERE  m.space_id = @SpaceId AND m.is_deleted = 0
    ORDER BY m.display_name, m.id;

    SELECT m.id AS model_id, ml.locale_id, ml.media_link
    FROM   dbo.ad_3d_model m
    INNER JOIN dbo.space s              ON s.id = m.space_id AND s.is_deleted = 0
    INNER JOIN dbo.media pm             ON pm.id = m.preview_media_id AND pm.is_deleted = 0
    INNER JOIN dbo.media_localization ml ON ml.media_id = m.preview_media_id AND ml.is_deleted = 0
    WHERE  m.space_id = @SpaceId AND m.is_deleted = 0
    ORDER BY m.id, ml.locale_id;
END

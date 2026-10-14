-- One model. RS1 has 0 rows = not found.
CREATE   PROCEDURE [dbo].[sp_Ad3dModel_GetById]
    @SpaceId INT,
    @Id      INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT m.id, m.space_id, m.model_key, m.display_name, m.[description], m.is_active,
           m.preview_media_id, pm.media_type_id AS preview_media_type_id, pmt.[type] AS preview_media_type_name
    FROM   dbo.ad_3d_model m
    INNER JOIN dbo.space s       ON s.id = m.space_id AND s.is_deleted = 0
    LEFT JOIN  dbo.media pm      ON pm.id = m.preview_media_id AND pm.is_deleted = 0
    LEFT JOIN  dbo.media_type pmt ON pmt.id = pm.media_type_id
    WHERE  m.id = @Id AND m.space_id = @SpaceId AND m.is_deleted = 0;

    SELECT m.id AS model_id, ml.locale_id, ml.media_link
    FROM   dbo.ad_3d_model m
    INNER JOIN dbo.space s              ON s.id = m.space_id AND s.is_deleted = 0
    INNER JOIN dbo.media pm             ON pm.id = m.preview_media_id AND pm.is_deleted = 0
    INNER JOIN dbo.media_localization ml ON ml.media_id = m.preview_media_id AND ml.is_deleted = 0
    WHERE  m.id = @Id AND m.space_id = @SpaceId AND m.is_deleted = 0
    ORDER BY ml.locale_id;
END

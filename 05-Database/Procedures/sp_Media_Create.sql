CREATE   PROCEDURE [dbo].[sp_Media_Create]
    @SpaceId        INT,
    @MediaTypeId    INT,
    @CreatedBy      NVARCHAR(255),
    @TextKey        UNIQUEIDENTIFIER = NULL,
    @DescriptionKey UNIQUEIDENTIFIER = NULL,
    @LinkLocs       NVARCHAR(MAX)    = NULL,
    @TextLocs       NVARCHAR(MAX)    = NULL,
    @DescLocs       NVARCHAR(MAX)    = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Insert media
    DECLARE @MediaId BIGINT;

    INSERT INTO media (space_id, media_type_id, text_key, description_key, created_by)
    VALUES (@SpaceId, @MediaTypeId, @TextKey, @DescriptionKey, @CreatedBy);

    SET @MediaId = SCOPE_IDENTITY();

    -- link_locs
    IF @LinkLocs IS NOT NULL
    BEGIN
        INSERT INTO media_localization (media_id, locale_id, media_link, created_by)
        SELECT @MediaId, j.locale_id, j.media_link, @CreatedBy
        FROM   OPENJSON(@LinkLocs) WITH (
                   locale_id  NVARCHAR(20)  '$.locale_id',
                   media_link NVARCHAR(MAX) '$.media_link'
               ) j;
    END;

    -- text_locs
    IF @TextLocs IS NOT NULL AND @TextKey IS NOT NULL
    BEGIN
        INSERT INTO i18n ([key], locale_id, [value], space_id, created_by)
        SELECT @TextKey, j.locale_id, j.[value], @SpaceId, @CreatedBy
        FROM   OPENJSON(@TextLocs) WITH (
                   locale_id NVARCHAR(20)  '$.locale_id',
                   [value]   NVARCHAR(MAX) '$.value'
               ) j;
    END;

    -- desc_locs
    IF @DescLocs IS NOT NULL AND @DescriptionKey IS NOT NULL
    BEGIN
        INSERT INTO i18n ([key], locale_id, [value], space_id, created_by)
        SELECT @DescriptionKey, j.locale_id, j.[value], @SpaceId, @CreatedBy
        FROM   OPENJSON(@DescLocs) WITH (
                   locale_id NVARCHAR(20)  '$.locale_id',
                   [value]   NVARCHAR(MAX) '$.value'
               ) j;
    END;

    SELECT @MediaId AS media_id;
END;

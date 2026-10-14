CREATE   PROCEDURE [dbo].[usp_ContentApproval_Decide]
    @ApprovalId      INT,
    @Decision        VARCHAR(20),
    @RejectionReason VARCHAR(500)  = NULL,
    @DecidedBy       UNIQUEIDENTIFIER,
    @CallerUserId    VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Decision NOT IN ('approved','rejected')
    BEGIN
        RAISERROR('Invalid decision value. Must be ''approved'' or ''rejected''.', 16, 1);
        RETURN;
    END

    DECLARE @ContentType  VARCHAR(50);
    DECLARE @ContentId    BIGINT;
    DECLARE @SubmittedBy  UNIQUEIDENTIFIER;
    DECLARE @LastEditedBy UNIQUEIDENTIFIER;
    DECLARE @ContentName  NVARCHAR(255);
    DECLARE @ActionType   VARCHAR(10);
    DECLARE @ProposedData NVARCHAR(MAX);

    SELECT @ContentType  = [content_type],
           @ContentId    = [content_id],
           @SubmittedBy  = [submitted_by],
           @LastEditedBy = [last_edited_by],
           @ContentName  = [content_name],
           @ActionType   = [action_type],
           @ProposedData = [proposed_data]
    FROM   [dbo].[content_approval]
    WHERE  [id] = @ApprovalId AND [status] = 'pending';

    IF @ContentType IS NULL
    BEGIN
        SELECT 0 AS AffectedRows, NULL AS SubmittedBy, NULL AS ContentName, NULL AS ContentType;
        RETURN;
    END

    BEGIN TRANSACTION;

    UPDATE [dbo].[content_approval]
    SET    [status]           = @Decision,
           [decided_at]       = SYSUTCDATETIME(),
           [decided_by]       = @DecidedBy,
           [rejection_reason] = @RejectionReason,
           [modified_by]      = @CallerUserId,
           [modified_time]    = SYSUTCDATETIME()
    WHERE  [id] = @ApprovalId;

    DECLARE @TableName SYSNAME;
    DECLARE @IdColumn  SYSNAME = N'id';

    SELECT @TableName = CASE @ContentType
        WHEN 'booth'               THEN N'booth'
        WHEN 'booth_media'         THEN N'booth_media'
        WHEN 'portal'              THEN N'portal'
        WHEN 'custom_booth_item'   THEN N'custom_booth_item'
        WHEN 'event'               THEN N'event'
        WHEN 'teleport'            THEN N'teleport_table'
        WHEN 'teleport_button'     THEN N'teleport_table_button'
        WHEN 'item'                THEN N'item'
        WHEN 'charity'             THEN N'charity'
        WHEN 'hosting'             THEN N'hosting'
        WHEN 'advertiser'          THEN N'advertiser'
        WHEN 'campaign'            THEN N'advertiser_campaign'
        WHEN 'ad'                  THEN N'advertiser_ad'
        WHEN 'reward'              THEN N'reward'
        WHEN 'ai_moderation'       THEN N'rules'
        WHEN 'payment'             THEN N'payment_gateway_config'
        WHEN 'discount'            THEN N'discounts'
        WHEN 'recognition'         THEN N'predefined_comments'
        WHEN 'free_trial_setting'  THEN N'free_trial_settings'
        WHEN 'free_trial_item'     THEN N'free_trial_items'
        WHEN 'package'             THEN N'package'
        WHEN 'package_item'        THEN N'package_item'
        ELSE NULL
    END;

    IF @ContentType = 'booth_media' SET @IdColumn = N'media_id';

    IF @ActionType = 'create' AND @TableName IS NOT NULL
    BEGIN
        DECLARE @ContentStatus VARCHAR(20) = CASE WHEN @Decision = 'approved' THEN 'approved' ELSE 'draft' END;
        DECLARE @Sql NVARCHAR(300) = N'UPDATE [dbo].[' + @TableName
            + N'] SET [status] = @Status WHERE [' + @IdColumn + N'] = @Id';
        EXEC sp_executesql @Sql, N'@Status VARCHAR(20), @Id BIGINT', @ContentStatus, @ContentId;
    END


    IF @ContentType = 'portal' AND @ActionType = 'create'
    BEGIN
        UPDATE [dbo].[portal_link]
        SET    [status] = CASE WHEN @Decision = 'approved' THEN 'approved' ELSE 'draft' END
        WHERE  [portal_id] = @ContentId;
    END


    IF @ContentType = 'custom_booth_item' AND @ActionType = 'create'
    BEGIN
        UPDATE [dbo].[custom_booth_item_link]
        SET    [status] = CASE WHEN @Decision = 'approved' THEN 'approved' ELSE 'draft' END
        WHERE  [custom_booth_item_id] = @ContentId;
    END

    IF @ContentType = 'ad' AND @ActionType = 'create'
    BEGIN
        UPDATE [dbo].[portal]
        SET    [status] = CASE WHEN @Decision = 'approved' THEN 'approved' ELSE 'draft' END
        WHERE  [ad_id] = @ContentId AND [is_deleted] = 0;

        UPDATE pl
        SET    pl.[status] = CASE WHEN @Decision = 'approved' THEN 'approved' ELSE 'draft' END
        FROM   [dbo].[portal_link] pl
        INNER JOIN [dbo].[portal] p ON p.[id] = pl.[portal_id]
        WHERE  p.[ad_id] = @ContentId AND p.[is_deleted] = 0 AND pl.[is_deleted] = 0;
    END

    COMMIT TRANSACTION;

    SELECT 1               AS AffectedRows,
           @SubmittedBy    AS SubmittedBy,
           @ContentName    AS ContentName,
           @ContentType    AS ContentType,
           @ActionType     AS ActionType,
           @ProposedData   AS ProposedData,
           @ContentId      AS ContentId;
END

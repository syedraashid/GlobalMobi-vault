-- ============================================================
-- SP 2: usp_ContentApproval_Submit
-- Creates or resets the content_approval record.
-- Content tables are NEVER touched here (only draft/approved live there).
-- The content_approval record gets status='pending'.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_ContentApproval_Submit]
    @SpaceId        INT,
    @ContentType    VARCHAR(50),
    @ContentId      BIGINT,
    @ContentName    NVARCHAR(255),
    @SubmittedBy    UNIQUEIDENTIFIER,
    @LastEditedBy   UNIQUEIDENTIFIER = NULL,
    @CallerUserId   VARCHAR(36),
    @ActionType       VARCHAR(10)   = 'create',
    @ProposedData     NVARCHAR(MAX) = NULL,
    @CurrentSnapshot  NVARCHAR(MAX) = NULL,
    @ProposedSnapshot NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ExistingId INT;
    SELECT @ExistingId = [id]
    FROM   [dbo].[content_approval]
    WHERE  [content_type] = @ContentType AND [content_id] = @ContentId;

    BEGIN TRANSACTION;

    IF @ExistingId IS NULL
    BEGIN
        INSERT INTO [dbo].[content_approval]
            ([space_id],[content_type],[content_id],[content_name],
             [submitted_by],[last_edited_by],[status],[submitted_at],
             [action_type],[proposed_data],[current_snapshot],[proposed_snapshot],
             [created_by],[modified_by],[modified_time])
        VALUES
            (@SpaceId,@ContentType,@ContentId,@ContentName,
             @SubmittedBy,@LastEditedBy,'pending',SYSUTCDATETIME(),
             @ActionType,@ProposedData,@CurrentSnapshot,@ProposedSnapshot,
             @CallerUserId,@CallerUserId,SYSUTCDATETIME());
        SET @ExistingId = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        -- On resubmit (UPDATE), preserve existing snapshot data when caller passes NULL.
        -- CREATE resubmits may provide a fresh proposed_snapshot; edit/delete resubmits
        -- pass NULL so the original proposed_data and snapshots are retained intact.
        UPDATE [dbo].[content_approval]
        SET    [submitted_by]      = @SubmittedBy,
               [last_edited_by]    = @LastEditedBy,
               [content_name]      = @ContentName,
               [status]            = 'pending',
               [submitted_at]      = SYSUTCDATETIME(),
               [decided_at]        = NULL,
               [decided_by]        = NULL,
               [rejection_reason]  = NULL,
               [action_type]       = @ActionType,
               [proposed_data]     = ISNULL(@ProposedData,     [proposed_data]),
               [current_snapshot]  = ISNULL(@CurrentSnapshot,  [current_snapshot]),
               [proposed_snapshot] = ISNULL(@ProposedSnapshot, [proposed_snapshot]),
               [modified_by]       = @CallerUserId,
               [modified_time]     = SYSUTCDATETIME()
        WHERE  [id] = @ExistingId;
    END

    COMMIT TRANSACTION;

    SELECT @ExistingId   AS ApprovalId,
           @SubmittedBy  AS SubmittedBy,
           @LastEditedBy AS LastEditedBy;
END

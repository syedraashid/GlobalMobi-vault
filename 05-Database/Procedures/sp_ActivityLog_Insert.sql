-- ============================================================
-- Activity Log — Stored Procedures (Final — already clean, no versioning conflicts)
-- Source: sp_ActivityLog.sql
-- ============================================================
-- ============================================================
-- Activity Log Stored Procedures
-- Author : Syed Raashid
-- Date   : 05/20/2026
-- Run    : Execute once against the target database.
--          CREATE OR ALTER is idempotent — safe to re-run.
--
-- Production-grade pattern used in all three SPs:
--   SET XACT_ABORT ON  — any runtime error immediately aborts
--                        and rolls back the transaction, even if
--                        the error is caught; prevents leaving a
--                        connection in a half-committed state.
--   BEGIN TRY / BEGIN TRANSACTION / COMMIT
--   BEGIN CATCH / IF @@TRANCOUNT > 0 ROLLBACK / THROW
--                      — explicit transaction makes intent clear;
--                        ROLLBACK guard checks @@TRANCOUNT before
--                        rolling back so it is safe whether or not
--                        the transaction was ever opened (e.g., if
--                        the error occurred before BEGIN TRANSACTION).
--                        THROW re-raises the original error with its
--                        original number, severity, and state so the
--                        caller (C# LogWarning) gets full detail.
-- ============================================================


-- ------------------------------------------------------------
-- 1. INSERT — called by ActivityLoggingFilter after every
--    successful POST / PUT / DELETE across all controllers.
-- ------------------------------------------------------------
CREATE   PROCEDURE [dbo].[sp_ActivityLog_Insert]
    @SpaceId       INT,
    @EntityType    NVARCHAR(100),
    @EntityId      NVARCHAR(100),
    @EntityName    NVARCHAR(500) = NULL,
    @Action        NVARCHAR(50),
    @PerformedBy   NVARCHAR(255),
    @CorrelationId NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO activity_log
            (space_id, entity_type, entity_id, entity_name, action, performed_by, correlation_id)
        VALUES
            (@SpaceId, @EntityType, @EntityId, @EntityName, @Action, @PerformedBy, @CorrelationId);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

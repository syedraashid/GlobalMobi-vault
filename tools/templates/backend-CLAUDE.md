# CLAUDE.md

`TifoXRCoreWebAPI` is the ASP.NET Core 10 (net10.0) backend for the TifoXR VR platform. It serves the Unity WebGL app and the private, role-based CMS. Root namespace: `GMS.TifoXRCoreWebAPI.*`.

## Repo rules (decided by the team)

- **Never run the complete test suite for the API.** No unfiltered `dotnet test`. Run only the tests for the code you changed, with `--filter "FullyQualifiedName~SomeTests"`. (Vault note: ADR-0001.)
- **Every SQL change is a migration file**, written with the `sql-migration` skill and saved in `migration/` at the repo root (git-ignored, never committed). It must check before it acts so it can be re-run, run in one transaction that rolls back fully on any error, and verify its result before committing. Do not run it on prod. (Vault note: ADR-0002.)
- **Before any database work**, use the `db-context` skill. Check the database notes' as-of date; if they may be stale, **ask the user** whether to run the refresh. **Never run the refresh on your own**: it connects to the dev database and needs the user's permission every time.
- **Architecture and database notes** are in the TifoXR vault (folder in `$TIFOXR_VAULT`, printed at the start of the session). They were written from the code and can be wrong; check the code first.

## Commands

```powershell
dotnet restore TifoXRCoreWebAPI.sln
dotnet build TifoXRCoreWebAPI.sln
dotnet run --project TifoXRCoreWebAPI.csproj      # http://localhost:5211, swagger at /swagger
dotnet test TifoXRCoreWebAPI.Tests\TifoXRCoreWebAPI.Tests.csproj --filter "FullyQualifiedName~BoothRepositoryTests"
```

`appsettings.json` is git-ignored and holds real settings; you need your own local copy. CI builds and deploys but does not run tests.

## Plugin
Install the TifoXR Claude Code plugin from the vault repo (`node tools/setup.js` in the vault does it). It adds the session index, the database skills and the guard hooks.

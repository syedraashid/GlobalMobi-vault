---
title: "ADR-0001 Never Run The Full API Test Suite"
category: decisions
agent_hint: "Load before running any dotnet test in the API: never run the full suite."
index_tier: lazy
review_by: 2027-01-12
type: decision
status: accepted
owner: syed
decided_on: 2026-10-14
last_verified: 2026-10-14
tags: [decision, backend, testing]
---

# ADR-0001 Never Run The Full API Test Suite

## Decision
Never run the complete test suite for the backend API. This means no unfiltered `dotnet test` on `TifoXRCoreWebAPI.Tests`, and none on the whole solution. Run only the specific tests that cover the code you changed.

## How to apply
Always filter, for example:

```
dotnet test TifoXRCoreWebAPI.Tests\TifoXRCoreWebAPI.Tests.csproj --filter "FullyQualifiedName~BoothRepositoryTests"
```

If no test covers the change, say so instead of running everything. This applies to people, Claude and any agent.

## Known facts (not the recorded reason)
syed did not record why. What the code and docs show:
- The API test project has about 128 test files.
- Three of them use `SqlTestDbProvider`. The backend `CLAUDE.md` says some repository tests are integration tests that hit a **real SQL Server** through the `DefaultConnection` setting, so a full run can touch a real database. This was not independently verified.
- The backend pipeline does not run `dotnet test` either, so CI never runs the full suite.

## Consequences
Test coverage is checked by targeted runs only. Add the reason here if it differs from the facts above.

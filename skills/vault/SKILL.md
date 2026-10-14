---
name: vault
description: Load the TifoXR vault notes for the repo you are in (backend or CMS), then summarise what you now know. Run only when the user asks for it.
disable-model-invocation: true
argument-hint: "[optional topic: database | payments | auth | approvals | publishing | unity | cms]"
---

Load the TifoXR knowledge vault as working context for **this repo**. The vault folder is `$TIFOXR_VAULT` (it is also printed at the start of a TifoXR session, together with a short index). Topic from the user (may be empty): $ARGUMENTS

## Step 1: find out which repo you are in
Look at the current working directory and its git root name:
- `TifoXRCoreWebAPI` (or a worktree of it): **backend**
- `TifoXRContentManager` or `gms-content-management-system`: **CMS**
- Anything else: ask the user which part of TifoXR they mean, then continue.

## Step 2: read these notes with the Read tool
Always: `03-Decisions/Decision Log.md`, then `02-Architecture/Architecture Overview.md` and `01-Project/Module Status.md`.

By repo:
- **Backend:** `02-Architecture/Components/Backend API.md`, `EventFunctions.md`, `02-Architecture/Dynamic Pull Flow.md`, `Push Flows.md`, `Authentication.md`
- **CMS:** `02-Architecture/Components/CMS Frontend.md`, `02-Architecture/Approval Workflow.md`, `Authentication.md`, `Dynamic Pull Flow.md`

If a topic was given, also read:
- `database`: use the `db-context` skill (it loads only what the task needs)
- `payments`: the Payments section of `Push Flows.md`
- `auth`: `Authentication.md`; `approvals`: `Approval Workflow.md`; `publishing`: `Dynamic Pull Flow.md`
- `unity`: `02-Architecture/Components/Unity Contract.md`; `cms`: `CMS Frontend.md`

Paths are relative to the vault folder. If a file is missing, say so and carry on.

## Step 3: database freshness
Read the "as of" date in `05-Database/DB Current State.md` and tell the user. **Do not run the refresh.** If the notes are older than about 7 days, or the topic is `database`, ask the user whether they want to run `/refresh-db` and wait for the answer.

## Step 4: rules for the rest of the session
- Never run the complete API test suite; run filtered tests only (ADR-0001).
- Every SQL change is a migration file written with the `sql-migration` skill (ADR-0002).
- Never open or print the database access file.
- Never run the database refresh without asking the user first.
- The vault was written from the code and can be wrong. Check the code before relying on a claim, and if a note is wrong, tell the user and offer to correct it.
- Use plain ASCII in everything you write.

## Step 5: report back in at most 12 lines
Which repo you detected, which notes you read, the database notes' as-of date, the two or three "Not confirmed" items most relevant here, and "Ready. What are we working on?"

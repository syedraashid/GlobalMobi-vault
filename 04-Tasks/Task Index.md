---
title: "Task Index"
category: tasks
agent_hint: "Load to see open work, the backlog and open questions."
index_tier: lazy
status: live
review_by: 2027-01-12
type: task-index
owner: syed
last_verified: 2026-10-14
tags: [tasks]
---

# Task Index

Real tracking happens in **Azure DevOps Boards**. This note is a light index of the important items. Do not duplicate tickets here: one line, the work item ID, and a link.

## In progress
| Work | DevOps ID | Notes |
|---|---|---|
| Post-.NET 10 upgrade follow-up | (add ID) | Build and test on 10, check pipelines, check all environments, retire stale `CLAUDE.md` |
| This knowledge vault | (add ID) | Phase 1 skeleton done. See below. |

## Vault backlog
- [x] Dev schema imported and `/refresh-db` command built ([[DB Refresh Command]])
- [ ] Fill in `SQL_DEV_SERVER`, `SQL_DEV_DATABASE`, `SQL_DEV_USER`, `SQL_DEV_PASSWORD` in the access env file, then run `node tools/refresh-db.js --check`
- [ ] Run the first live `/refresh-db` (expect "Baseline switched" once)
- [ ] Make sure the account has VIEW DEFINITION so procedure text can be read
- [ ] Write procedure logic notes as development needs them (`/refresh-db --only ...`)
- [ ] Confirm schema dump date (14-10-2026 header vs 06-10-2026 file name)
- [ ] Get test and prod schema scripts to diff against dev
- [ ] Export lookup-table contents (statuses, types, roles) to document allowed values
- [ ] Decide whether to import the hand-written db-schema.md business rules after checking it against the dev schema
- [ ] Check how Rewards, Rules Engine and 3D Streaming reach the DB (no stored procedures)
- [x] Events status: phase 0, not usable ([[Module Status]])
- [ ] Define Events scope beyond phase 0
- [ ] Write the CMS role matrix (read `permissions.js` and backend policies)
- [ ] Phase 3: endpoint catalog tagged cms / unity / shared
- [ ] Phase 3: payment flow note, content approval note
- [ ] Set up read-only DB and Azure access for Claude
- [x] Plugin, session index hook, db-context skill, guard hook and setup script built ([[Claude Setup]], [[New Machine Setup]])
- [ ] Commit the vault and host it on a git remote (needed for teammates to install the plugin)
- [ ] Add tracked CLAUDE.md and .claude/settings.json to the backend and CMS repos by pull request (templates in tools/templates)
- [ ] After confirming the plugin works in a fresh session, delete the older user-level copies (see Claude Setup)
- [x] Payment and order queue consumers: removed, direct API calls ([[EventFunctions]])
- [x] Architecture notes rewritten from the code; all imported docs removed from the vault
- [ ] Write notes from the code for: payment flow, free trial, game announcement, penalty shootout
- [ ] Phase 3: endpoint catalog by area, and a CMS role-to-permission matrix
- [ ] Confirm which CMS edits skip approval
- [ ] Confirm Front Door and CDN setup per environment (not in the repos)

## Known issues
None recorded yet. Use [[Template - Runbook]] for repeatable fixes.

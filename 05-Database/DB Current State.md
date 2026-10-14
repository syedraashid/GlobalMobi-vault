---
title: "DB Current State"
category: database
agent_hint: "Load only when the task touches the database, tables or stored procedures. Check the as-of date and ask before refreshing."
index_tier: lazy
type: database
status: live
environment: dev
side: shared
owner: syed
source: "script file dev-06-10-2026-Schema-Only.sql"
snapshot_as_of: 2026-10-14T16:39:38
last_verified: 2026-10-14
generated: true
tags: [database, side/shared]
---

# DB Current State

**Read this first** before any development that touches the database. This is the **dev** database, the single source of truth.

## Freshness
| | |
|---|---|
| Environment | dev |
| Source | script file dev-06-10-2026-Schema-Only.sql |
| Database state as of | 2026-10-14T16:39:38 |
| Notes refreshed | 2026-10-14T12:17:10Z |
| Platform | Basic, max 2 GB, compatibility level 160 |

## Rule
Before database-related work, check the as-of date above. If the notes may be stale, **ask the user** whether to run `/refresh-db` (see [[DB Refresh Command]]). **Claude must not run the refresh without the user's permission.** If the refresh is not run, say the information may be stale and quote the date above. After a migration runs successfully on dev, ask the user to refresh again.

## Size
Tables 193, columns 1780, foreign keys 331, stored procedures 471, other modules (views, functions, triggers) 0, indexes 307.

## Domains
| Domain | Tables | Procedures |
|---|---|---|
| [[DB Spaces and Access]] | 18 | 57 |
| [[DB Users and Auth]] | 11 | 59 |
| [[DB Friends]] | 5 | 11 |
| [[DB Booths Portals and Teleport]] | 17 | 51 |
| [[DB Shop Items and Orders]] | 29 | 143 |
| [[DB Payments]] | 21 | 34 |
| [[DB Ads Campaigns and Charity]] | 10 | 37 |
| [[DB Content Media and Approval]] | 13 | 45 |
| [[DB Events]] | 4 | 9 |
| [[DB Games and Leaderboards]] | 20 | 21 |
| [[DB Rewards]] | 6 | 0 |
| [[DB Rules Engine]] | 20 | 0 |
| [[DB Metrics and Activity]] | 7 | 2 |
| [[DB 3D Streaming and Moderation]] | 12 | 0 |

Also: [[DB Table Catalog]], [[DB Unclassified Procedures]], [[DB Refresh Report]], [[DB Refresh Log]].

## Stored procedure business logic
Summaries live in `05-Database/Logic/`. Status now: 0 up to date, 0 stale, 471 not written. Each summary carries the hash of the SQL it was written from, so a changed procedure shows as STALE. Do not trust a STALE or missing summary; read the SQL file in `05-Database/Procedures/`.

Human notes about the database (meaning, history): [[Database]].

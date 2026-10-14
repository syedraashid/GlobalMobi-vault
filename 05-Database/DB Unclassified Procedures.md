---
title: "DB Unclassified Procedures"
category: database
agent_hint: "Load to find stored procedures that touch no table."
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

# DB Unclassified Procedures

Procedures with no table reference found in their SQL text (they may call other procedures or use dynamic SQL). Count: 2. Part of [[DB Current State]].

- sp_AdPortal_Remove (logic: missing)
- usp_admin_update_member_role (logic: missing)

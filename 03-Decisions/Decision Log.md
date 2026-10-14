---
title: "Decision Log"
category: decisions
agent_hint: "Load before running tests, writing SQL or making any database change: the standing team decisions."
index_tier: eager
status: live
review_by: 2027-01-12
type: decision-index
owner: syed
last_verified: 2026-10-14
tags: [decision]
---

# Decision Log

One note per decision, named `ADR-NNNN Title`. Copy [[Template - Decision]]. Only real, lasting decisions belong here.

| ID | Decision |
|---|---|
| [[ADR-0001 Never Run The Full API Test Suite]] | Run only targeted tests for the API, never the whole suite |
| [[ADR-0002 SQL Changes Are Safe Migration Files]] | All SQL changes are re-runnable, transactional, verified migration files in the git-ignored backend `migration` folder |

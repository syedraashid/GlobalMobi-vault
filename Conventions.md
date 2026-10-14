---
title: "Conventions"
category: conventions
agent_hint: "Load before writing or editing vault notes: properties, status rule, no secrets, plain ASCII."
index_tier: lazy
status: live
review_by: 2027-01-12
type: convention
owner: syed
last_verified: 2026-10-14
tags: [convention]
---

# Conventions

Rules for everyone who edits this vault. Keep it short so people actually follow it.

## Properties (front matter) on every note
| Property | Meaning |
|---|---|
| `title` | must equal the file name without `.md` |
| `category` | project, architecture, decisions, tasks, database, conventions |
| `agent_hint` | one line (under 200 characters) saying when Claude should read this note |
| `index_tier` | `eager` (listed with its hint in the session index; at most 8 notes) or `lazy` (listed by title only) |
| `review_by` | date by which a hand-written note must be re-checked against the code (generated notes do not need it) |
| `type` | component, module, decision, runbook, task-index, convention |
| `status` | live, planned, in-development, deprecated |
| `side` | cms, unity, or shared (who the thing serves) |
| `owner` | a person's name. Default is syed. |
| `last_verified` | date someone last checked the note against code or the running system |

`node tools/check-vault.js` validates all of this (and links, ASCII, secrets). After changing a note's properties run `node tools/build-index.js` to refresh `vault-index.md`. The git pre-commit hook runs both.

## The status rule
A module on the `develop` branch of the backend or CMS counts as **live**. Anything not on `develop` is `planned` or `in-development`.

## Naming
- Notes: plain English titles, one concept per note, e.g. `Backend API`, `Payment Flow`.
- Decisions: `ADR-0001 Short Title`.
- No dates in titles. Dates go in properties.

## Links and tags
- Link to the note that owns a fact. Do not restate it. If you copy a fact, it will go stale.
- Tags use `#side/cms`, `#side/unity`, `#side/shared` and `#status/live`, `#status/planned`. Avoid inventing new tags; add them here first.

## One fact, one home
Before creating a note, search for it. If a note exists, extend it. Write facts from code you have read, and say where they came from.

## Secrets: never in this vault
Document config key **names** and where the secret lives (for example a Key Vault name). Never write a value: no connection strings, API keys, client secrets, JWT keys, passwords, tokens.

## Keep notes ASCII
Use plain hyphens and straight quotes. Avoid fancy dashes, curly quotes, arrows and ellipsis characters; they corrupt in some tools.

## Verification
When you confirm a note is still correct, update `last_verified`. A note older than 90 days with status `live` is suspect.

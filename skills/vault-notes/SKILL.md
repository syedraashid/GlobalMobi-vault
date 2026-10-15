---
name: vault-notes
description: Use whenever you create or edit a note in the TifoXR knowledge vault. Gives the exact folder, properties, tags, links and size rules so the note passes check-vault and stays small, linked and easy to find in Obsidian.
---

# Writing TifoXR vault notes

Follow this every time you create or edit a note in `$TIFOXR_VAULT`. `Conventions.md` in the vault is the master; if this text and that note disagree, the note wins and you tell the user.

## Before writing
1. **One fact, one home.** Search the vault for the topic first (Grep for a keyword). If a note owns it, extend that note. Create a new note only when no note fits.
2. **Write facts you have read in code or seen working.** Put the source on one line at the end: `Source: <repo>/<path>`. Never copy chat, ticket text or debugging stories.
3. **Never write a secret value.** Key names and where the value lives only.
4. Do **not** hand-edit generated database notes (`05-Database`, except `Database.md` and `Logic/`). The refresh command rewrites them.

## Where a note goes
| category | folder | use for |
|---|---|---|
| project | `01-Project/` | overview, module status, setup runbooks |
| architecture | `02-Architecture/` (`Components/` for one component) | flows, components, contracts |
| decisions | `03-Decisions/` | `ADR-NNNN Short Title.md` (next free number) |
| tasks | `04-Tasks/` | the task index only, one line per item with the DevOps ID |
| database | `05-Database/` | human database notes and `Logic/` procedure summaries |
| conventions | vault root | rules for editing the vault |

File name = the title, plain English, no dates, no version numbers.

## Properties (top of every note, exactly these)
```
---
title: "Same As File Name"
category: architecture
agent_hint: "One line, under 200 characters: when should Claude load this note?"
index_tier: lazy
review_by: yyyy-mm-dd
type: component
status: live
side: shared
owner: syed
last_verified: yyyy-mm-dd
tags: [architecture, side/shared]
---
```
- `index_tier` is `lazy` unless the user says otherwise. At most 8 notes in the whole vault may be `eager`; never add one yourself.
- `status`: live (on the `develop` branch), in-development, planned, deprecated, accepted (decisions), draft.
- `type`: component, module, architecture, decision, runbook, task-index, convention.
- `side`: cms, unity or shared.
- `review_by` is 90 days after `last_verified`. Set `last_verified` to today only when you checked the note against code in this session.
- `agent_hint` is what the session index shows, so make it specific: "Load for X, Y and Z", not "Notes about X".

## Tags (frontmatter list, nothing else)
Allowed: the type word (`architecture`, `database`, `decision`, `runbook`, `component`, `module`, `convention`, `tasks`), one `side/` tag (`side/cms`, `side/unity`, `side/shared`), and a `status/` tag only when it helps (`status/live`, `status/planned`). Do not invent tags. If one is truly needed, add it to `Conventions.md` first.

## Links
- Link to the note that owns a fact with `[[Exact Note Name]]` or `[[Exact Note Name|short label]]`. Never restate the fact.
- Every new note links **out** to at least its parent (for example `[[Architecture Overview]]`) and **in**: add one line to the parent or the closest related note pointing at the new note.
- Links must resolve to a real file name. A broken link is an error.
- End with one line: `Related: [[A]], [[B]]` (three at most).

## Shape of the body
- Short. A typical note is 30 to 80 lines. Over about 24,000 characters you must split it.
- Start with one sentence saying what this is for. Use tables for lists of facts, numbered steps for flows, bullets for rules.
- Headings are plain words (`Purpose`, `Flow`, `Rules`, `Open questions`). No arrows, no diagrams made of symbols; use a table or numbered steps.
- Mark unknowns under `Open questions` instead of guessing.
- Plain ASCII only: hyphens `-` or `--`, straight quotes, three dots as words. No em dashes, en dashes, curly quotes, ellipsis characters or arrows.

## After writing
1. Run `node "$TIFOXR_VAULT/tools/build-index.js"` and then `node "$TIFOXR_VAULT/tools/check-vault.js"`. Fix every error before reporting.
2. Report which files you created or changed. Do not commit unless the user asks.

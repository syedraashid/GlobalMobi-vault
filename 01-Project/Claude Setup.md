---
title: "Claude Setup"
category: project
agent_hint: "Load when asked how Claude is wired to the vault: plugin, hooks, skills, what loads when."
index_tier: lazy
status: live
review_by: 2027-01-12
type: runbook
owner: syed
last_verified: 2026-10-14
tags: [runbook, claude]
---

# Claude Setup

How Claude Code is wired to this vault. The vault repo is also a **Claude Code plugin** named `tifoxr`, so installing the plugin gives Claude everything below on any machine.

## What a plugin is here
A plugin is a folder Claude Code installs once and then loads in every session. This vault repo has `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` at its root, so the repo is both the knowledge vault and the plugin. Install on a new machine with `node tools/setup.js` ([[New Machine Setup]]).

## What is in it
| Piece | Where | When it is used |
|---|---|---|
| Session index hook | `hooks/scripts/inject-index.js` | Start of every session **inside TifoXR work only**. Prints the small index in `vault-index.md` (about 1,800 characters) plus a one-line database freshness note. |
| Guard hook | `hooks/scripts/guard.js` | Before every Bash or PowerShell command. Asks you before the database refresh, denies an unfiltered `dotnet test` in TifoXR work, and denies commands that print or copy the database access file. |
| `db-context` skill | `skills/db-context/` | Claude picks it up **only when a task touches the database**. It loads just the domain notes needed and asks before any refresh. |
| `sql-migration` skill | `skills/sql-migration/` | When Claude writes or changes SQL ([[ADR-0002 SQL Changes Are Safe Migration Files]]). |
| `vault` skill | `skills/vault/` | **Only when you invoke it** (`/tifoxr:vault`): loads the notes for the repo you are in. |
| `vault-notes` skill | `skills/vault-notes/` | **When Claude writes or edits a vault note.** Folder, properties, tags, links and size rules, so notes pass `check-vault`. |
| `vault-update` skill | `skills/vault-update/` | **Only when you invoke it** (`/tifoxr:vault-update`) after development. Proposes the lasting facts to save (files, tags, links), waits for your yes, then writes and checks. Never commits. |
| `refresh-db` skill | `skills/refresh-db/` | **Only when you invoke it** (`/tifoxr:refresh-db`). Marked so Claude cannot start it by itself, and the guard hook still asks for approval. |
| Tools | `tools/` | `refresh-db.js`, `build-index.js`, `check-vault.js`, `setup.js` |

## What loads when (why Claude is not flooded)
1. **Session start (TifoXR folders only):** the index. Four notes get a "when to read" line; the rest are listed by title. The database appears as one line with its as-of date. About 450 tokens.
2. **During the task:** Claude reads a note only when the index or a skill says the task needs it.
3. **Database work:** the `db-context` skill loads `DB Current State`, then only the domain notes and procedure files the task needs. Procedure SQL files are never loaded in bulk.
4. **Refresh:** never automatic. You invoke it, and you approve the prompt.

Notes carry `agent_hint` and `index_tier` (eager or lazy) in their properties. Only a few notes may be eager (limit 8), so the index stays small however many notes exist.

## Rules Claude follows
- **Ask before refreshing.** Enforced by the guard hook, not only by instruction.
- Never run the complete API test suite ([[ADR-0001 Never Run The Full API Test Suite]]). Enforced by the guard hook in TifoXR work.
- Every SQL change is a migration file written with the `sql-migration` skill ([[ADR-0002 SQL Changes Are Safe Migration Files]]).
- Never open or print the database access file ([[Access Setup]]). Enforced by the guard hook.
- The vault can be wrong. Notes list what is not confirmed, and Claude checks the code first.

## Where things live
| Thing | Location |
|---|---|
| Plugin, hooks, skills, tools, notes | This vault repo |
| Vault location on a machine | The `TIFOXR_VAULT` setting (set by `tools/setup.js`) |
| Database access file | `~/.tifoxr/access.env`, or the path in `TIFOXR_ACCESS_ENV` (an older `C:\TifoXR\tifoxr-access.env` is still honoured). Never in git. |
| Backend rules | `CLAUDE.md` in the backend repo (untracked unless added by pull request) |
| `migration/` | Backend repo root, git-ignored through `.git/info/exclude` |

## Changing this setup
- Edit hooks, skills, tools or notes in this repo. After editing a note's properties, run `node tools/build-index.js` and `node tools/check-vault.js` (the git pre-commit hook runs both).
- To publish a change to teammates: commit and push the vault, then they run `claude plugin update tifoxr`.
- Bump `version` in `.claude-plugin/plugin.json` and the marketplace entry when you release a change.

## Known limits
- Installed plugins run from a cached copy. Hooks and skills therefore read the cache, while the database refresh writes to your live clone through `TIFOXR_VAULT`. The refresh refuses to run from the cache without it.
- DB notes reach teammates only after you commit and push and they update the plugin, or they run their own refresh.
- The hooks need `node` on the PATH.
- Older copies on this machine (commands `vault.md` and `refresh-db.md` in `~/.claude/commands`, the `sql-migration` stub in `~/.claude/skills`, and the `permissions.ask` rule in user settings) can be deleted once the plugin is confirmed working in a fresh session.

## Not done yet
- Tracked `CLAUDE.md` and `.claude/settings.json` in the backend and CMS repos, so teammates are prompted to install the plugin. A template is in `tools/templates/`; it needs a pull request and the vault repo's git URL.
- Hosting the vault repo on a git remote.

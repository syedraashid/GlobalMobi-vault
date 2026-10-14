---
title: "New Machine Setup"
category: project
agent_hint: "Load when setting up TifoXR on a new machine or onboarding someone."
index_tier: lazy
status: live
review_by: 2027-01-12
type: runbook
owner: syed
last_verified: 2026-10-14
tags: [runbook, onboarding]
---

# New Machine Setup

Everything needed to make Claude work well with TifoXR on a new machine.

## Before you start
- **Node 18 or newer**, **git** and **Claude Code** installed.
- **sqlcmd** (SQL Server command line tools), only needed for the database refresh.
- The vault repo cloned somewhere. The backend and CMS repos cloned anywhere (next to the vault is easiest).

## Steps
1. In the vault folder run: `node tools/setup.js`
   - add `--backend <path>` and `--cms <path>` if those repos are not next to the vault
   - add `--dry-run` first if you want to see what it will do
2. Open the access file it created (it prints the path) and fill in `SQL_DEV_SERVER`, `SQL_DEV_DATABASE`, `SQL_DEV_USER` (your Entra email) and `SQL_DEV_PASSWORD`. Leave the rest empty unless you need it.
3. Make sure your IP is allowed on the Azure SQL firewall and your account can read the dev database.
4. Open a **new terminal** (so `TIFOXR_VAULT` is picked up) and start Claude Code inside a TifoXR repo. You should see "TifoXR knowledge vault" and the short index at the start of the session.
5. Optional: run the refresh skill with `--check` (`/tifoxr:refresh-db --check`) and approve the prompt, to confirm the connection works.

## What the script does
It checks the tools, sets `TIFOXR_VAULT`, creates the access file (empty, owner-only), creates and locally ignores `migration/` in the backend clone, adds a `CLAUDE.md` to the backend and CMS clones if they have none, turns on the vault's pre-commit check, installs the plugin, and runs the self-tests. It never overwrites an existing file. Details: [[Claude Setup]].

## Without the plugin
If you cannot install plugins, `/vault` and the other skills are not available. Claude can still read the notes directly, starting at `vault-index.md` in the vault folder.

## Not covered by the script
- Filling in the database values, the firewall, and Entra access (steps 2 and 3).
- Making the backend and CMS `CLAUDE.md` files tracked in git, which needs a pull request.

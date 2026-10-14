---
title: "Access Setup"
category: project
agent_hint: "Load when setting up database or Azure access, the env file keys, or Entra sign-in."
index_tier: lazy
review_by: 2027-01-12
type: runbook
status: live
owner: syed
last_verified: 2026-10-14
tags: [runbook, security]
---

# Access Setup

How Claude Code gets read-only access to the databases and Azure. **This note holds names only, never values.**

## Where the secrets live
The access file lives outside this vault and outside both code repos. The refresh looks for it in this order: `TIFOXR_ACCESS_ENV`, `ACCESS_ENV_FILE`, an older `C:\TifoXR\tifoxr-access.env` if it exists, then `~/.tifoxr/access.env`. `node tools/setup.js` creates an empty one from a template. Windows permissions allow only the owner's user account. It is not in git. Each person who wants Claude access makes their own copy with their own credentials.

## Keys (names only)
| Group | Keys |
|---|---|
| SQL dev (used by `/refresh-db`) | `SQL_DEV_SERVER`, `SQL_DEV_DATABASE`, `SQL_DEV_USER` (Entra email), `SQL_DEV_PASSWORD`, optional `SQL_DEV_TRUST_CERT`, `SQLCMD_PATH` |
| Azure | `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_SUBSCRIPTION_ID_DEV`, `AZURE_SUBSCRIPTION_ID_PROD` |
| Blob | `BLOB_DEV_READONLY`, `BLOB_PROD_READONLY` |
| Azure DevOps | `AZDO_ORG_URL`, `AZDO_PAT` |

## What each credential must be
- **SQL (dev):** the Entra account must exist in the dev database and be able to read definitions (`VIEW DEFINITION`). It is currently expected to be a personal account, which may be able to write; the refresh sends only SELECT queries and warns if the login can change data. A dedicated read-only dev user (`db_datareader` plus `VIEW DEFINITION`, no `db_datawriter` or `db_owner`) is the safer choice later, because anything holding the credential could run other statements.
- **Prod SQL:** out of scope for now. There is no prod command.
- **Azure:** a service principal with the **Reader** role at subscription or resource group level.
- **Blob:** a SAS token with read and list only, or a Reader-style role. Not an account key.
- **Azure DevOps:** a PAT with read-only scopes. Set a short expiry.

## How Claude uses it
Claude loads the file into environment variables for a single command and does not print the values. Claude should not open the file to display its contents. Claude must ask the user before running `/refresh-db`, and a `permissions.ask` rule in `~/.claude/settings.json` makes Claude Code prompt for every run of the refresh script. Prod access is for investigating live issues, not for changes.

## Rotating
Change values in the file. Revoke old credentials at the source. If a value ever lands in a note, a commit or a chat, treat it as leaked and rotate it.

## Entra sign-in for dev
The dev database uses **Microsoft Entra** sign-in (users created `FROM EXTERNAL PROVIDER`). `/refresh-db` signs in with `sqlcmd -G`, your Entra email and password, the same way as `sqlcmd -S <server>.database.windows.net -d <database> -G -U <email> -P <password>`. The password reaches `sqlcmd` through an environment variable, not the command line.
- This password sign-in **does not work if your account requires MFA**.
- The Azure SQL firewall must allow your IP address.
- If `--check` fails with a login error, ask whoever administers the server whether your account exists in the database.
See [[DB Refresh Command]] and [[Database]].

## File permissions
Some editors recreate the file and reset its permissions, which can let other users on the machine read it. The refresh command warns when that happens. To lock it again: `icacls "C:\TifoXR\tifoxr-access.env" /inheritance:r /grant:r "%USERNAME%:(F)"`.

## Likely extra step
Azure SQL firewalls often need your IP allowed before a login can connect. This is an Azure-side change someone with rights must make.

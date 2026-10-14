---
title: "Unity Contract"
category: architecture
agent_hint: "Load for what the Unity app reads and calls from the backend."
index_tier: lazy
review_by: 2027-01-12
type: component
status: live
side: unity
owner: syed
last_verified: 2026-10-14
tags: [component, side/unity]
---

# Unity Contract

The Unity WebGL app is out of scope for this vault. This note covers only what it **reads and calls**, taken from the backend code. Statements about how the client behaves come from backend comments, not from the Unity repo. Part of [[Architecture Overview]].

## What Unity reads: space content from Blob
- `space/{spaceId}/version.json`, then the versioned files it lists, for booths, items, teleport, ads, events, charities, hosting, recognition, packages, game announcements, localizations and similar. Module list and layout: [[Dynamic Pull Flow]].
- Global lookups (currencies, CCU settings, games) under `lookups/`.
- `config.json` is bundled in the Unity build. Per the backend comments, Unity takes its CDN base URL from it. It is not fetched from the API.
- If Blob or the CDN fails, the API serves the same shapes live from the database at `tifoxr-content/...`. These require the login token.

## What Unity calls directly
| Area | Calls | Note |
|---|---|---|
| Login | `POST api/space/{spaceId}/auth/guest-login`, `microsoft-login`, `google-login`, session calls | [[Authentication]] |
| User data | `api/user/{userId}`, inventory `api/space/{spaceId}/users/{userId}/...` | Direct, user-specific |
| Orders and payments | `api/space/{spaceId}/orders/...` | Direct. No queue, no webhooks. [[Push Flows]] |
| Friends | `api/spaces/{spaceId}/friends`, `friend-requests`, `users/search`, notifications | Reads direct; changes go through the queue |
| Free trial | `api/space/{spaceId}/free-trials`, `.../items/{itemId}/free-trial`, `.../packages/{packageId}/free-trial` | |
| Game announcements | `GET api/space/{spaceId}/announcements/active`, `api/space/{spaceId}/games/{gameId}/announcements` | |
| Leaderboard and stats | `api/space/{spaceId}/games/{gameId}/leaderboard`, `api/space/{spaceId}/games/stats` | |

## What Unity sends without waiting (Event Hub)
- `POST api/metrics/events`: metric event batches. The API answers 202.
- `POST api/space/{spaceId}/games/{gameId}/sessions/batch`: completed game sessions. The API answers 202.

## Real-time
Hubs `/hubs/friend`, `/hubs/sync-result` and `/hubs/game`, authenticated with `?access_token=`. See [[Push Flows]].

## Feature-specific contracts
Free trial, game announcement and penalty shootout integration details are not written up here yet. The original guides remain in the `docs/` folder of your local CMS checkout (an untracked folder, not part of the repo or this vault).

## To do
- Complete Unity-facing endpoint list (Phase 3)
- Token lifetimes and guest flow details (not in the code read so far)
- Exact `version.json` field names as serialized (the record is `SchemaVersion`, `GeneratedAt`, `Modules` with `Version` and `Url`)

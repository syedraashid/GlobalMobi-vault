---
title: "Dynamic Pull Flow"
category: architecture
agent_hint: "Load for content publishing to Blob, version.json, the ContentWrite queue and the daily jobs."
index_tier: lazy
review_by: 2027-01-12
type: architecture
status: live
side: shared
owner: syed
last_verified: 2026-10-14
tags: [architecture, side/shared]
---

# Dynamic Pull Flow

How space-specific content gets from the CMS to Unity through Azure Blob. Read from the code; part of [[Architecture Overview]].

## What is published
Space content is published as **versioned JSON files**. The module keys the publisher can build (`ContentPublishService`) are:

| Space modules | Global modules (space id 0) |
|---|---|
| booths, charities, hosting, item, teleport, recognition, packages, ads, event, game-announcement, localizations, supported-language, payment-gateway, boothcomment, portal, discount | currencies, ccu-settings, games |

Portal data is embedded in the **booths** file and discount and free-trial eligibility data are embedded in the **item** file, so approving a portal rebuilds `booths` and approving a discount rebuilds `item` (`ContentPublishRules`). Advertiser, campaign and localization approvals do not rebuild through that rule table.

## Blob layout
Container: `BlobStorage:ContainerName`, default `tifoxr-content`.

| Path | Meaning |
|---|---|
| `space/{spaceId}/version.json` | Manifest for one space: schema version, generated time, and for each module its version and a root-relative url |
| `space/{spaceId}/content/{module}.v{n}.json` | One versioned content file |
| `lookups/content/{module}.v{n}.json` | Versioned global lookup file |
| `space/{spaceId}/standard/{module}.json` and `lookups/standard/` | Copy of the oldest retained version, made by StandardPublishJob |

When version N of a file is written, version N-3 is deleted (`ContentQueueFunction`). A global module change is written once under `lookups/` and then the version.json of every active space is updated.

URLs in `version.json` are root-relative. Per the code comments, Unity prepends a CDN base URL from its own `config.json`, so the same files work in every environment.

## The publish pipeline
1. **Trigger.** A content change is approved (`ContentApprovalService`), or a CMS or admin action publishes directly (booth comments, currencies, localization, payment gateway config, games, CCU settings, admin config), or a daily job runs.
2. **Version bump.** `ContentVersionService` calls the stored procedure `sp_BumpContentVersion`, which atomically increments the version for that space and module in `content_version` and returns the new number.
3. **Build the JSON.** `ContentPublishService` reads the approved data for that space and module from SQL and serializes it in the shape Unity expects.
4. **Queue.** The API sends a `ContentWriteQueueMessage` (space, module, JSON, new version, idempotency key `{module}:{spaceId}:{version}`) to the **ContentWrite** Service Bus queue. The session id is the space id, so writes for one space are processed one at a time and `version.json` cannot be overwritten by a race.
5. **Write.** `ContentQueueFunction` ([[EventFunctions]]) writes the content file, deletes the old one, and rebuilds `version.json`. With the Redis cache provider, a Redis hash `content:versions:{spaceId}` holds the running versions. With the in-memory provider the function reads `content_version` from SQL instead.
6. **Unity pulls.** Unity reads `version.json`, compares versions, and fetches the files it needs.

## Failover through the API
`ContentDeliveryController` (`GET tifoxr-content/space/{spaceId}/version.json` and `.../content/{module}.v{n}.json`) and `ContentDeliveryLookupsController` (`tifoxr-content/lookups/content/...`) return the **same shapes generated live from the database**. The code calls them the "Front Door failover origin". They require a login token, because Unity sends its token on every request.

## Daily and periodic jobs (in the API process)
| Job | When | What |
|---|---|---|
| EventScheduleDailyJob | 00:00 Eastern | Republishes the `event` file for every space with events, to catch status changes caused only by the date rolling over |
| GameAnnouncementScheduleDailyJob | 00:05 Eastern | Same for `game-announcement` |
| AdScheduleDailyJob | 00:10 Eastern | Republishes `ads` for every space with active ad placements, so the file is the schedule for the new day |
| StandardPublishJob | Every `StandardPublish:IntervalDays` days (default 2) | Copies the oldest retained version of each module to `standard/`. Manual triggers: `POST api/space/{id}/cms/content/publish-standard` and `POST api/cms/content/publish-standard-lookups`. |

## Known behaviour
- If the queue publish fails after an approval, the approval stays saved and the blob stays out of date until the next publish (logged as an error in `ContentApprovalService`).
- Ad approvals publish the `ads` file through a separate path (`AdBlobPublishService`), and event changes through `EventBlobPublishService`.

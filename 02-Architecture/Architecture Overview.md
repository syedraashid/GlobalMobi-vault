---
title: "Architecture Overview"
category: architecture
agent_hint: "Load for any design, data-flow, hosting or environment question: the six data paths and how the parts talk."
index_tier: eager
review_by: 2027-01-12
type: architecture
status: live
side: shared
owner: syed
last_verified: 2026-10-14
tags: [architecture, side/shared]
---

# Architecture Overview

Built from the code on `develop` (backend commit c3c5f17, CMS commit e4c93a4) and from syed's description. Every statement below was read in code unless it is listed under **Not confirmed**. The Unity client is not in these repos, so anything said about what Unity does comes from comments in the backend.

## The parts
| Part | What it is | Detail |
|---|---|---|
| Unity WebGL app | Public player app | [[Unity Contract]] |
| CMS | Private React app for restricted, role-based staff. Deployed as an Azure Static Web App. | [[CMS Frontend]] |
| Backend API | One ASP.NET Core 10 app serving both Unity and the CMS | [[Backend API]] |
| EventFunctions | Separate Azure Functions app that consumes queue and Event Hub messages | [[EventFunctions]] |
| Data and services | Azure SQL (raw ADO.NET and stored procedures), Redis, Azure Blob, Service Bus, Event Hubs, Azure SignalR | below |

## How data moves: six paths
| # | Path | Direction | Mechanism | Note |
|---|---|---|---|---|
| 1 | **Space content** (booths, items, teleport, ads, events and similar) | Unity reads | Versioned JSON files in Azure Blob, found through `version.json`. The API serves the same shape as a failover. | [[Dynamic Pull Flow]] |
| 2 | **User-specific data** (profile, inventory, orders, friend lists) | Unity reads and writes | Direct API calls. Every controller requires a login token. | [[Backend API]] |
| 3 | **Payments** | Unity writes | Direct API calls (create order, payment intent, checkout, refund, verify, reconcile). No queue and no webhook code. | [[Push Flows]] |
| 4 | **Friend actions** (send, accept, decline, cancel, remove) | Unity writes | Service Bus queue, then FriendRequestQueueFunction. Friend lists are read directly. | [[Push Flows]] |
| 5 | **Metric events and game sessions** | Unity writes, no waiting | API accepts the batch, publishes to Event Hub, and answers 202. Functions write to SQL. | [[Push Flows]] |
| 6 | **CMS edits** | CMS writes | Direct API calls with a role-based token. Content changes go through approval, and approved changes are published to Blob. | [[Approval Workflow]], [[Dynamic Pull Flow]] |

Logins for both apps are in [[Authentication]].

## Publishing in one paragraph
When content is approved, the API bumps a version number in SQL, builds the approved JSON from the database, and sends it to the **ContentWrite** queue. EventFunctions writes `space/{spaceId}/content/{module}.v{n}.json` and rebuilds `space/{spaceId}/version.json`. Unity reads `version.json`, then the files it lists. Three jobs in the API also publish daily on their own (ads, events, game announcements). Details: [[Dynamic Pull Flow]].

## Runtime pieces
- **SQL:** all data access is raw ADO.NET through an `IDbProvider`, calling stored procedures (471 of them; see [[DB Current State]]). `AppDbContext` is registered but declares no tables and business code does not use it, so EF Core is not the data layer.
- **Redis or in-memory:** chosen by the `Caching:Provider` setting (Redis is the default). Used for caching, the idempotency store for the metrics endpoint, and the running content version state used by ContentQueueFunction.
- **Blob:** one container, named by `BlobStorage:ContainerName` (default `tifoxr-content`). Authenticates by connection string locally or by managed identity in Azure.
- **Service Bus:** queues for ContentWrite and FriendRequest. Names come from configuration.
- **Event Hubs:** destinations Metrics and GameSessionCompleted. Names come from configuration.
- **Azure SignalR:** used when `Azure:SignalR:ConnectionString` is configured; otherwise the hubs are self-hosted by the API. Four hubs: `/hubs/content-approval`, `/hubs/friend`, `/hubs/sync-result`, `/hubs/game`.
- **Background jobs inside the API process:** StandardPublishJob, EventScheduleDailyJob, GameAnnouncementScheduleDailyJob, AdScheduleDailyJob. See [[Dynamic Pull Flow]].

## Hosting and environments
| Branch | Env | Backend | Functions | CMS |
|---|---|---|---|---|
| develop | dev | App Service `TifoXRCoreWebAPI` | `TifoXRCoreWebAPI-EventFunctions` | Static Web App (dev stage) |
| test | test | `TifoXRCoreWebAPI-Test` | `...-EventFunctions-Test` | Static Web App (test stage) |
| master (backend) or main (CMS) | prod | `TifoXRCoreWebAPI-Prod-new` | `...-EventFunctions-Prod` | Static Web App (prod stage) |

The CMS pipeline runs Jest tests first and rolls the dev and test deploys back when the smoke test fails. The backend pipeline builds and deploys without running tests.

## Not confirmed
- Whether Azure Front Door and a CDN are actually configured in each environment. The code says Unity reads content through "Front Door" and prepends a CDN base URL from its own `config.json`, but those resources are not in these repos.
- How Unity behaves. Statements about the client come from backend comments, for example that Unity sends its token on every request including content fetches.
- The purpose of StandardPublishJob's copied `standard/` files. The code copies them but does not say what reads them.
- Which CMS edits skip approval. Only the approval path was traced.
- The Unity repo, which is out of scope.

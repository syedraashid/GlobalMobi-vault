---
title: "Backend API"
category: architecture
agent_hint: "Load when working in the backend: layout, routes, jobs, build and deploy."
index_tier: lazy
review_by: 2027-01-12
type: component
status: live
side: shared
owner: syed
last_verified: 2026-10-14
tags: [component, side/shared]
---

# Backend API

One ASP.NET Core Web API serving both the Unity app and the CMS. Verified against `develop` commit c3c5f17 (PR 773). Part of [[Architecture Overview]].

## Facts
- Framework: **net10.0** (upgraded from .NET 8 in PR 773). CI uses SDK 10.0.401.
- Root namespace: `GMS.TifoXRCoreWebAPI.*`
- Repo: Azure DevOps `globalmobisoft/TifoXRCoreWebAPI`. Local: `C:\TifoXR\TifoXRCoreWebAPI`.
- Solution projects: main API, `Tests`, `EventFunctions` ([[EventFunctions]]), `EventFunctions.Tests`.
- Local run: `dotnet run --project TifoXRCoreWebAPI.csproj`. Profiles use `http://localhost:5211` and `https://localhost:7017`. Swagger at `/swagger`.
- **Never run the full test suite** ([[ADR-0001 Never Run The Full API Test Suite]]).

## What runs inside the API process
- Controllers (about 90 across the folders below), all requiring a login token except the login endpoints ([[Authentication]]).
- Four SignalR hubs: `/hubs/content-approval`, `/hubs/friend`, `/hubs/sync-result`, `/hubs/game` ([[Push Flows]]).
- Four background jobs: StandardPublishJob, EventScheduleDailyJob, GameAnnouncementScheduleDailyJob, AdScheduleDailyJob ([[Dynamic Pull Flow]]).
- Global exception middleware, CORS policy `TifoXRCorsPolicy`, Serilog request logging, Application Insights and OpenTelemetry.

## Route families
| Pattern | Used by | Examples |
|---|---|---|
| `api/space/{spaceId}/...` | Unity and CMS | booths, items, orders, games, events, ads, leaderboard, approvals |
| `api/space/{spaceId}/cms/...` | CMS | `Cms*Controller` content endpoints (17 controllers) |
| `api/spaces/{spaceId}/...` | Unity | friends, friend requests, notifications |
| `api/admin/...` | CMS | roles, members, entities, spaces, analytics, config, CCU settings, global admin, accountant |
| `api/auth/cms/login`, `api/space/{id}/auth/...` | CMS, Unity | logins ([[Authentication]]) |
| `api/user`, `api/games`, `api/metrics` | Unity | users, games, metric events |
| `api/currencies`, `api/lookups` and similar | Both, not classified | shared reference data |
| `tifoxr-content/...` | Unity (failover) | content and `version.json` served live from SQL |

A full endpoint catalog is still to do (Phase 3).

## Code layout
Domain folders: Admin, Application, Auth, BlobUpload, Caching, Cms, ContentApproval, Controllers, Data, Discounts, FreeTrial, Friend, Game, GameAnnouncement, HealthAndSafety, Inventory, Item, Middleware, Models, Package, Repositories, Services, Shop, Sync, User, Utilities.
- `Application/Messaging` holds the publishers (Service Bus, Event Hub, content) and the version manifest.
- `Application/Jobs` holds the background jobs. `Application/PaymentGateways` holds Stripe, PayPal and crypto.
- **Data access is raw ADO.NET plus stored procedures**, through `IDbProvider` (`Utilities/Infrastructure`). Repositories open a connection, run a stored procedure and hand-map the reader. `Data/AppDbContext.cs` is registered in DI but declares no `DbSet`s and is not used by business code, so EF Core is not the real data layer. Repositories are auto-registered by naming convention (`IFooRepository` to `FooRepository`). See [[DB Current State]].

## Packages
EF Core 10 (present but unused as the data layer), Stripe.net, PayPalServerSDK, Thirdweb, Google.Apis.Auth, Azure Service Bus, Event Hubs, Azure SignalR, Azure Blob, StackExchange.Redis, RulesEngine, Serilog, Application Insights, OpenTelemetry. A `MySqlConnector` package is present; MySQL use is not confirmed.

## Build, test, deploy
- Pipeline `azure-pipelines.yml` triggers on develop, test, master. It builds and deploys. It does **not run `dotnet test`**.
- Per-environment settings files are downloaded from Azure DevOps **Secure Files**. Environments and app names are in [[Architecture Overview]].
- Dev also deploys the same package to a Linux App Service (`TifoXRCoreWebAPI-Linux-Dev`) that is "under evaluation".

## Configuration (names only, never values)
`appsettings.json` is git-ignored. Key groups: `ConnectionStrings`, `Jwt`, `Caching`, `Redis`, `BlobStorage`, `Azure:SignalR`, `ServiceBus`, `EventHub`, `StandardPublish`, `PayPal`, `Stripe`, `Google` and Microsoft auth options.

## SQL changes
All SQL changes are migration files: [[ADR-0002 SQL Changes Are Safe Migration Files]].

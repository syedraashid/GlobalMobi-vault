---
title: "EventFunctions"
category: architecture
agent_hint: "Load for the Azure Functions app: queue and Event Hub consumers."
index_tier: lazy
review_by: 2027-01-12
type: component
status: live
side: shared
owner: syed
last_verified: 2026-10-14
tags: [component, side/shared]
---

# EventFunctions

Azure Functions v4 (isolated worker, net10.0) deployed as a **separate** Azure resource from the API. Project: `TifoXRCoreWebAPI.EventFunctions` in the backend repo. It references the main API project to reuse models, repositories and services. Part of [[Architecture Overview]].

## Functions on develop
| Function | Trigger | What it does |
|---|---|---|
| ContentQueueFunction (Sessioned and Plain) | Service Bus queue **ContentWrite** | Writes the approved content JSON to Blob as a versioned file, deletes the old version, rebuilds `version.json`. Session id is the space id, so one space is processed at a time. Details: [[Dynamic Pull Flow]]. |
| FriendRequestQueueFunction (Sessioned and Plain) | Service Bus queue **FriendRequest** | Handles send, accept, decline, cancel and remove. Sends `SyncSuccess` or `SyncError` to the acting user through `SyncResultHub`. See [[Push Flows]]. |
| GameSessionBatchFunction | Event Hub **GameSessionCompleted** | One stored-procedure call per batch of game sessions. Write-only. |
| MetricsFunction | Event Hub **Metrics** | Prepares the batch, then one stored-procedure call per batch. Retries with exponential backoff on transient failures. |
| PingFunction | HTTP `/api/ping` | Pipeline health check after deploy |

Queue and hub names come from configuration (`ServiceBus:Destinations:*`, `EventHub:Destinations:*`), not hard-coded.

## Shared code
Message pipelines live in `EventFunctions/Messaging` (`QueueSessionMessagePipeline`, `EventHubBatchMessagePipeline`, `SyncQueueNotify`). The DI helpers it reuses from the API are in `Application/DependencyInjection/QueueConsumerInfrastructureExtensions.cs`. Hub notifications from the functions go through the Azure SignalR Management SDK (`Application/Notifications`).

## Environments
dev: TifoXRCoreWebAPI-EventFunctions. test: ...-EventFunctions-Test. prod: ...-EventFunctions-Prod. All Flex Consumption, Linux, per the pipeline comments.

## Payment and order queues: removed
Earlier code (and the old backend `CLAUDE.md`) had Payment and Order queue consumers. They were **removed**; payments and orders are direct API calls (confirmed by syed). No payment or order queue code remains on `develop`.

## Retired
`TifoXRCoreWebAPI.SyncWorker` is not on develop. It was an earlier predecessor to this app. A few comments in the code still mention it.

---
title: "Push Flows"
category: architecture
agent_hint: "Load for payments, the friend queue, metric events, game sessions and the SignalR hubs."
index_tier: lazy
review_by: 2027-01-12
type: architecture
status: live
side: unity
owner: syed
last_verified: 2026-10-14
tags: [architecture, side/unity]
---

# Push Flows

How data Unity sends reaches the database, and how results come back. Read from the code; part of [[Architecture Overview]].

## Payments: direct API calls
`OrderController` (`api/space/{spaceId}/orders`) handles the whole flow in the request itself:
- create the order, then create a payment intent or start checkout
- Stripe and PayPal return pages (`GET {orderId}/payments/stripe/return` and `.../paypal/return`)
- crypto: `GET .../crypto/prepared` and `POST .../crypto/report-tx`
- refunds (`POST {orderId}/charges/{chargeId}/refunds`), `GET {orderId}/verify`, `POST {orderId}/reconcile`
- deposits: `DepositController` and, for global admins and accountants, `GlobalDepositController` and `GlobalTransactionsController`

Facts:
- There is **no webhook code** anywhere in the backend.
- Stripe and PayPal credentials come from the database per space (`payment_gateway_config`, secret fields encrypted with AES-GCM) and gateway objects are built per request by `PaymentGatewayFactory`.
- The Payment and Order queue consumers that older code had were removed (confirmed by syed). Payments are plain API calls.
- Per-space payment gateway settings can also be published to Blob as the `payment-gateway` module ([[Dynamic Pull Flow]]).

## Friend actions: Service Bus queue
`FriendController` (`api/spaces/{spaceId}/...`):
- **Reads** are direct: `GET friends`, `GET friend-requests/incoming`, `GET friend-requests/outgoing`, `GET users/search`.
- **Mutations** (send, accept, decline, cancel, remove) are published to Service Bus through `SyncQueuePublisher`. The queue is picked by the message's `RequestType`, and `FriendRequest` is the only value that exists today.
- `FriendRequestQueueFunction` ([[EventFunctions]]) consumes the queue (`tifoxr-friendrequest-queue` per its comment) and handles all five actions.
- Real-time results: `FriendService` pushes the matching event to the other user over `FriendHub`, and the function sends the acting user a `SyncSuccess` or `SyncError` event through `SyncResultHub` (via the Azure SignalR Management SDK).

## Metric events: Event Hub
`POST api/metrics/events` (`MetricEventsController`):
1. The batch passes `IIdempotencyGate` (Redis or in-memory store, set by `Caching:Provider`).
2. The API publishes it to the Event Hub destination **Metrics** and returns **202 Accepted**. It never waits for the database.
3. `MetricsFunction` reads the batch, prepares it, and makes **one stored-procedure call per batch**. Per-section savepoints in the procedure isolate failures between event types.

## Game sessions: Event Hub
`POST api/space/{spaceId}/games/{gameId}/sessions/batch` (`GameSessionController`):
1. The API publishes the batch to the Event Hub destination **GameSessionCompleted** and returns **202 Accepted**.
2. `GameSessionBatchFunction` makes one stored-procedure call for the whole batch. It is **write-only**: it sends no push back to the client.
3. A retried batch is not guaranteed idempotent, because rows get database-generated ids. The procedure's overlap guard on user, game and time range catches an exact resend.

## SignalR hubs
Hub connections pass the login token as `?access_token=` because WebGL WebSockets cannot set headers. The hubs are mapped in `Program.cs`:

| Hub | Path | Used for |
|---|---|---|
| ContentApprovalHub | `/hubs/content-approval` | CMS approval notifications ([[Approval Workflow]]) |
| FriendHub | `/hubs/friend` | Friend events to Unity |
| SyncResultHub | `/hubs/sync-result` | Outcome of queued operations. The only queued operation type today is the friend request. |
| GameHub | `/hubs/game` | Score updates. The current batch session function does not push to it. |

## Not confirmed
- How Unity subscribes to these hubs.
- Whether anything still sends through GameHub. The notifier classes exist, but the batch flow is documented as write-only.

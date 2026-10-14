---
title: "Authentication"
category: architecture
agent_hint: "Load for CMS or Unity login, JWT tokens, roles and policies."
index_tier: lazy
review_by: 2027-01-12
type: architecture
status: live
side: shared
owner: syed
last_verified: 2026-10-14
tags: [architecture, security, side/shared]
---

# Authentication

How the CMS and Unity sign in, and how the API checks tokens. Read from the code; part of [[Architecture Overview]]. No secrets or key values are recorded here.

## One token type for the API
The API has a single authentication scheme: **JWT bearer**, validated with one handler. The issuer, audience and signing key come from the `Jwt` configuration section, and the lifetime is validated. Two services issue tokens with those same settings: `JwtService` for Unity players and `CmsJwtService` for CMS staff. Every controller requires a login (`[Authorize]`) except the login endpoints themselves. Both apps send `Authorization: Bearer <token>`.

| Token | Issued by | Claims |
|---|---|---|
| Player | `JwtService` | user id, username, login type, user type, spaces |
| CMS | `CmsJwtService` | user id, email, username, login type `cms`, user type `cms_member`, spaces, system role, entity id. Lifetime `ExpirationHours`, 24 hours when unset. |

SignalR hubs accept the token as `?access_token=` on the query string, because WebGL WebSockets cannot set headers.

## CMS sign-in (staff)
1. The CMS signs the person in with **MSAL** against a Microsoft Entra External ID (CIAM) authority, then gets a CIAM access token.
2. It calls `POST api/auth/cms/login` with that token (`AdminAuthController`, `AdminCmsAuthService`).
3. The API validates the CIAM token, reads the object id and email, and looks up the CMS user by that object id. A first login by email must match an existing user or an **invitation** (`pending_invitation`); per the code comments an invitation is what proves someone is allowed in.
4. The API returns its own CMS JWT, plus the user's system role and spaces.
5. The CMS stores the token and profile in `localStorage` and attaches the token to every request. On a 401 it tries once to exchange again silently through MSAL, and otherwise forces a new login.

## Unity sign-in (players)
`AuthController` (`api/space/{spaceId}/auth/...`):

| Endpoint | Purpose |
|---|---|
| `POST guest-login` | Guest player |
| `POST microsoft-login` | Validates a Microsoft token (object id and tenant id), and links the identity to an existing user with the same email |
| `POST google-login` | Validates a Google token. The expected Google client id is looked up **per space** from the database. |
| `POST session`, `.../{sessionId}/active`, `.../inactive`, `.../end` | Player session tracking |
| `GET users/username/{username}/exists` | Username check |

The Google and Microsoft validators and the JWT issuer are in `Auth/Services`.

## Roles and policies
- Claims include a **system role**: `global_admin`, `entity_admin` or `gms_accountant`. Space roles are listed in [[Project Overview]].
- `PolicyNames.GlobalAdminOrAccountant` allows global admins and accountants. It guards `GlobalDepositController` and `GlobalTransactionsController`.
- The admin endpoints use `RequireAdminAccess` attributes that check the system role, and the CMS hides pages by role in `auth/permissions.js`.
- A full role-to-permission matrix is **not written yet**.

## Inviting CMS members
`GraphApiService` sends the invitation through the Microsoft Graph REST API (`graph.microsoft.com/v1.0/invitations`, with the redirect URL from `GraphApi` settings). `AdminMemberService` and `AdminEntityService` use it when staff are added.

## Not confirmed
- The Unity player token lifetime (the CMS default of 24 hours is confirmed; `AuthOptions` has a 24-hour session setting that was not traced).
- Exactly which endpoints allow anonymous access beyond the login ones. Class-level `[Authorize]` was checked; individual `[AllowAnonymous]` actions were not.

---
title: "CMS Frontend"
category: architecture
agent_hint: "Load when working in the CMS React app: providers, API client, feature flags, deploy."
index_tier: lazy
review_by: 2027-01-12
type: component
status: live
side: cms
owner: syed
last_verified: 2026-10-14
tags: [component, side/cms]
---

# CMS Frontend

Private, role-based React app for restricted staff. It configures what the Unity app shows. Verified against `develop` commit e4c93a4 (PR 742). Part of [[Architecture Overview]].

## Facts
- App folder: `gms-content-management-system/` in the CMS repo (Azure DevOps `globalmobisoft/TifoXR Content Manager`). Local: `C:\TifoXR\TifoXRContentManager`.
- Stack (package.json): React 19, MUI 7, Tailwind 3, react-router-dom 7, axios, `@microsoft/signalr`, `@azure/msal-browser` and `msal-react`, exceljs, react-dnd, Jest.
- Build tool: Create React App (`react-scripts` 5). Run: `npm start`. Test: `npm test` (Jest, about 158 test files). Build: `npm run build`.

## Source layout (`src/`)
| Folder | Holds |
|---|---|
| `api/` | One file per area (`boothApi.js`, `approvalApi.js`, `paymentApi.js` and so on) plus `client.js` and `apiConfig.js` |
| `auth/` | `msalConfig.js`, `msalInstance.js`, `permissions.js` (roles), `ProtectedRoute.jsx` |
| `context/` | Auth, Space, SpaceConfig, Localization, Currency, Toast, Approval, NavigationGuard |
| `pages/`, `components/` | Screens and their parts, grouped by feature (booth, items, approval, finance, ...) |
| `hooks/`, `utils/`, `constants/` | `usePermissions`, `useSpaceId`; helpers; content types and SignalR event names |
| `services/` | `signalRService.js`, `translationService.js` |

## How it starts
`index.js` wraps the app in `MsalProvider`, then the theme, then these providers in order: Auth, SpaceConfig, Localization, Space, Currency, Toast, Approval, NavigationGuard. Auth is outermost so the data contexts can read the active space.

## Signing in
MSAL signs the person in against the CIAM authority, then the CMS exchanges that token with the backend ([[Authentication]]). The app token, system role, user id, entity id and spaces are kept in `localStorage` under `tifoxr_*` keys; MSAL's own cache is also in `localStorage`. After sign-in the user picks a **space** (`/select-space`) and the active space is stored too.

## Calling the API
- `apiConfig.js` sets one axios request interceptor that adds `Authorization: Bearer <token>` and a 30 second timeout. On a **401** it tries once to re-exchange the token silently through MSAL, queues other requests meanwhile, and otherwise forces a new login.
- `spaceClient` (in `client.js`) builds URLs as `{API_ROOT}/{activeSpaceId}/...`, where `API_ROOT` defaults to `{API_BASE}/api/space`. Many CMS reads use `/cms/...` routes (for example booths), and some writes (for example creating a booth) use the shared non-`cms` routes.
- Admin screens call the `api/admin/...` endpoints directly.
- Build-time settings (names only): `REACT_APP_API_BASE`, `REACT_APP_API_ROOT`, `REACT_APP_CIAM_AUTHORITY`, `REACT_APP_CIAM_CLIENT_ID`, `REACT_APP_CIAM_REDIRECT_URI`.

## Access control in the UI
- Roles are in `auth/permissions.js`: system roles `global_admin`, `entity_admin`, `gms_accountant`; space roles are listed in [[Project Overview]].
- `ProtectedRoute` guards role-limited pages: user analytics, admin portal, CCU settings, game score board.
- Other pages sit behind `FlagRoute`, a **per-space feature flag** read from the admin space config (`getSpaceConfig`). Flags seen: booths, recognition, aiModeration, events, items, subscriptions, rewards, charities, lighting, selfies, payments, advertisers, approvals.
- The backend enforces access too; the UI only hides things. The full role matrix is still to do.

## Real-time
`signalRService.js` connects to the API's `/hubs/content-approval` with the token and listens for approval events and `ForceLogout` ([[Approval Workflow]]).

## Build and deploy
Pipeline `azure-pipelines.yml` triggers on develop, test and main. A Jest stage runs first. Then `DeployDev`, `DeployTest` or `DeployProd` builds the app and deploys it with the **AzureStaticWebApp** task (`staticwebapp.config.json` rewrites unknown paths to `index.html`). The dev stage runs a smoke test and **rolls back** on failure.

## Pages
Dashboard, Approvals, Booth and BoothEdit, Items, Packages (and add-items pages), Free-trial add items, Events, Teleport map, Advertisers (brand and campaign), Charities, Rewards, Payments, Subscriptions, Game score board, CCU settings, Lighting, Recognition, Selfies, AI moderation, User analytics, Admin portal, Settings, Space select, Login. Some routes (portal, hosting) are commented out in `App.js`.

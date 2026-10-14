---
title: "Project Overview"
category: project
agent_hint: "Load to understand the business: private role-based CMS, public Unity app, one backend, roles and environments."
index_tier: eager
review_by: 2027-01-12
type: overview
status: live
side: shared
owner: syed
last_verified: 2026-10-14
tags: [overview, side/shared]
---

# Project Overview

TifoXR is an immersive/VR platform built by Global Mobile Software LLC. Players use a Unity WebGL app. Staff configure what the players see through a CMS. One backend serves both.

## The three parts
| Part | Audience | Access | Note |
|---|---|---|---|
| Unity WebGL app | All users, public | Guests and logged-in players | [[Unity Contract]] |
| CMS (React) | Restricted staff only | Private, role-based | [[CMS Frontend]] |
| Backend API (.NET 10) | Serves both | CMS endpoints behind roles; Unity endpoints public-facing | [[Backend API]] |

## What the CMS is for
The CMS holds the configuration and settings the Unity app needs: content, ads and campaigns, booths, spaces, portals, teleport, shop items, rewards, games, approvals, payments setup. Staff change data in the CMS. Approved changes are published to Azure Blob as versioned JSON, which Unity then pulls. See [[Architecture Overview]].

## Roles (CMS)
Role names found in the CMS code (`auth/permissions.js`):
- System roles: `global_admin`, `entity_admin`, `gms_accountant`
- Space roles: `space_admin`, `event_host_3d`, `event_host_2d`, `marketing`, `marketing_manager`, `star_guest`, `finance`, `data_analyst`, `demo_user`

What each role may do is **not yet documented**. To do: read `permissions.js` and the backend policies and write a role matrix.

## Environments
| Branch | Environment |
|---|---|
| develop | dev |
| test | test |
| master (backend) / main (CMS) | prod |

Details in [[Backend API]] and [[CMS Frontend]].

## Repositories
Both live in Azure DevOps under `globalmobisoft`:
- `TifoXRCoreWebAPI` (backend, local path `C:\TifoXR\TifoXRCoreWebAPI`)
- `TifoXR Content Manager` (CMS, local path `C:\TifoXR\TifoXRContentManager`)
The Unity client is out of scope except for its API contract.

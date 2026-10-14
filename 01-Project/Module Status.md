---
title: "Module Status"
category: project
agent_hint: "Load to know which features are live, in development or planned. Events is phase 0 and not usable."
index_tier: eager
status: live
review_by: 2027-01-12
type: module-status
owner: syed
last_verified: 2026-10-14
tags: [status]
---

# Module Status

Rule: on `develop` means live. Statuses below come from syed's answers and from the code on `develop` (backend commit c3c5f17, CMS commit e4c93a4).

| Module | Status | Evidence in code | Side |
|---|---|---|---|
| Shop, orders, Stripe and PayPal payments | live | OrderController, Stripe.net, PayPalServerSDK | shared |
| Content approval workflow | live | ContentApproval/, Approvals.jsx | cms |
| Booths, spaces, portals, teleport | live | BoothController, SpaceController, PortalController, TeleportTableController | shared |
| Friends, rewards, Google login | live | FriendRequest queue function, RewardController, Google.Apis.Auth | unity |
| Game announcements and leaderboards | live | GameAnnouncement/, LeaderboardController, GameScoreBoard.jsx | shared |
| Ads, campaigns, 3D ads and models | live | AdController, CampaignController, Ad3dModelModel | shared |
| Payment reconciliation and deposits | live (whatever is in code) | DepositController, GlobalDepositController | cms |
| Free trial | live (whatever is on develop) | FreeTrial/, CmsFreeTrialController | shared |
| Events | in-development, phase 0 only. NOT usable by users. | EventController, CmsEventController, EventScheduleDailyJob, Events.jsx | shared |
| Other undecided features | planned, not started | none | n/a |

## Events
Events is a much bigger feature. What is on `develop` today is **phase 0**, a first foundation that users cannot use yet (confirmed by syed, 2026-10-14). The code exists, so it is not "planned", but it must not be described as a working feature. The full Events scope is not yet defined; add a module note when it is.

## Open questions
1. What is the scope of Events beyond phase 0, and what are the later phases?
2. Which "other" features are planned? Name them so they can get planned-status notes.

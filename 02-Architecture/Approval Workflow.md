---
title: "Approval Workflow"
category: architecture
agent_hint: "Load for CMS content approval, approver roles and publishing after approval."
index_tier: lazy
review_by: 2027-01-12
type: architecture
status: live
side: cms
owner: syed
last_verified: 2026-10-14
tags: [architecture, side/cms]
---

# Approval Workflow

How content changes made in the CMS get reviewed and then published. Read from the backend `ContentApproval` code and the CMS approval API; part of [[Architecture Overview]].

## Vocabulary
- Statuses: `draft`, `pending`, `approved`, `rejected`.
- Action types: `create`, `edit`, `delete`, `convert`.
- Content types include booth, booth media, portal, custom booth item, event, teleport and teleport button, item, charity, hosting, advertiser, campaign, ad, reward, AI moderation rule, subscription, recognition, discount, lighting, selfie jumbotron, free trial setting and item, package and package item.

## Who approves
`ApprovalMatrix` maps each content type to approver roles:
- Almost every type: **marketing_manager**.
- Hosting: `event_host_3d`, `event_host_2d` or `marketing_manager`.
- **space_admin** is never listed but is always the last-resort approver.
- A special `demo_user` super-approver exists, marked in the code as temporary ("revert this class to remove the demo_user role").

`ApproverResolutionService` picks approvers in five steps and returns the first non-empty step: (1) holders of the specialized role other than the submitter's own, (2) same-role peers, (3) space admins, (4) peer space admins when the submitter is a space admin, (5) nobody. The submitter and last editor are always excluded. `ApprovalGateService` runs the same check **before** content is created or edited and blocks it with a 422 when no eligible approver exists.

## Flow
1. The CMS submits the change: `POST api/space/{spaceId}/approvals`.
2. Approvers see it in their inbox (`GET approvals/inbox`). Submitters see theirs in `GET approvals/my-submissions`.
3. An approver approves or rejects (`PATCH approvals/{id}/approve` or `/reject` with a reason). The submitter can withdraw (`PATCH .../withdraw`).
4. On **approve**, `ContentApprovalService` applies the change to the real data (`ContentEditApplier`). If applying fails, the approval status is reset to pending so data and status stay consistent.
5. After a successful apply, the service bumps the module version and publishes to Blob: [[Dynamic Pull Flow]]. Ad approvals publish the `ads` file through their own path.

## Real-time notices
The CMS connects to `/hubs/content-approval` and listens for `ApprovalRequested`, `ApprovalDecision`, `ApprovalWithdrawn` and `ForceLogout`. `ForceLogout` is sent by `AdminEntityService` when a user is removed from an entity or promoted.

## Not confirmed
- Which CMS edits skip approval and write directly.
- What each status transition allows beyond the endpoints above.

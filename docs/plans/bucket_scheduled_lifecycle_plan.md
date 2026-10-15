# Bucket Scheduled Lifecycle Plan

## Goal

Add a bucket-level scheduling model for time-based domain processes.

This is not a background job system and should not be modeled as a notification system. The scheduler records durable calendar facts about future domain work. Solid Queue, notifications, policies, and action objects can all use those facts, but none of them should be the source of truth.

The core example is compliance review:

- A bucket is approved.
- Approval grants authority until a fixed boundary, such as 12 months from approval.
- The renewal process starts earlier, such as 11 months from approval.
- Notifications tell people to act before and after the boundary.
- Restrictions come from the authority boundary itself, not from notification state.

## Core Decisions

1. Approval moves the authority boundary.
   Approval should set a durable date such as `compliance_valid_until`, `approved_until`, or another domain-specific validity boundary. That boundary is the line in the sand for capabilities and restrictions.

2. The scheduler starts processes; it does not define authority.
   A scheduled trigger should wake the system at 11 months to start the compliance review process. The actual authority boundary remains 12 months.

3. Overdue conditions are communication and escalation signals.
   If the process is still incomplete after the boundary, the system can notify, escalate, and show urgent UI. Those overdue conditions should not be the fundamental restriction mechanism.

4. Restrictions are derived from durable domain state.
   Policies, capability objects, and action objects should ask whether the bucket is still valid. They should not depend on whether a notification was delivered or a background job succeeded.

5. Notifications are downstream effects.
   Notifications should answer who needs to know, when, and through which channel. They should not own scheduling rules or domain authority.

6. Solid Queue is an execution mechanism.
   Solid Queue may dispatch due scheduled triggers, send notifications, or run process work. It should not be the durable calendar model.

## Conceptual Lifecycle

For a bucket approved on `2026-05-31`:

```text
approved_at: 2026-05-31
review_process_starts_at: 2027-04-30
compliance_valid_until: 2027-05-31
```

At approval:

```text
set compliance_valid_until = approval date + 12 months
schedule compliance review activation for approval date + 11 months
```

At 11 months:

```text
activate compliance review process
create review workflow or task
notify responsible people
record a timeline/event fact if useful
```

At 12 months:

```text
if the bucket has not been re-approved, capability and policy checks treat it as invalid
notifications can escalate because the review is now late
system restrictions apply because the validity boundary has passed
```

After successful re-approval:

```text
move compliance_valid_until forward another 12 months
schedule the next review activation
complete or close the previous review process
```

## Proposed Model Shape

Use two separate concepts:

- a generic scheduled trigger
- a domain-specific process object

### Scheduled Trigger

The generic trigger is the durable calendar entry. It knows when something should be activated, not how the business process works.

Suggested name:

- `ScheduledTrigger`

Suggested responsibilities:

- belongs to a `bucket`
- belongs to a polymorphic `triggerable`
- stores `trigger_at`
- stores `trigger_key`, such as `activate`, `deadline_reached`, or `escalate`
- stores trigger state, such as `pending`, `triggered`, `cancelled`, or `failed`
- records `triggered_at`

Example:

```text
ScheduledTrigger
  bucket: bucket
  triggerable: ComplianceReviewCycle
  trigger_key: "activate"
  trigger_at: 2027-04-30
  status: "pending"
```

The scheduler only needs to find pending triggers whose `trigger_at` has passed and ask the triggerable to handle them.

### Domain Process

The domain process owns business meaning.

Suggested name for the compliance case:

- `ComplianceReviewCycle`

Suggested responsibilities:

- belongs to a `bucket`
- stores the validity boundary it is working toward
- stores lifecycle state, such as `scheduled`, `active`, `completed`, or `cancelled`
- implements trigger behavior for activation and escalation
- creates review tasks, workflow records, events, and notifications as side effects
- schedules the next cycle when re-approval succeeds

Example:

```text
ComplianceReviewCycle
  bucket: bucket
  starts_at: 2027-04-30
  valid_until: 2027-05-31
  completed_at: null
  status: "scheduled"
```

The process object should expose a small trigger interface:

```ruby
handle_scheduled_trigger(trigger)
```

or a more explicit interface:

```ruby
activate_from_trigger!(trigger)
deadline_reached_from_trigger!(trigger)
```

The exact method name can be decided during implementation. The important point is that the scheduler remains generic and the process object owns domain behavior.

## Authority Boundary

The bucket should own or expose the relevant validity boundary.

Possible field names:

- `approved_until`
- `valid_until`
- `compliance_valid_until`
- `authorization_expires_at`

Prefer a positive authority name over a restriction name when possible. For example, `compliance_valid_until` describes what approval grants. Restrictions are then derived from the absence or expiry of that approval.

Policy and capability checks can interpret this boundary:

```ruby
bucket.compliance_valid?
bucket.restricted?
bucket.can_publish?
bucket.can_accept_new_content?
```

Action objects can enforce the same boundary before performing work:

```ruby
PublishBucket.call(bucket:, actor:)
AddRecording.call(bucket:, actor:, ...)
```

The split should be:

```text
validity boundary = source of truth
policy/capability/action object = interpretation and enforcement
scheduled process = renewal workflow
notification = communication and pressure
```

## Notification Role

Notifications should be generated by lifecycle transitions, not own the lifecycle.

Useful notification moments:

- review process activated
- review deadline approaching
- validity boundary reached
- review remains incomplete after the boundary
- escalation required

Notification delivery can fail, retry, be muted, or change channel. None of those outcomes should change whether the bucket is valid.

## Restriction Role

Restrictions should be derived from validity state.

The system should not need a job to run at exactly the boundary to make restrictions true. If `compliance_valid_until` is in the past, policy and capability checks should already know the bucket is no longer valid.

Scheduled work at the boundary can still be useful for side effects:

- send escalation notifications
- record an event
- update a workflow status
- notify administrators

Those side effects should support the restriction model, not be required for it.

## Implementation Direction

1. Add a durable bucket validity boundary for the first concrete domain, likely compliance review.
2. Add a generic scheduled trigger model scoped to buckets.
3. Add a compliance review process model that can be triggered.
4. On approval, move the validity boundary and schedule the review activation trigger.
5. Add a scheduler job that dispatches pending triggers through Solid Queue.
6. Add notification side effects from process activation and escalation.
7. Update policy, capability, or action object checks to derive restrictions from the validity boundary.

## Open Questions

- What is the first real validity boundary name in the domain: compliance, approval, authorization, or something else?
- Should each review cycle be represented as its own model, or should the first implementation use a more generic process model with a type key?
- Should activation create a task, a recording, an event, or a dedicated workflow record?
- Which bucket actions should be restricted after the validity boundary passes?
- Should the next cycle be scheduled when approval is granted, when the current cycle completes, or both?

## Non-Goals

- Do not build a generic background job framework.
- Do not make notifications the source of truth.
- Do not make overdue notification state control system restrictions.
- Do not store a future Ruby class name as the main scheduled fact.
- Do not put scheduling responsibilities inside policy objects.

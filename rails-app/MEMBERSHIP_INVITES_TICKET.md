# Ticket: Add Membership Invites

## Summary

Add a `MembershipInvite` model that represents a pending, one-bucket access grant. The invite stores the target bucket, invited email address, and proposed role. Accepting the invite creates the actual `Membership` for the accepting person.

## Background

Access in the app is modeled through `Membership`, which joins a `Person` to a `Bucket` with a bucket-specific role. A person can be an admin in one bucket and a viewer in another.

Invites should follow the same shape. A `MembershipInvite` should be scoped to one bucket and should carry the role that will become the eventual `Membership#role`. The invite itself must not grant authorization; only an accepted membership should.

## Goals

- Create an admin namespace with an admin dashboard page.
- Link to the admin dashboard from the top bar next to the existing Sys Admin link.
- Allow an authorized person to invite someone to a specific content bucket.
- Store the invited role on the invite.
- Create the membership only when the invite is accepted.
- Support different roles for the same person across different buckets.
- Keep authorization checks based on `Membership`, not `MembershipInvite`.
- Provide invite UI from the existing bucket administration surface.

## Admin Namespace

Create an `admin` namespace for bucket administration features.

The initial admin namespace should include an admin dashboard page. The dashboard should be accessible from the application's top bar, positioned beside the existing Sys Admin link.

The admin namespace should include:

- `Admin::Invites` for creating and managing membership invites.
- `Admin::Users` for viewing users/members relevant to administration.

The membership invite UI should live under `Admin::Invites` and be reachable from the admin dashboard or bucket administration flow.

## Proposed Model

Create `MembershipInvite` with:

- `bucket_id`, required
- `invited_by_id`, required, references `people`
- `accepted_by_id`, optional, references `people`
- `email_address`, required
- `role`, required, using the same enum values as `Membership`
- `token_digest`, required
- `expires_at`, required
- `accepted_at`, optional
- `revoked_at`, optional
- timestamps

Suggested associations:

```ruby
class MembershipInvite < ApplicationRecord
  belongs_to :bucket
  belongs_to :invited_by, class_name: "Person"
  belongs_to :accepted_by, class_name: "Person", optional: true

  enum :role, Membership.roles
end
```

## Constraints

Add a unique index for invite tokens:

```ruby
add_index :membership_invites, :token_digest, unique: true
```

Prevent duplicate active invites for the same bucket/email pair:

```ruby
add_index :membership_invites,
  [:bucket_id, :email_address],
  unique: true,
  where: "accepted_at IS NULL AND revoked_at IS NULL"
```

Consider normalizing `email_address` the same way `User` does.

## Invite States

Prefer timestamp-derived state over a status enum:

- Active: `accepted_at.nil? && revoked_at.nil? && expires_at.future?`
- Accepted: `accepted_at.present?`
- Revoked: `revoked_at.present?`
- Expired: `expires_at.past?`

Renewing an expired invite should extend `expires_at` on the existing invite rather than creating a replacement invite. Renewal is useful for ease of use, but can be treated as out of scope for the initial implementation.

## Acceptance Behavior

When a valid invite is accepted:

1. Resolve or create the accepting `Person` through the auth/signup flow.
2. Create the membership for the invite bucket and role.
3. Mark the invite accepted.

Acceptance is controlled by possession of the invite token, not by matching the accepting account's email address to `email_address`. Anyone with access to the email containing the invite link may accept it, including a person who already has an account under a different user/email identity.

Example behavior:

```ruby
Membership.create!(
  person: accepting_person,
  bucket: invite.bucket,
  role: invite.role
)

invite.update!(
  accepted_at: Time.current,
  accepted_by: accepting_person
)
```

If the invited person already has a membership for the bucket, the invite should not be created. Membership role changes must happen through the membership management flow, not the invite mechanism.

If a person who already has a membership for the bucket attempts to accept an invite, the invite must not create a duplicate membership or change the existing role.

## Authorization Rules

- Sys admins may create invites for any content bucket.
- Bucket admins may create invites only for buckets where they have admin membership.
- Creating invites should be rejected when the invited email address already belongs to a person with membership in the bucket.
- Accepting an invite should not require existing bucket access.
- `MembershipInvite` should never be used as an authorization source.
- Bucket access should continue to flow through `Membership`.

## Out Of Scope For Initial Implementation

- Renewing expired invites by extending `expires_at`.

## Acceptance Criteria

- An admin namespace exists.
- An admin dashboard page exists.
- The admin namespace includes an `Admin::Invites` section.
- The admin namespace includes an `Admin::Users` section.
- The top bar includes a link to the admin dashboard beside the existing Sys Admin link.
- A person can be invited to one bucket with a specific role.
- The invite can be accepted by any authenticated person who has the valid invite token, even if their account email differs from the invited email address.
- Accepting the invite creates exactly one membership for that bucket/person pair.
- The created membership uses the role from the invite.
- The same person can hold different roles in different buckets.
- Invites cannot be created for people who are already members of the target bucket.
- Sys admins can invite users to any content bucket.
- Bucket admins can invite users only to buckets where they have admin membership.
- Invite creation is available from the bucket administration UI that sys admins and bucket admins can access.
- Duplicate active invites for the same bucket/email pair are prevented.
- Expired, revoked, and accepted invites cannot be accepted.
- Expired invite renewal is not required for the initial implementation.
- Authorization checks continue to use memberships only.

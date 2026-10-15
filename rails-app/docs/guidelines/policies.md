# Policy Guidelines

## Overview

This document covers `app/policies`. Policies are the source of truth for authorization decisions. They answer permission questions and avoid rendering, redirects, persistence, and controller state.

Controllers use policies to enforce access. Action objects use the same policies to decide whether controls should be visible.

---

## 1. Policy Responsibilities

Policies should:

- Answer one permission question per public method
- Return `true` or `false`
- Use explicit context passed to the initializer
- Keep role and ownership rules in one place
- Be easy to test without rendering or request setup

Policies should not:

- Read `Current`, `params`, `session`, or request objects
- Render views or build links
- Mutate records
- Send mail, enqueue jobs, or publish events
- Hide missing authorization behind broad rescue behavior

If a rule changes whether a user may perform an operation, it belongs in a policy or in a model method called by a policy. It does not belong only in a view or action object.

---

## 2. Two Policy Shapes

The app currently uses two related policy shapes.

### Recordable Policies

Recordable policies authorize commands for a recordable type, usually through a `Recording`:

```ruby
class ArticlePolicy < RecordablePolicy
  def can_create?
    bucket_admin?
  end

  def can_edit?(recording)
    assert_recordable!(recording)

    bucket_admin?
  end
end
```

Use this shape for capabilities such as:

- Creating a recordable
- Editing or deleting a recordable recording
- Publishing a publishable recordable
- Commenting on a commentable recordable

Recordable policies are initialized with:

```ruby
ArticlePolicy.new(person: Current.person, bucket: Current.bucket)
```

They are used by controllers directly and by `ActionsBase#person_allowed_to?`, which maps `:publish` to `can_publish?`.

### Recording Policies

Recording policies authorize generic recording permissions exposed by `Permissible`:

```ruby
recording.editable_by?(person)
recording.deletable_by?(person)
recording.viewable_by?(person)
```

The default policy is:

```ruby
class DefaultRecordingPolicy
  def initialize(person:, recording:)
    @person = person
    @recording = recording
  end

  def editable?
    person.editor_of?(recording.bucket)
  end
end
```

Use a specialized recording policy when a recordable has different generic behavior:

```ruby
class PersonCardRecordingPolicy < DefaultRecordingPolicy
  def editable?
    owner? || person.admin_of?(recording.bucket)
  end
end
```

`Permissible` resolves `"#{recordable_type}RecordingPolicy"` first and falls back to `DefaultRecordingPolicy`.

---

## 3. Naming Conventions

Use these names consistently:

| Policy Type | Class Name | Public Methods | Initializer |
|-------------|------------|----------------|-------------|
| Recordable command policy | `ArticlePolicy` | `can_create?`, `can_edit?(recording)` | `person:, bucket:` |
| Generic recording policy | `ArticleRecordingPolicy` | `editable?`, `deletable?`, `viewable?` | `person:, recording:` |
| Fallback recording policy | `DefaultRecordingPolicy` | `editable?`, `deletable?`, `viewable?` | `person:, recording:` |

Use `can_<action>?` for recordable command policies because `ActionsBase` depends on that method shape.

Examples:

```ruby
can_create?
can_edit?(recording)
can_delete?(recording)
can_publish?(recording)
can_comment_on?(recording)
```

Use plain adjectives for generic recording policies:

```ruby
editable?
deletable?
viewable?
```

---

## 4. Context Rules

Pass context into policies explicitly.

Good:

```ruby
ArticlePolicy.new(person: Current.person, bucket: Current.bucket)
PersonCardRecordingPolicy.new(person:, recording:)
```

Avoid:

```ruby
Current.person
Current.bucket
params[:id]
request.path
```

Policies should not know where the request came from. A controller, action object, or model concern provides the person, bucket, and recording.

Guest access should work through `GuestPerson`, not `nil` checks spread through policies. If a policy receives a person-like object, it should be able to ask role methods such as `guest?`, `viewer_of?`, `editor_of?`, `admin_of?`, and `sys_admin?`.

---

## 5. Bucket and Role Semantics

Use the role helpers on `Person`:

```ruby
person.viewer_of?(bucket)
person.editor_of?(bucket)
person.admin_of?(bucket)
person.sys_admin?
```

These helpers encode the membership hierarchy:

- A viewer can view bucket content
- An editor can edit bucket content
- An admin can administer bucket content
- A sys admin can act across operational boundaries

Do not query `Membership` directly in policies unless the role helpers cannot express the rule. If a new reusable role concept appears, add it to `Person` or a focused model method first.

Membership invites must not grant authorization. Only accepted `Membership` records should be used for authorization.

---

## 6. Recordable Type Guards

Recordable policies should guard methods that receive a recording:

```ruby
def can_publish?(recording)
  assert_recordable!(recording)

  recording.publishable? && bucket_admin?
end
```

`RecordablePolicy#assert_recordable!` raises when the policy is asked to authorize the wrong recordable type. This catches wiring mistakes early:

```ruby
ArticlePolicy cannot authorize Comment
```

Do not silently return `false` for impossible type mismatches unless the caller is intentionally probing multiple policy types. In normal controller and action paths, a mismatch is a bug.

---

## 7. Controller Enforcement

Every mutating or private controller action should enforce authorization before performing work:

```ruby
before_action :authorize_article_editing, only: [ :edit, :update ]

def authorize_article_editing
  head :forbidden unless article_policy.can_edit?(@recording)
end

def article_policy
  ArticlePolicy.new(person: Current.person, bucket: Current.bucket)
end
```

For dynamic recordable actions, resolve the policy from the recording type:

```ruby
def publication_policy
  policy_class = "#{@recording.recordable_type}Policy".safe_constantize
  policy_class&.new(person: Current.person, bucket: Current.bucket)
end
```

If no policy exists for a command, deny the action. Do not treat a missing policy as permission.

Action objects may hide the matching button or link, but that is only a usability layer.

---

## 8. Model Permission Helpers

Use `Permissible` methods for generic recording permissions:

```ruby
recording.viewable_by?(Current.person)
recording.editable_by?(Current.person)
recording.deletable_by?(Current.person)
```

These are appropriate when the permission is about the recording itself, such as viewing a diff.

Use recordable command policies when the permission is about a specific command or capability:

```ruby
ArticlePolicy.new(person:, bucket:).can_publish?(recording)
ArticlePolicy.new(person:, bucket:).can_comment_on?(recording)
```

Do not add one-off permission methods directly to controllers or views when they represent reusable domain authorization.

---

## 9. Testing

Policy tests should cover:

- Allowed role
- Denied lower role
- Guest or non-member behavior
- Owner-specific behavior, when ownership matters
- Type mismatch behavior for recordable policies
- Specialized recording policies and default fallback behavior

Prefer direct policy tests:

```ruby
policy = ArticlePolicy.new(person:, bucket:)

assert policy.can_publish?(recording)
refute policy.can_delete?(recording)
```

Avoid testing policies through rendered pages unless the behavior is specifically about integration. Controller tests should verify enforcement. Action tests should verify visibility.

---

## 10. Checklist

Before adding or changing a policy:

- Is the initializer explicit and free of request state?
- Does each public method answer one permission question?
- Are role checks using `Person` helper methods?
- Does a recordable policy guard recording type with `assert_recordable!`?
- Does the controller enforce the policy before mutation?
- Does the matching action object use the same policy for visibility?
- Are allowed and denied cases covered by focused tests?

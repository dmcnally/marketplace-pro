# Action Guidelines

## Overview

This document covers `app/actions` objects. In this application, action objects are view-facing presenters for links, buttons, forms, and small rendered fragments.

Actions keep ERB templates declarative:

```erb
<%= article_actions.edit_link_for(@recording) %>
<%= publication_actions.toggle_for(@recording) %>
<%= comment_actions.new_form_for(@recording) %>
```

They are not service objects. They should not perform domain mutations, load controller params, redirect, or enforce request-level security.

---

## 1. Responsibilities

Use an action object when a view needs reusable UI for an available action.

Good uses:

- Rendering a `link_to` or `button_to`
- Rendering a small partial such as a toggle or form
- Hiding an unavailable control by returning `nil`
- Keeping path helper, CSS class, and confirm text details out of templates
- Centralizing policy-backed capability checks for visible controls

Do not use an action object for:

- Creating, updating, or deleting records
- Sending mail, enqueueing jobs, or publishing events
- Reading `params`, `session`, or request state directly
- Replacing controller authorization
- Holding business rules that belong in a policy or model

Rule of thumb: an action object can decide whether and how to show a control. The controller or model still performs the work.

---

## 2. File and Class Names

Place action objects in `app/actions`.

Use one action class per resource or surface:

```text
app/actions/articles_actions.rb              # ArticlesActions
app/actions/publications_actions.rb          # PublicationsActions
app/actions/session_actions.rb               # SessionActions
app/actions/admin/actions.rb                 # Admin::Actions
app/actions/admin/sidebar_actions.rb         # Admin::SidebarActions
app/actions/sys_admin/bucket_actions.rb     # SysAdmin::BucketActions
```

Use a namespace when the controls belong to a namespace in the UI or routes:

- `Admin::*` for bucket administration screens
- `SysAdmin::*` for sys admin screens
- Top-level classes for application-wide or public content controls

Prefer resource names over generic names. `ArticlesActions` is better than `PageActions` when the methods are article-specific.

---

## 3. Constructor Pattern

Most app actions should accept the view context, current person, and current bucket:

```ruby
class ArticlesActions < ActionsBase
  def new_link
    return unless person_allowed_to?(:create, Article)

    view.link_to "New Article", view.new_article_path, class: "btn btn--primary"
  end
end
```

`ActionsBase` provides:

- `view` - the Action View context
- `person` - the current person or `GuestPerson`
- `bucket` - the current bucket
- `person_allowed_to?(action, recordable)` - policy-backed visibility checks

Use `ActionsBase` when the action needs policy checks or standard current context. A smaller custom initializer is acceptable for isolated management surfaces that do not use recordable policies, but keep the public API consistent with nearby action classes.

Do not call `Current.person` or `Current.bucket` from inside action objects. Pass context in from helper factories.

---

## 4. Helper Factories

Expose action objects through helpers and memoize them per render:

```ruby
module ApplicationHelper
  def article_actions
    @article_actions ||= ArticlesActions.new(
      view: self,
      person: Current.person,
      bucket: Current.bucket
    )
  end
end
```

Use the narrowest helper module that matches the UI:

- `ApplicationHelper` for global/content actions
- `AdminHelper` for admin actions
- `SysAdminHelper` for sys admin actions

Views should ask for a named action object instead of instantiating action classes directly.

---

## 5. Method Naming

Name public methods after the UI element they return:

```ruby
new_link
index_link
edit_link_for(recording)
show_link_for(record)
delete_button_for(recording)
toggle_for(recording)
new_form_for(parent_recording)
render_for(recording)
```

Use `_for` when the method depends on a record. Omit `_for` for fixed links or global actions.

Return either rendered output or `nil`. Returning `nil` is the standard way to hide an unavailable control:

```ruby
def edit_link_for(article)
  return unless person_allowed_to?(:edit, article)

  view.link_to "Edit", view.edit_article_path(article), class: "btn btn--primary"
end
```

This allows templates to render controls directly without extra conditionals.

---

## 6. Authorization and Visibility

Action objects may hide controls, but hidden controls are not security.

The same permission must be enforced in the controller or model path that performs the operation:

```ruby
def authorize_article_editing
  head :forbidden unless article_policy.can_edit?(@recording)
end
```

For recordable controls, prefer policy checks through `ActionsBase`:

```ruby
return unless person_allowed_to?(:publish, recording)
```

This resolves `ArticlePolicy` from the recording's `recordable_type` and calls `can_publish?(recording)`.

For management surfaces that are not recordable-specific, small role checks are acceptable when they mirror controller gates:

```ruby
return unless person.sys_admin?
return unless person.admin_of?(bucket)
```

Do not duplicate complex authorization logic in actions. Move that logic into a policy and call the policy from both the action object and the controller.

---

## 7. View Context Usage

Action objects should call Rails helpers through the injected `view`:

```ruby
view.link_to "View", view.sys_admin_bucket_path(bucket), class: "btn btn--secondary"

view.button_to "Reset Password",
               view.sys_admin_user_password_path(user),
               method: :post,
               class: "btn btn--danger",
               form_class: "user-detail__action-form"

view.render "publications/toggle", recording: publishable
```

Do not include helper modules into action classes. Keep dependencies visible through the `view` object so tests can use small fake views.

Use `link_to` for GET navigation. Use `button_to` for form submissions when the surrounding markup allows it. If an existing inline control uses `link_to` with Turbo method data, follow the surrounding pattern and keep destructive controls clearly styled and confirmed.

Destructive controls should use:

- `btn--danger` or the local destructive style
- A `turbo_confirm` message when accidental activation is plausible
- `form_class` when `button_to` needs layout-specific styling

---

## 8. Rendering Partials

Use actions for small, reusable fragments that represent an available action:

```ruby
class PublicationsActions < ActionsBase
  def toggle_for(publishable)
    return unless person_allowed_to?(:publish, publishable)

    view.render "publications/toggle", recording: publishable
  end
end
```

The partial should receive explicit locals. Avoid relying on instance variables inside partials rendered from action objects.

If the rendered content is a whole page section or domain display, prefer a normal partial/helper. Actions should stay focused on controls and command surfaces.

---

## 9. Testing

Action object tests should use fake view objects instead of full integration rendering when possible:

```ruby
class FakeArticlesView
  def link_to(label, path, options = {})
    { label:, path:, options: }
  end

  def new_article_path
    "/articles/new"
  end
end
```

Test both sides of visibility rules:

- Authorized users get the expected link, button, or rendered fragment
- Unauthorized users get `nil`
- Special cases are explicit, such as non-switchable buckets or guests

When an action uses a policy, policy tests should cover the permission logic. Action tests should only verify that the action calls the permission boundary and renders the expected UI.

---

## 10. Checklist

Before adding a new action method:

- Is this view-facing UI, not domain work?
- Does a controller or model still enforce the permission?
- Is authorization delegated to a policy when the rule is more than a simple namespace gate?
- Does the method return rendered output or `nil`?
- Are path helpers and CSS classes kept inside the action object?
- Is the action exposed through a helper factory?
- Is there a focused action test for visible and hidden cases?

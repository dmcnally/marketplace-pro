# Admin persona

## Sam — team administrator

Sam owns or manages a small takeaway and is responsible for giving the right
people access to its workspace. They invite new colleagues, choose their roles,
and change permissions when responsibilities change. They manage access between
other operational tasks and need clear explanations rather than technical
permission settings.

> “I want to get someone onto the team, give them the access they need, and
> understand exactly what will change when I update their role.”

This is a representative persona, not a new user account. Sam manages access
within their business's workspace; they are not a platform-wide system admin.
They work with [Alex, the menu editor](editor.md), who owns day-to-day menu
curation. Products, Categories, Allergens, and Menus belong in the main sidebar
for editors and admins. Only admins see the Admin entry; its dashboard contains
user-management functions such as Members, roles, and Invitations.

## Responsibilities

- Invite colleagues to the correct workspace using their name and email address.
- Choose a role based on the person's actual responsibilities.
- Track whether an invitation is pending, accepted, expired, or cancelled.
- Correct mistaken invitations before they are accepted.
- Change existing members' roles as their responsibilities change.
- Review team access when people join, change jobs, or leave the business.
- Ensure the business retains someone able to administer its workspace.

Although an admin can also manage the catalogue and publish menus, Sam's primary
task in this persona is managing people and permissions.

## Choosing a role

Roles apply to the selected workspace, not every workspace the person belongs to.

| Role | Suitable for | What the person can do |
| --- | --- | --- |
| Viewer / staff | Colleagues serving customers or working in the kitchen | Access Overview and the Orders destination; change availability for choices on the live menu. Cannot edit catalogue content or manage team access. |
| Editor | Alex and other menu curators | Staff capabilities, plus manage products, categories, allergens, and menus; publish products and menus. Cannot manage team access. |
| Admin | Sam and colleagues responsible for the team | Editor capabilities, plus manage invitations and view members; responsible for changing permissions through the intended role-management workflow. |

The current stored role is named `viewer`, but it is not strictly read-only:
workspace members can change live-menu availability. Role descriptions should
make that clear. The Orders destination currently exists as a deferred feature;
it does not provide order processing.

## Tasks to invite a colleague

### 1. Check the workspace and existing team

Confirm which business's workspace is open. Check members and pending
invitations to avoid inviting someone who already has access or an outstanding
invitation.

**Result:** Sam knows whether to invite someone or update an existing membership.

### 2. Choose the person's access

Identify what the colleague needs to do. Choose staff access for availability
management, editor access for menu curation, or admin access for team management.
Read a short explanation of the selected role before proceeding.

**Result:** the selected role matches the person's responsibilities.

### 3. Send the invitation

Enter the person's first name, last name, and email address. Check the recipient,
workspace, and role, then send the invitation.

**Result:** an invitation is sent and appears as pending. Sending an invitation
does not itself grant workspace access; acceptance creates the membership.

### 4. Follow up on its status

Check whether the invitation has been accepted. Cancel an active invitation if
the email address or intended role is wrong, then create a corrected invitation.
If an invitation expires, Sam needs a clear way to invite the person again.

**Result:** Sam can distinguish someone who has joined from someone still waiting
to join, and knows the next action when an invitation cannot be used.

## Tasks to change permissions

This is the intended workflow for Sam's requested responsibility. The current
app lists members and their roles but does not yet provide role editing.

1. **Find the member.** Identify the person by name and email in the correct
   workspace. Show their current role alongside their identity.
2. **Choose the new role.** Explain which capabilities will be added or removed.
   For example, changing Alex from editor to viewer removes menu editing and
   publication access while retaining live-menu availability controls.
3. **Review the impact.** Summarise the person, workspace, and change from the
   current role to the new role. Make granting admin access explicit.
4. **Apply the change.** Save the new role and show a clear success message and
   updated membership. If saving fails, retain the selection and explain how to
   recover without implying the role changed.
5. **Check the result.** Confirm the member now has the intended access. The role
   change should affect this workspace only and should not require a new invite.

## Goals, frustrations, and success

Sam wants colleagues to get started without unnecessary back-and-forth and wants
to understand permissions without memorising a role hierarchy. Common
frustrations are ambiguous role names, confusing invited people with active
members, duplicate invitations, and uncertainty about whether a change saved.

Success means every colleague has the intended role in the correct workspace,
invitation status is clear, and Sam can explain what each person is allowed to do.

## UX needs for design and implementation

- Separate pending invitations from active members, while making both easy to find.
- Give each screen one clear next action: invite, review an invitation, or change
  a member's role.
- Describe permissions in everyday language beside the role selector.
- Show the member's identity and current role when reviewing a role change.
- Make cancellation and back navigation predictable, without silently applying edits.
- Preserve entered values after validation errors and show errors beside the
  relevant fields.
- Explain expired invitations and provide a working recovery path.
- Prevent accidentally leaving a workspace without an administrator; define how
  self-demotion and removal of the last admin should work before implementation.
- Make access changes traceable so an admin can see who changed a role and when.

These are persona-driven design needs, not claims that all safeguards and history
features already exist.

## Current implementation boundaries

The app supports admin-only invitation creation, invitation listing, cancellation
of active invitations, and member listing. Invitations normally expire after
14 days. Accepted invitations create a membership with the invited role.

Changing existing roles, removing members, invitation resend/reissue, access-change
history, and last-admin protection are not exposed by the inspected team-management
workflow. In particular, a replacement for an expired invitation needs implementation
review: current uniqueness validation can still treat an expired, unrevoked
invitation as a duplicate. Do not present these tasks as working UI until verified.

## Completion checklist

- The intended workspace, person, and email address have been checked.
- The selected role matches the person's responsibilities.
- Invitation status is distinguishable from active membership.
- A permission change shows its impact before it is applied.
- The final role or invitation outcome is visible and unambiguous.
- The workspace retains a way for its team to administer access.

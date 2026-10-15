# Questionnaire Recordables Plan

## Goal

Provide a questionnaire workflow using the existing `Recording` / `Recordable` architecture.

Sys admins should be able to author questionnaire trees in the system bucket, publish immutable versions of those trees, and assign published versions to customer buckets for completion. Customer answers should be stored as recordable content under the customer-side questionnaire tree.

The design should preserve these properties:

- Sys admins can keep editing draft questionnaire content without changing already-assigned customer workflows.
- Published questionnaire versions are immutable release artifacts.
- Question content remains immutable and bucket-independent.
- Customer assignments are bucket-scoped recording trees.
- Answers can carry type-specific validation and progression behavior.

## Core Decisions

1. Use recordings for authoring, publishing, assignment, and answers.
   The questionnaire is naturally tree-shaped, and `Recording::Tree` already provides parent/child structure, bucket scoping, event history, and discard behavior.

2. Keep question content in concrete immutable recordables.
   Each question type should be a separate recordable model. Duplicate table structure is acceptable because it keeps each question type free to evolve without accumulating irrelevant columns.

3. Publish a questionnaire by creating a release recordable.
   A release stores a manifest of the current questionnaire tree. The manifest freezes structure and references immutable recordables by type and id.

4. Reconstruct customer assignments from a published release.
   Assignment creates a new recording tree in the customer bucket using the release manifest. The customer recordings can point at the same immutable question recordables because the content itself is bucket-independent.

5. Store answers as child recordings.
   Answers should not mutate questions. Each answer is its own immutable recordable, attached under the relevant question recording in the customer bucket.

6. Keep navigation outside answer models.
   Question and answer recordables can evaluate whether a response is complete, invalid, or blocking. A workflow service should decide how to move through the tree.

## Authoring Model

Sys admins author questionnaires as recording trees in the system bucket.

Example:

```text
Questionnaire: Onboarding
  QuestionGroup: Business details
    ShortTextQuestion: Company name
    LongTextQuestion: Registered address
  QuestionGroup: Consent
    SingleChoiceQuestion: Do you accept the terms?
```

Possible recordable models:

- `Questionnaire`
- `QuestionGroup`
- `ShortTextQuestion`
- `LongTextQuestion`
- `SingleChoiceQuestion`
- `MultipleChoiceQuestion`
- `DateQuestion`
- `FileUploadQuestion`

Each model should include `Recordable`. Question models should also expose a shared question capability, likely through a `Questionable` concern.

## Questionable Concern

Use a shared concern for question behavior, not for shared persistence fields.

The concern should give the rest of the system a small polymorphic contract:

```ruby
module Questionable
  extend ActiveSupport::Concern

  included do
    include Recordable
  end

  def questionable? = true

  def answer_recordable_types
    raise NotImplementedError
  end

  def evaluate_answer(answer)
    raise NotImplementedError
  end
end
```

Concrete question models own their own columns and rules.

Examples:

```text
SingleChoiceQuestion
  prompt
  required
  options

DateQuestion
  prompt
  required
  min_date
  max_date

FileUploadQuestion
  prompt
  required
  accepted_content_types
  max_file_size
```

The system should ask the recordable what it can do instead of branching on question class names throughout controllers and services.

## Publishing Model

Publishing should create a new immutable recordable such as:

- `QuestionnaireRelease`
- or `QuestionnaireVersion`

`QuestionnaireRelease` is a recordable whose payload is a JSON manifest.

The release is not the same concept as the existing `Publication` marker. The existing `Publication` model answers whether a recording is published. `QuestionnaireRelease` is a versioned release artifact containing the frozen structure of a questionnaire at a point in time.

Example tree:

```text
Questionnaire: Onboarding
  QuestionnaireRelease: v1
  QuestionnaireRelease: v2
```

or:

```text
Questionnaire: Onboarding
  Releases
    QuestionnaireRelease: v1
    QuestionnaireRelease: v2
```

## Release Manifest

The manifest should contain the concrete recordable type and id for each node, plus child ordering.

It does not need to duplicate recordable attributes if releases only need to work inside the same database. Recordables are immutable, so `recordable_type` and `recordable_id` are enough to reference frozen content.

Example:

```json
{
  "schema_version": 1,
  "root": {
    "recordable_type": "Questionnaire",
    "recordable_id": 12,
    "children": [
      {
        "recordable_type": "QuestionGroup",
        "recordable_id": 21,
        "children": [
          {
            "recordable_type": "ShortTextQuestion",
            "recordable_id": 44,
            "children": []
          },
          {
            "recordable_type": "SingleChoiceQuestion",
            "recordable_id": 45,
            "children": []
          }
        ]
      }
    ]
  }
}
```

Array order can be the initial sibling ordering mechanism. If ordering needs named positions later, add explicit `position` values to manifest nodes.

The manifest is the place where concrete recordable type identity is stored as data. Runtime behavior should remain polymorphic through recordable concerns and methods. `Recording::RECORDABLE_TYPES` still needs to allow the concrete classes for Rails delegated type support.

## Customer Assignment

Assigning a questionnaire release to a customer should create an operational record such as:

```text
QuestionnaireAssignment
  bucket_id
  questionnaire_release_recording_id
  root_recording_id
  assigned_by_id
  assigned_to_id
  due_at
  submitted_at
```

The assignment model owns workflow metadata. The reconstructed recording tree owns the content and answers.

Assignment flow:

1. Sys admin selects a `QuestionnaireRelease`.
2. App reads the release manifest.
3. App creates a new root `Recording` in the customer bucket.
4. App recursively creates child recordings in the customer bucket.
5. Each customer recording points at the immutable recordable referenced by the manifest.
6. App stores the customer root recording on `QuestionnaireAssignment`.

The reconstruction service should be generic:

```ruby
recordable = node.fetch("recordable_type").constantize.find(node.fetch("recordable_id"))

Recording.create!(
  bucket: customer_bucket,
  parent: parent_recording,
  recordable: recordable
)
```

The service should validate manifest types against an allowlist before constantizing.

## Recordable Sharing Note

This design intentionally allows many recordings to point at the same immutable question recordable.

The current `Recordable` concern declares:

```ruby
has_one :recording, as: :recordable, touch: true
```

If shared immutable question recordables become a first-class behavior, this association should be revisited. It may need to become:

```ruby
has_many :recordings, as: :recordable
```

or be supplemented with a clearer read path that does not assume one recordable has only one recording. The implementation should audit any code that calls `recordable.recording`.

Answer recordables may still be effectively one-to-one with their answer recordings, but the base concern should support the broader immutable-content model.

## Answers

Answers should be recordables attached as child recordings under customer-side question recordings.

Example:

```text
SingleChoiceQuestion: Do you accept the terms?
  SingleChoiceAnswer: No
```

Answer models can be separated by type:

- `ShortTextAnswer`
- `LongTextAnswer`
- `SingleChoiceAnswer`
- `MultipleChoiceAnswer`
- `DateAnswer`
- `FileUploadAnswer`

Splitting answer models is useful when storage, validation, rendering, or progression behavior differs.

Answer updates should follow the normal immutable recordable pattern:

1. Create a new answer recordable row.
2. Repoint the existing answer recording to the new recordable.
3. Let `Eventable` track the change.

## Answer Evaluation And Progression

Some answers are complete but should prevent the user from continuing. For example, a single-choice answer may select an option that blocks progression.

Use a richer evaluation result than a boolean.

Example:

```ruby
AnswerEvaluation = Data.define(:complete, :valid, :blocked, :messages, :metadata)
```

Suggested responsibilities:

- Question recordable owns configuration.
- Answer recordable owns submitted value.
- Question and answer together produce an evaluation.
- Workflow service owns navigation.

Example:

```ruby
evaluation = question.evaluate_answer(answer)

if evaluation.blocked
  stay_on_current_question
elsif evaluation.complete && evaluation.valid
  move_to_next_question
else
  render_validation_errors
end
```

For choice questions, blocking behavior belongs to the immutable question configuration. The answer stores selected option keys; the question determines whether any selected option blocks progression.

This distinction lets the app represent cases where:

- the answer is missing and cannot progress;
- the answer is invalid and cannot progress;
- the answer is valid and complete but intentionally blocks progression;
- the answer is valid and complete and can progress.

## Completion And Submission

Completion should be derived from the customer assignment tree where possible.

For each question recording:

1. Find the current kept answer child.
2. Ask the question recordable to evaluate the answer.
3. Aggregate required question results.
4. Check whether any evaluation blocks progression or submission.

Submission is operational state, not questionnaire content. `QuestionnaireAssignment` can cache state such as `submitted_at`, but the durable boundary for completion should be a separate submission fact.

## Submission State Model

Submission state should be modelled separately from questionnaire content so sys admins and admins can see work that needs attention without inspecting answer trees.

Use a current-state model attached to the relevant recording:

```text
QuestionnaireSubmissionState
  recording_id
  bucket_id
  state
  attention_required
  attention_reason
  assigned_to_id
  changed_by_id
  created_at
  updated_at
```

`recording_id` should point at the mutable customer-side questionnaire recording whose operational state is being tracked, usually the reconstructed questionnaire root recording. The state model should never point at `recordable_type` / `recordable_id` or embed state on immutable recordables.

The state row is an operational projection for queues and dashboards. It should be cheap to query:

```ruby
QuestionnaireSubmissionState
  .where(bucket: Current.bucket, attention_required: true)
  .order(updated_at: :asc)
```

Possible states:

- `submitted`
- `awaiting_review`
- `in_review`
- `requires_attention`
- `returned`
- `accepted`
- `closed`
- `reaction_failed`

The exact state names should come from product workflow needs, but the state model should support:

- sys admin and admin queues;
- ownership or assignment to a person;
- attention flags and reasons;
- retry/error states for failed reactions;
- transitions driven by reaction handlers or review actions.

If state history matters, add an append-only transition model:

```text
QuestionnaireSubmissionStateTransition
  recording_id
  bucket_id
  from_state
  to_state
  reason
  changed_by_id
  created_at
```

The current-state row supports efficient operational queries. The transition rows preserve history. Avoid deriving admin queues from historical events alone unless the query volume is known to be small.

The submit flow should create the submission and initial state for the submitted recording together. Reaction handlers can then move the state forward, mark it as requiring attention, or record failures without changing the questionnaire, release, question, or answer recordables.

## Submission Reactions

Questionnaire completion needs a decoupled reaction boundary. Submitting a questionnaire may need to notify an admin, start a review process, create tasks, call an integration, or trigger more complex workflow behavior later.

Those reactions should not live on the questionnaire, question, answer, or release recordables. The questionnaire content should define what is asked and how answers are evaluated. Submission reactions are operational behavior around a completed assignment.

Use a first-class submission fact as the boundary:

```text
QuestionnaireSubmission
  questionnaire_assignment_id
  recording_id
  bucket_id
  submitted_by_id
  submitted_at
```

`recording_id` should be the same customer-side questionnaire recording used by `QuestionnaireSubmissionState`.

The submit flow should be:

1. Validate the assignment is complete and not blocked.
2. Create a `QuestionnaireSubmission`.
3. Create the initial `QuestionnaireSubmissionState`.
4. Record an audit/timeline event if needed.
5. Commit the transaction.
6. After commit, enqueue reaction dispatch from the submission.

Avoid direct calls such as mailers, process builders, or integration clients inside the questionnaire submit transaction. The submit action should create a durable fact; reaction workers should consume that fact.

For reliability and future flexibility, consider an outbox-style model:

```text
WorkflowEvent
  bucket_id
  event_type
  subject_type
  subject_id
  payload
  processed_at
```

For a submitted questionnaire:

```json
{
  "event_type": "questionnaire.submitted",
  "subject_type": "QuestionnaireSubmission",
  "subject_id": 123,
  "payload": {
    "questionnaire_assignment_id": 456,
    "questionnaire_release_recording_id": 789,
    "recording_id": 321
  }
}
```

Reaction handlers can then subscribe to `questionnaire.submitted` without changing questionnaire models.

Possible handlers:

- `NotifyAdminsOnQuestionnaireSubmission`
- `CreateReviewTaskForQuestionnaireSubmission`
- `StartProcessFromQuestionnaireSubmission`
- `SendWebhookForQuestionnaireSubmission`

Handler selection should be configured outside question content. Depending on product needs, reaction configuration could be attached to:

- the questionnaire release;
- the customer assignment;
- the customer bucket;
- a broader workflow/process configuration.

The important boundary is that the submitted questionnaire emits a stable domain event, and separately configured reaction handlers decide what to do with it.

Handlers should be idempotent. A reaction may be retried, so each handler should either write idempotency keys or check whether its side effect already exists for the submission.

## Version History

Each publish creates a new `QuestionnaireRelease` recordable. Because recordables are immutable and recordings emit events, release history can be shown through:

- release child recordings under the draft questionnaire;
- timeline events on the questionnaire tree;
- an explicit releases list filtered by parent questionnaire.

Draft edits after a release do not affect the release manifest. Customer assignments created from old releases continue to point at the released structure and immutable question content.

## Implementation Outline

1. Add typed questionnaire and question recordables.
2. Add a `Questionable` concern and type-specific question behavior.
3. Add `QuestionnaireRelease` as an immutable recordable with a JSON manifest.
4. Add a publisher service that walks a system-bucket questionnaire tree and writes a release manifest.
5. Add `QuestionnaireAssignment` for customer workflow metadata.
6. Add an assignment reconstruction service that creates customer-bucket recording trees from release manifests.
7. Add typed answer recordables.
8. Add answer evaluation objects and progression service behavior.
9. Add `QuestionnaireSubmission` as the durable submission boundary.
10. Add `QuestionnaireSubmissionState` for current operational state and admin queues.
11. Add optional state transition history if audit/review workflows need it.
12. Add workflow event/outbox dispatch for `questionnaire.submitted`.
13. Add configurable reaction handlers for notification and process triggers.
14. Add views/controllers for sys admin authoring, release publishing, customer answering, assignment review, and submission queues.

## Validation And Tests

Model and service tests should cover:

- release manifest generation from an authored recording tree;
- manifest validation and rejected unknown recordable types;
- customer reconstruction preserving tree shape and sibling order;
- reconstructed recordings using the target customer bucket;
- shared immutable question recordables remaining unchanged across assignments;
- answer creation as child recordings;
- answer replacement by repointing the answer recording;
- question-specific answer evaluation;
- blocking answer behavior preventing progression;
- assignment completion and submission rules;
- submission creates one durable submission fact;
- submission creates an initial current-state row for the submitted recording;
- admin and sys admin attention queues can query current state efficiently;
- state transitions can be driven by review actions and reaction handlers;
- submission dispatches reactions after commit, not inside answer/question models;
- reaction handlers are idempotent and can be retried safely;
- configured reactions can be changed without changing questionnaire content.

Use the project test runner through Docker:

```bash
docker compose exec web rails test
```

## Open Questions

- Should release manifests include explicit source recording ids for provenance, or are recordable ids enough?
- Should customer assignments point only to a release recording, or also store the source questionnaire recording?
- Should answer recordings be direct children of question recordings, or should repeated answers/version history use a dedicated answer container node?
- Should the first implementation use array order in the manifest, or add explicit `position` values immediately?
- Should the base `Recordable` concern switch from `has_one :recording` to `has_many :recordings` before questionnaire releases are implemented?
- Should submission state point at the reconstructed questionnaire root recording, or should submission create a dedicated submission marker recording?
- Should there also be an assignment-level state model for pre-submission progress?
- Which initial submission state should be used by default: `submitted`, `awaiting_review`, or a state chosen by workflow configuration?
- Should submission reactions be configured per questionnaire release, per assignment, per customer bucket, or through a separate workflow configuration model?
- Should the app use the existing `Event` model only for audit/timeline and introduce a separate workflow outbox for reaction dispatch?

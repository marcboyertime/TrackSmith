# 0005 — User-mediated production tutor as a separate ProductionTutor module

Date: 2026-08-05. Status: accepted.

## Decision

TrackSmith adds a permanent Guide Me tutor implemented as a new Swift package
library, `ProductionTutor`, separate from `ProductionIntelligence` and from the
`ProcessingPlan`/`ModelIntentContract` contracts. The tutor tells the user what
to try manually in Logic Pro; it never operates Logic and never mutates the AU
graph.

## Rationale

- Manual Logic instructions are a different authority class from executable
  TrackSmith DSP graphs. Overloading `ProcessingPlan` or the frozen model
  contracts would blur the execution boundary that all existing validation
  depends on.
- Exact instructions must come from locally validated, versioned,
  provenance-backed procedural knowledge, mirroring how DSP authority already
  works: providers propose bounded symbols; local code materializes actions.
- The tutor is permanent product architecture (the future explanation layer
  for automated modules), so it deserves first-class typed contracts, its own
  bounded persistence, and its own evaluation corpus.

## Constraints adopted

1. Dependency direction: `ProductionTutor` may depend on `AgentCore`,
   `AudioAnalysis`, `PlanSchema`; `ProductionIntelligence` must not depend on
   `ProductionTutor`.
2. Actors are limited to `userManual`, `TrackSmithReadOnlyAnalysis`, and
   `TrackSmithPreviewDemonstration`. There is no "TrackSmith controls Logic"
   actor in v1.
3. Logic locations are versioned semantic references (work area, processor
   identity, control identity, navigation labels); pixel coordinates and
   assumed key commands are prohibited and rejected by validation.
4. Numeric instructions carry a safe starting value, bounded range, unit,
   stop condition, maximum excursion, warning signs, and rollback value, all
   from the reviewed catalog — never from a provider.
5. Destructive Logic workflows (bounce-in-place, replace, flatten, normalize,
   region conversion) are excluded from the tutor happy path.
6. Tutor persistence is a separate checksummed bounded store under
   `Application Support/com.marcboyer.tracksmith/ProductionTutor/`; the frozen
   `ProductionConversationState` schema is not expanded.
7. Feedback is an immutable event stream; the next lesson state is produced by
   a deterministic reducer, so identical histories always produce identical
   lessons.
8. Evidence mode (`audioGrounded` versus `userReportedOnly`) is explicit and
   user-visible; stale capture authority demotes audio-grounded claims to
   historical rather than silently retaining them.

## Alternatives rejected

- Extending `ModelIntentContract` with manual steps: mixes untrusted provider
  output with instruction authority.
- A chat-transcript tutor UI: hides state, encourages checklist dumps, and
  cannot enforce one-reversible-experiment-at-a-time.
- UI automation as a shortcut: violates the capability-gating rule; any future
  automation remains a separate project with semantic preconditions,
  postcondition verification, permissions, version tests, and rollback.

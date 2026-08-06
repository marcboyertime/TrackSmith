# TrackSmith General Production Tutor v2

Opened 2026-08-06. Machine-readable gate authority:
[`research/evaluation/general-production-tutor-v2/ledger.json`](../research/evaluation/general-production-tutor-v2/ledger.json).

Predecessor: Logic Production Tutor v1, closed at an explicitly bounded scope
([closure record](evidence/LOGIC_PRODUCTION_TUTOR_V1_BOUNDED_CLOSURE_2026-08-05.md)).
Nothing Tutor v1 proved or failed to prove is rewritten here.

## The problem this milestone solves

Tutor v1 could only answer one shape of question — troubleshoot a bounded
vocal issue — and only when the wording matched one of 18 enum cases. Its own
closure record names the binding constraint:

> The closed issue vocabulary is the binding constraint. 18 enum cases cannot
> represent the space of ordinary production questions.

General Tutor v2 removes that constraint without giving up the rule that made
Tutor v1 trustworthy.

## The rule that does not change

> **The model may help understand, retrieve, compare, and explain.
> Locally validated knowledge owns exact instructions.**

Breadth is obtained from *reviewed knowledge cards*, never from letting a
model improvise menus, controls, values, or claims. Every exact Logic
instruction still resolves to the versioned procedure catalog. Every material
number is either quoted from a cited reviewed source or comes from a validated
procedure — the answer validator throws otherwise.

## Architecture

```text
open-ended question
  → GeneralTutorRouter          (9 question kinds, 100+ domains, no enum match required)
  → GeneralTutorRetriever       (deterministic lexical ranking over reviewed cards,
                                 typed filters, source diversity, contradiction-aware)
  → GeneralTutorCoordinator     (synthesis + measurement-relevance mapping)
  → GeneralTutorAnswerValidator (citation coverage, uncited-number rejection,
                                 forbidden claims, audio-influence honesty)
  → GeneralTutorAnswerContract  (direct answer, assumptions, first move,
                                 strategy options, tradeoffs, sources, limits)
```

The Tutor v1 issue vocabulary is retained as a fast path: when it matches, the
answer can carry exact validated procedures. When it does not, the answer is a
source-grounded strategy rather than a refusal.

### Knowledge model

Five typed card kinds, each versioned with machine-auditable provenance:
`ProductionKnowledgeClaim`, `ProductionStrategyCard`, `ProductionConceptCard`,
`ContradictionRecord`, and `SourceRegistryEntry`, plus `PersonalOutcomeRecord`
for user-confirmed results that must never generalize.

Evidence classes are never flattened into one score: `documentedBehavior`,
`measuredBehavior`, `technicalInference`, `professionalPracticeHeuristic`,
`subjectivePreference`, `userConfirmedPersonalResult`, `provisionalResearch`,
`unresolvedOrDisputed`.

### The audio-honesty fix

Tutor v1 could display a capture as evidence that never influenced the lesson.
`MeasurementRelevanceMap` now maps domains to the metrics that can actually
support them. An answer records exactly which measurements influenced it, and
the validator throws if the answer says the audio informed it when no metric
did. "A capture is available, but no measurement it provides can resolve this
question" is a first-class, expected outcome.

## Gates

| Gate | Name | Status intent |
|---|---|---|
| GP0 | Frozen Tutor v1 baseline and broad-product gap map | Baseline + question library + gap map |
| GP1 | Open-ended question contract and router | No enum match required to answer |
| GP2 | Lawful source-acquisition and review pipeline | Registry + review states + rights/transcript rules |
| GP3 | General production knowledge graph and retrieval | Typed cards + deterministic retrieval |
| GP4 | Grounded answer synthesis and exact-instruction validation | Citations, numbers, refusals |
| GP5 | Adaptive general tutor workflow and native UI | Guide Me extended to open questions |
| GP6 | Personalization and confirmed-outcome memory | Explicit, local, deletable |
| GP7 | Broad evaluation, adversarial, and regression evidence | Corpus + evaluator + regressions |
| GP8 | Real-project and direct Logic validation | Owner sessions + in-host procedures |
| GP9 | Closure and Vocal Module v1 implementation handoff | Evidence-grounded handoff |

No gate is marked passed without named artifacts and executed checks.

## Explicit exclusions

- No provider-authored menu paths, key commands, plug-in identities, control
  names, numeric values, project state, or claimed actions.
- No promotion of research results to trusted knowledge without review.
- No full public transcript or video payload committed to the repository.
- No claim of audiovisual review when only captions were read.
- No claim of direct Logic verification from documentation alone.
- Vocal Module v1 implementation does not begin in this milestone.

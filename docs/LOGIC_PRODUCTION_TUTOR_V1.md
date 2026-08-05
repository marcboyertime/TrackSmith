# TrackSmith Logic Production Tutor v1

Opened 2026-08-05. Machine-readable gate authority:
[`research/evaluation/logic-production-tutor-v1/ledger.json`](../research/evaluation/logic-production-tutor-v1/ledger.json).

## Product decision

TrackSmith adds a permanent **Guide Me** mode beside the existing
**Create For Me** mode.

- **Guide Me**: the user describes a problem ("I sound nasal") or a desired
  result. TrackSmith presents a short diagnostic summary with competing
  possible causes, then exactly one reversible manual experiment at a time:
  what to do, where in Logic Pro, a validated bounded starting point when a
  value is involved, what to listen for, why the step helps, when to stop,
  what could go wrong, and exactly how to undo it. The user reports
  Better / Worse / No change / Not sure / Not applicable / Cannot find it /
  Done / Undo, and a deterministic reducer selects the next validated step.
- **Create For Me**: the existing capture → analyze → three level-matched
  previews → audition → revise → commit workflow, unchanged.

The tutor is the future explanation/learning layer for Vocal Module v1 and
later automated modules. The long-term relationship is: guide me through doing
it myself; create it for me; explain what you created and teach me how to
reproduce it.

## Central safety and reliability rule

**The model may help understand and rank. Local validated knowledge must
materialize the exact instructions.**

No provider prose ever becomes an exact-step card. Every exact Logic
instruction resolves to a locally validated, versioned, provenance-backed
procedure in the tutor procedural knowledge catalog. Every numeric starting
point and adjustment range is locally bounded. A provider (when one is used at
all) may propose only canonical symbolic IDs — issue kinds, cause categories,
procedure IDs, existing production terms, preservation constraints, and one
clarification — validated by a staged validator before use. The deterministic
offline path must complete the entire nasal-vocal vertical slice with no
network and no credential.

## Scope of the v1 vertical slice

Source: vocal. Primary acceptance scenario: "I sound nasal. Tell me exactly
what to try, step by step, and explain why," plus the paraphrase, constraint,
and adversarial variants listed in the evaluation corpus.

The tutor must understand and preserve these boundaries:

- "Nasal" is a perceived quality, not a proven cause.
- The current `SourceAwareAnalyzer` is descriptive and not phoneme-aware; an
  averaged spectral concentration cannot prove nasality.
- The cause may be performance/vowel formation, microphone position, room,
  existing compression, a static resonance, a time-varying (vowel-dependent)
  resonance, or a combination. Competing hypotheses stay visible.
- A static EQ cut may be wrong when the issue is vowel- or section-specific;
  the tutor says so and records the limitation instead of inventing a fix.
- The natural identity of the voice must not be erased; "do nothing" is a
  valid outcome; rerecording may outperform processing.
- Listening and user feedback remain decisive.

## Architecture summary

New Swift package library `ProductionTutor`
(`packages/ProductionTutor/Sources/ProductionTutor/`), depending on
`AgentCore`, `AudioAnalysis`, and `PlanSchema`. `ProductionIntelligence` does
not depend on `ProductionTutor`. The tutor runs entirely in the companion
process; the AU contributes only its existing bounded capture and connection.

Pipeline:

```text
user request
  → local tutor issue parsing (TutorIssueVocabulary)
  → existing Production Intelligence interpretation where applicable
  → competing cause hypotheses (TutorCauseModel)
  → local procedure retrieval (TutorProcedureCatalog, generated from the
    reviewed versioned artifact research/knowledge/logic-pro-12.3-tutor-procedures.json)
  → deterministic TutorPlanner → TutorLessonValidator → visible lesson
  → immutable user feedback events → deterministic TutorFeedbackReducer
  → next validated step … → completion summary + concepts learned
```

Persistence is a separate bounded, checksummed `TutorSessionStore` under
`Application Support/com.marcboyer.tracksmith/ProductionTutor/`; the frozen
`ProductionConversationState` schema is not expanded.

## Gates

| Gate | Name | Meaning |
|---|---|---|
| T0 | frozen baseline and current-focus record | Verified clean baseline at the recorded HEAD; additive focus record; no historical evidence rewritten |
| T1 | typed tutor contracts and validation | Bounded Codable/Equatable/Sendable tutor domain model, lesson validator, forbidden-claim and authority checks |
| T2 | versioned procedural knowledge and provenance | Reviewed tutor procedure artifact, generator + audit scripts, generated typed catalog, fail-closed validation |
| T3 | deterministic offline nasal-vocal vertical slice | Offline recognition → hypotheses → lesson → all feedback branches → summary, with evaluation corpus and machine-readable artifacts |
| T4 | companion Guide mode and adaptive feedback | Native Guide Me / Create For Me modes, one-step-at-a-time cards, feedback controls, persistence, no Create For Me regression |
| T5 | provider-enhanced interpretation | Optional bounded symbolic tutor proposals behind a staged validator; provider prose never defines an instruction; fails closed offline |
| T6 | persistence, privacy, adversarial, and regression testing | Store round-trip/corruption/redaction, adversarial corpus lanes, all existing portable and native lanes green |
| T7 | direct Logic 12.3 user-mediated validation | The exact manual host scenario with recorded artifacts; cannot be inferred or simulated |
| T8 | closure and Vocal Module v1 handoff | Closure record plus evidence-grounded `docs/VOCAL_MODULE_V1_HANDOFF.md` |

No gate is marked passed without its named artifacts and actual executed
evidence. T7 requires a human operating Logic Pro 12.3 and recording the
checklist artifacts; automation of Logic is out of scope for this milestone.

## Explicit exclusions

- No TrackSmith-controlled Logic actor of any kind (no Accessibility, no
  coordinates, no AppleScript, no key-command injection, no MIDI control).
- No destructive Logic workflow in the tutor happy path (no file editing,
  normalization, flattening, replacement, bounce-in-place, or region
  conversion instructions).
- No claims of access to selected regions, channel-strip state, existing
  inserts, automation, MIDI regions, file paths, or project state.
- No raw audio to any provider; no provider-authored numeric values, menu
  paths, plug-in names outside the registry, control names, or key commands.
- No MIDI editing work (a later milestone).
- Vocal Module v1 implementation does not begin until T1–T6 pass and T7's
  boundary is honestly recorded.

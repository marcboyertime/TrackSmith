# Logic Production Tutor v1 — bounded closure (2026-08-05)

Tutor v1 is closed at an **explicitly bounded scope**. It is not closed as
"all gates passed." This record states exactly what the milestone proved and
what it did not, so General Production Tutor v2 has an honest predecessor.

Source revision at closure: `b2fb62e02cfe08fa88791b0385c08d410b637340` on
`codex/logic-production-tutor-v1`.

## Closed as proven

| Gate | Scope proven |
|---|---|
| T0 | Frozen baseline at `c87cea5`: builds, 72/72 TestRunner Debug+Release, host probe, unsigned native build, realtime heap probe |
| T1 | Typed tutor contracts: 18 issue kinds with negation-aware recognition, 12 cause categories, user-mediated actors, bounded steps, staged lesson validation |
| T2 | Reviewed versioned procedure catalog (8 procedures / 18 steps) with generator, audit script, SHA-256-verified generated Swift, and fail-closed validation |
| T3 | Deterministic offline nasal-vocal slice; 77/77 tutor corpus with no network and no credential |
| T4 | Guide Me / Create For Me native modes, tutor coordinator with no AU command path, step cards, eight feedback controls, bounded persistence — exercised interactively in Logic Pro 12.3 |
| T6 | TestRunner 83/83 Debug+Release, `make verify`, host probe, realtime heap probe, unsigned native build |

## Closed as explicitly bounded (not proven)

**T5 — provider-enhanced interpretation.** The bounded symbolic
`TutorInterpretationProposal` contract and its seven-stage fail-closed
validator are implemented and adversarially tested with mocked payloads
(invented issue/cause/procedure IDs, menu paths, key commands, claimed
actions, and out-of-range values are all rejected). **No live provider was
ever wired into the tutor request path.** The deterministic offline path is
the complete default. Bounded outcome: the *contract* is proven; the
*integration* was never built and is deferred to General Tutor v2, which needs
a materially more capable semantic path anyway.

**T7 — direct Logic 12.3 validation.** Partially executed on 2026-08-05 with
the signed build; see
[`LOGIC_12_3_TUTOR_V1_VALIDATION_2026-08-05.md`](LOGIC_12_3_TUTOR_V1_VALIDATION_2026-08-05.md).
Proven in-host: insert, live capture (14.9 s / 44.1 kHz / 1 ch), the Guide Me
nasal lesson with four competing causes, exact reversible step cards,
deterministic Done/Undo branching across two experiments, an AU graph provably
unchanged, offline operation, checksummed 0600 persistence with a clean
privacy scan, unchanged source SHA-256, restart restore, stale-authority
demotion, and Create For Me preview rendering.

**Not proven, and not claimed:**

- **Owner self-evaluation on a real vocal (acceptance criterion 23).** The run
  used a deterministic generated test signal, not a voice. Every feedback
  answer was chosen to exercise state transitions, not to report perceived
  sound. **Tutor v1 therefore carries no perceptual evidence of any kind.**
- In-host revision, commit, and bypass/restore.
- Logic project save/reload into a fresh AU runtime.
- Thread Sanitizer for the 83-check harness.

**T8 — closure.** This record plus
[`VOCAL_MODULE_V1_HANDOFF.md`](../VOCAL_MODULE_V1_HANDOFF.md).

## What Tutor v1 establishes for its successor

1. The authority split works and is enforceable in code: local validated
   knowledge materializes exact instructions; a model may only propose
   canonical IDs behind a staged validator.
2. A deterministic feedback reducer over immutable events produces reproducible
   lessons — identical histories yield identical lessons, which made a 77-case
   corpus meaningful.
3. Fail-closed knowledge validation (no coordinates, no key commands, no
   destructive actions, mandatory rollback/stop/listening cues, bounded values)
   held across the whole catalog without exception.
4. Evidence-mode honesty is implementable end to end: the UI demoted
   audio-grounded claims to historical when AU authority changed, in host.

## What Tutor v1 proved is insufficient

1. **The closed issue vocabulary is the binding constraint.** 18 enum cases
   cannot represent the space of ordinary production questions. Most recognized
   issues outside the vocal-focused set terminate in an honest
   no-safe-procedure limitation rather than useful guidance.
2. **Eight procedures is a narrow catalog.** Non-vocal sources generalize
   almost entirely to limitations.
3. **The analyzer rarely changed the answer.** Capture presence altered the
   evidence banner but seldom the recommendation — a conceptual gap the
   successor milestone must fix explicitly.
4. **No strategy, concept, comparison, or research response type exists.**
   Tutor v1 answers exactly one shape of question: troubleshoot a bounded
   vocal issue.

## Claim boundary

Tutor v1 proves a narrow, honest, user-mediated tutoring mechanism works
end to end in Logic Pro 12.3 for a bounded vocal scope. It proves nothing
about perceptual usefulness, broad production coverage, or open-domain
question understanding.

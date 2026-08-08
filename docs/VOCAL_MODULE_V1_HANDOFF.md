# Vocal Module v1 — handoff specification

Written 2026-08-05 at Logic Production Tutor v1 bounded closure.

**Evidence status: thin, and stated as such.** This handoff is grounded only
in what Tutor v1 actually produced: the reviewed procedure catalog, the 77-case
corpus behavior, the partial direct-Logic run, and defects found along the way.
It is **not** grounded in repeated real vocal sessions, because none were run.
Fields that would normally be answered by owner usage are marked
`UNRESOLVED — requires owner sessions` rather than guessed.

Vocal Module v1 must not begin implementation on this evidence alone. General
Production Tutor v2 is the milestone expected to supply the missing evidence.

## 1. Which vocal problems recurred

`UNRESOLVED — requires owner sessions.` No real vocal lesson has been run. The
corpus exercises 15 nasal/honky variants and 42 vocal troubleshooting cases,
but those are authored cases, not observed recurrence. Corpus frequency is a
design choice and must not be reported as a finding about the owner's voice.

## 2. Which manual experiments consistently helped

`UNRESOLVED — requires owner sessions.` No `better` feedback has ever been
reported by a human listening to their own vocal. The only feedback events on
record (`done`, `undo`, `done`) were entered to exercise state transitions.

## 3. Which problems were source or performance issues

`UNRESOLVED empirically.` The catalog encodes the *hypothesis* that
performance and microphone position are first-class causes — the nasal
procedure ordering deprioritizes static EQ when the problem is vowel-specific,
and two non-DSP procedures (microphone position, performance openness) exist.
Whether they help in practice is untested.

## 4. Which required static processing versus appeared time-varying

Design-level finding, not measurement: the tutor **refuses** to offer a static
EQ cut when the user reports the problem is vowel- or section-specific, and
instead records the limitation:

> "Safe exact handling of a vowel-dependent resonance is not in the current
> validated knowledge and is recorded as a requirement for Vocal Module v1."

This is the single clearest, genuinely evidence-backed requirement in this
handoff: **the tutor has an explicit, reachable state where it says the right
tool does not exist.** That state is triggered by the `vowelSpecific`
qualifier and is covered by corpus case `nasal-10`.

## 5. Which TrackSmith measurements were useful

Honest answer: **almost none influenced the recommendation.** The context
builder surfaces `vocal_200_500_hz_energy_ratio`,
`vocal_120_350_hz_energy_ratio`, `maximum_third_octave_concentration_ratio`,
and `level_variability_p90_p10_db`, all labeled `doesNotResolve`. They change
the evidence banner, not the chosen procedure. Corpus cases `nasal-01` and
`nasal-13` differ only in evidence mode and produce the same first procedure.

## 6. Which measurements were insufficient

- The analyzer is **not phoneme-aware** and cannot detect vowels, consonants,
  or nasality. This is stated in the product text and enforced by the
  forbidden-claim validator.
- Percentile dynamics over digital silence are ill-defined: an 11.2 s capture
  that was roughly one-third silence reported
  `level_variability_p90_p10_db: 224.1 dB`. Finite and honestly labeled
  `contextual` after the 2026-08-05 fix, but not a meaningful production
  statement. **Any Vocal Module that consumes dynamics metrics must handle
  silence explicitly.**
- Nonfinite series values broke JSON encoding of the whole preview manifest
  until fixed — a reminder that Vocal Module measurement plumbing needs
  silence and edge-case tests before it drives processing.

## 7. Which Logic-native procedures were most valuable

`UNRESOLVED — requires owner sessions.` What *is* known: the compression-emphasis
check is the deterministic first experiment whenever a compressor may be
present, and the Channel EQ resonance search is the fallback when it is not.
That ordering is a product heuristic in `TutorPlanner`, not a measured result.

## 8. What preservation constraints mattered

Encoded and enforced, from reviewed sources:

- The corrective cut is hard-bounded to **−6 dB**; the body-restoration boost
  to **+2 dB**; de-essing to **8 dB** maximum reduction.
- Every mutating step carries preservation checks and an exact rollback, or
  catalog validation rejects it.
- Search boosts are explicitly temporary and must not remain active.
- "Do nothing" is a first-class terminal outcome
  (`tutor.vocal.no-processing-decision.v1`), reachable and corpus-covered.

## 9. What the user repeatedly preferred

`UNRESOLVED — requires owner sessions.` No personal outcome has ever been
recorded. The Tutor v1 store has no personalization schema at all; General
Tutor v2 introduces `PersonalOutcomeRecord` for exactly this gap.

## 10. Which capabilities should be automated first

Ranked by strength of *actual* evidence, not by appeal:

1. **Nothing yet.** The honest recommendation is that Vocal Module v1 should
   not begin until General Tutor v2 supplies confirmed outcome data.
2. If forced to rank on current evidence, the two best-supported candidates are:
   - **Dynamic / vowel-dependent resonance handling**, because the tutor has a
     concrete, reachable, corpus-covered state where it declares no safe
     manual procedure exists. That is a real capability hole, not a guess.
   - **Silence-aware dynamics measurement**, because the 224 dB observation
     and the `-inf` encode defect are reproducible facts.
3. **Explicitly not yet justified:** de-essing improvements, level automation,
   compression automation, ambience, personalized vocal profiles. Each is
   plausible; none has evidence from this milestone.

## What Vocal Module v1 must inherit

- Exact instructions come only from reviewed local knowledge; a model may rank
  and explain but never author values, paths, or controls.
- Every generated change must be explainable and must carry the equivalent
  manual procedure so the user can reproduce or revise it.
- Personal preferences are remembered only on explicit user confirmation and
  never generalized.
- Preservation, stop conditions, and rollback are mandatory, not optional.

## Required before implementation

1. At least 20 real owner vocal sessions with recorded feedback and confirmed
   outcomes (General Tutor v2 gate GP8).
2. A measurement study showing which metrics actually discriminate the vocal
   problems the owner reports.
3. Direct Logic validation of the vocal procedures against a real voice.

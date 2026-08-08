# Current product focus

Status date: 2026-08-06. This record is additive. It changes engineering priority
only; it does not alter, close, weaken, or reinterpret any existing milestone,
gate status, or dated evidence record.

## Active implementation priority: General Production Tutor v2

TrackSmith's active milestone is now
[General Production Tutor v2](GENERAL_PRODUCTION_TUTOR_V2.md): turning the
narrow Tutor v1 vertical slice into a broadly capable production tutor that
accepts an ordinary open-ended question and returns a useful, grounded,
traceable answer — or an honest limitation.

Guide Me and Create For Me remain the two permanent top-level modes. What
changes is what Guide Me can be asked. The tutor no longer requires a question
to match one of 18 issue enum cases; it routes across 9 question kinds and
100+ production domains, retrieves reviewed knowledge cards, and synthesizes a
validated answer. Exact Logic instructions still come only from the reviewed
procedure catalog.

Current engine status (2026-08-06): the open-domain path is implemented and
passes 332/332 corpus cases offline. The native Guide Me surface has **not**
yet been extended to open questions (gate GP5), no external source has been
ingested (GP2 partial), personalization is types-only (GP6 partial), and no
owner session or in-host validation has been run (GP8). See the
[ledger](../research/evaluation/general-production-tutor-v2/ledger.json) for
exact gate status.

### Predecessor: Logic Production Tutor v1 (closed at bounded scope)

Tutor v1 was closed on 2026-08-05 at an explicitly documented bounded scope —
not as all-gates-passed. T0–T4 and T6 passed; T5, T7, and T8 are closed
bounded. It carries **no perceptual evidence of any kind**, and its
[Vocal Module v1 handoff](VOCAL_MODULE_V1_HANDOFF.md) deliberately records
UNRESOLVED wherever owner sessions would be required. See the
[closure record](evidence/LOGIC_PRODUCTION_TUTOR_V1_BOUNDED_CLOSURE_2026-08-05.md).

## Previous priority (historical): Logic Production Tutor v1

TrackSmith now targets two permanent top-level product modes:

1. **Guide Me** — a user-mediated, inside-the-Logic-workflow production tutor.
   The user describes a problem or desired result; TrackSmith tells the user
   exactly what to try manually in Logic Pro, one reversible experiment at a
   time, in simple language, with the reason, what to listen for, when to stop,
   what could go wrong, and how to undo it. The tutor adapts deterministically
   to user feedback (better / worse / no change / not sure / not applicable /
   cannot find it / done / undo).
2. **Create For Me** — the existing TrackSmith workflow: bounded deterministic
   processing alternatives, audition, revision, and explicit commit. This mode
   must not regress.

The first Tutor v1 vertical slice is intentionally narrow: the owner's real
vocal-production problem, "I sound nasal," from request through competing cause
hypotheses, one exact reversible experiment, feedback adaptation, rollback, and
a completion summary that teaches the underlying production principle.

The tutor is permanent architecture, not throwaway scaffolding: it is the
planned explanation and learning layer for Vocal Module v1 and later automated
production modules.

## Milestone bookkeeping

- The machine-readable authority for the new milestone is
  [`research/evaluation/logic-production-tutor-v1/ledger.json`](../research/evaluation/logic-production-tutor-v1/ledger.json).
- The plan is [`LOGIC_PRODUCTION_TUTOR_V1.md`](LOGIC_PRODUCTION_TUTOR_V1.md).
- The architecture decision is
  [`ARCHITECTURE_DECISION_RECORDS/0005-user-mediated-production-tutor.md`](ARCHITECTURE_DECISION_RECORDS/0005-user-mediated-production-tutor.md).

## What this focus change does NOT do

- Production Intelligence v1 remains a frozen predecessor. Its closure record,
  evidence boundary, and identities are unchanged.
- The Production Mastery and Perceptual Evaluation v1 milestone remains open
  with its ledger intact: G0, G1, G1.5, G2, and G4 passed; G3 and G5 pending;
  G6 in progress; G7 pending. None of that unfinished work is marked complete,
  erased, or rewritten by this pivot. Engineering attention moves to Tutor v1;
  the Production Mastery gates remain exactly as their ledger records them.
- No development bundle identifier, Audio Unit component identity, App Group
  identity, plan schema identity, capture identity, provider identity, or
  persisted Production Intelligence conversation identity changes.
- The Audio Unit's real-time contract is unchanged: no model calls, network,
  file I/O, UI, blocking, arbitrary allocation, unbounded loops, or tutor
  lesson generation in the render path.
- Tutor v1 is user-mediated only. TrackSmith does not operate Logic through
  Accessibility, coordinates, AppleScript, key commands, MIDI, or private APIs.

# Current product focus

Status date: 2026-08-08. This record is additive. It changes engineering priority
only; it does not alter, close, weaken, or reinterpret any existing milestone,
gate status, or dated evidence record.

## Active implementation priority: TrackSmith Vocal v1

[TrackSmith Vocal v1](TRACKSMITH_VOCAL_V1.md) is the active implementation
milestone and is **in progress**. That label is sequencing, not evidence that any
Vocal capability, installed build, Logic workflow, listening result, or milestone
gate is complete.

The frozen pre-Vocal baseline is commit `406b446`. At that baseline, the portable
`TestRunner` passed 91/91 ordinary checks in Debug and Release; the isolated
Release/Thread Sanitizer lane passed 92/92 when the optional 14-file BS.2217-2
vector check was enabled. Guide Me and Create For Me both existed, but there was
no typed handoff from a Guide Me result into Create For Me. Any such handoff is
Vocal v1 work, not a capability credited to the baseline.

Post-baseline automated development evidence is recorded in
[`TRACKSMITH_VOCAL_V1_AUTOMATED_VERIFICATION_2026-08-08.md`](evidence/TRACKSMITH_VOCAL_V1_AUTOMATED_VERIFICATION_2026-08-08.md).
Final development-tree Debug and Release `TestRunner` runs each passed 104/104;
the vector-enabled Release/Thread Sanitizer run passed 105/105 with no race
report. The record also bounds the current custom-host, heap-interposer,
synthetic semantic-evaluator, listening-CLI self-check, Tutor-regression, and
native-build observations. V0 and V7 are passed; V1-V6 remain in progress, with
V6 still awaiting final clean source-bound regression evidence. V7 is supported
by the separate signed-install record: the exact arm64 app/AU, entitlements,
registration, installed hashes, out-of-process `auval`, and installed App Group
publication all passed at local Apple Development scope. V8-V9 remain pending.
No automated observation establishes direct Logic validation, real-vocal owner
listening, artistic usefulness, or release completion.

## Open predecessor: General Production Tutor v2

[General Production Tutor v2](GENERAL_PRODUCTION_TUTOR_V2.md) removed Tutor v1's
closed-vocabulary bottleneck without giving provider prose execution authority.
Guide Me accepts ordinary open-ended questions, routes across 9 question kinds
and 100+ production domains, retrieves reviewed knowledge, and returns a validated
answer. Exact Logic instructions still come only from the reviewed procedure
catalog.

Current General Tutor status (2026-08-08):

- The offline evaluation passes 518/518 cases across 99 evaluated domains,
  including 10 multi-turn conversations and 10 retrieval-precision cases.
- The reviewed catalog contains 15 sources, 458 claims, 78 strategies, 12
  concepts, and 2 preserved contradictions. No external or YouTube source has
  been ingested.
- GP5 is passed: the native Guide Me Ask surface accepts open questions and
  renders the validated answer and guided-experiment entry point.
- GP6 is passed: confirmed outcomes are stored locally in a bounded, checksummed,
  atomic 0600 profile with per-item forget and delete-all controls. Personal
  outcomes can only apply bounded local ranking preference and never become
  general knowledge.
- GP0-GP7 are passed. GP8 and GP9 remain pending and owner-blocked. No real
  broad-tutor production-question session or direct Logic validation exists, so
  usefulness is not established.

The machine-readable
[General Tutor ledger](../research/evaluation/general-production-tutor-v2/ledger.json)
is authoritative for those gate states.

### Historical opening checkpoint (2026-08-06)

When General Tutor v2 first became the active priority, the open-domain path
passed 332/332 cases, GP5's native open-question surface was not yet wired, GP2's
pipeline was only partial, and GP6 was types-only. That opening checkpoint is
historical. The later 2026-08-06 ledger evidence—not a retroactive rewrite of the
opening result—records the 518-case expansion and GP0-GP7 passage described above.

## Earlier predecessor: Logic Production Tutor v1

Tutor v1 was closed on 2026-08-05 at an explicitly documented bounded scope —
not as all-gates-passed. T0-T4 and T6 passed; T5, T7, and T8 are **CLOSED
BOUNDED, NOT PASSED**. T7 contains a partial direct Logic run but no owner
perceptual evidence. Its
[Vocal Module v1 handoff](VOCAL_MODULE_V1_HANDOFF.md) deliberately records
UNRESOLVED wherever owner sessions would be required. See the
[closure record](evidence/LOGIC_PRODUCTION_TUTOR_V1_BOUNDED_CLOSURE_2026-08-05.md).

Starting a separate Vocal v1 milestone does not retroactively pass Tutor T7/T8,
General Tutor GP8/GP9, or rewrite that historical handoff.

Tutor v1's historical active focus was the owner's narrow "I sound nasal"
vertical slice: competing causes, one exact reversible experiment at a time,
feedback adaptation, rollback, and a teaching summary. Its architecture remains
useful rather than throwaway scaffolding. The historical plan is
[`LOGIC_PRODUCTION_TUTOR_V1.md`](LOGIC_PRODUCTION_TUTOR_V1.md), and its decision
record is
[`ARCHITECTURE_DECISION_RECORDS/0005-user-mediated-production-tutor.md`](ARCHITECTURE_DECISION_RECORDS/0005-user-mediated-production-tutor.md).

## Permanent product modes

1. **Guide Me** — a user-mediated, inside-the-Logic-workflow production tutor.
   The user asks a problem or goal; TrackSmith returns grounded guidance or an
   honest limitation. Where a reviewed exact procedure exists, it presents one
   reversible manual experiment at a time with the reason, listen-for, stop rule,
   risk, and undo. The tutor adapts deterministically to explicit user feedback.
2. **Create For Me** — the existing TrackSmith workflow: bounded deterministic
   processing alternatives, audition, revision, and explicit commit. This mode
   must not regress.

## Milestone bookkeeping

- The active Vocal plan is [`TRACKSMITH_VOCAL_V1.md`](TRACKSMITH_VOCAL_V1.md).
- The Vocal gate authority is
  [`research/evaluation/tracksmith-vocal-v1/ledger.json`](../research/evaluation/tracksmith-vocal-v1/ledger.json); its dated
  [automated-verification record](evidence/TRACKSMITH_VOCAL_V1_AUTOMATED_VERIFICATION_2026-08-08.md)
  preserves current development evidence separately from the frozen baseline.
- General Tutor gate authority is
  [`research/evaluation/general-production-tutor-v2/ledger.json`](../research/evaluation/general-production-tutor-v2/ledger.json).
- Tutor v1 gate authority is
  [`research/evaluation/logic-production-tutor-v1/ledger.json`](../research/evaluation/logic-production-tutor-v1/ledger.json).
- The Production Mastery and Perceptual Evaluation v1 ledger remains
  [`research/evaluation/production-mastery-v1/ledger.json`](../research/evaluation/production-mastery-v1/ledger.json).

## What this focus change does NOT do

- Production Intelligence v1 remains a frozen predecessor. Its closure record,
  evidence boundary, and identities are unchanged.
- Production Mastery and Perceptual Evaluation v1 remains open with its ledger
  intact: G0, G1, G1.5, G2, and G4 passed; G3 and G5 pending; G6 in progress;
  G7 pending. None of that unfinished work is marked complete, erased, or
  rewritten by this focus change.
- No development bundle identifier, Audio Unit component identity, App Group
  identity, plan schema identity, capture identity, provider identity, or
  persisted Production Intelligence conversation identity changes.
- The Audio Unit's real-time contract is unchanged: no model calls, network,
  file I/O, UI, blocking, arbitrary allocation, unbounded loops, or tutor lesson
  generation in the render path.
- Guide Me is user-mediated only. TrackSmith does not operate Logic through
  Accessibility, coordinates, AppleScript, key commands, MIDI, or private APIs.

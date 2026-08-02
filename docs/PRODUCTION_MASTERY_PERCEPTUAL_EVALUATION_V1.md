# TrackSmith Logic Production Mastery and Perceptual Evaluation v1

Status: active  
Plan version: 1.1  
Opened: 2026-07-27  
Authoritative machine ledger:
[`../research/evaluation/production-mastery-v1/ledger.json`](../research/evaluation/production-mastery-v1/ledger.json)

## Current snapshot — 2026-07-30

G0 frozen baseline, G1 production-judgment failure map, and G1.5 annotated
natural-audio evidence corpus are passed. G2 Logic-native bounded profiling is
in progress; G3 ranked TrackSmith-owned DSP, G4 language evaluation v2, G5
perceptual/workflow evidence, G6 installed-host recovery regression, and G7
closure remain pending.

The accepted G1.5 corpus contains 19 content-addressed captures, 390 identified
PCM assets, 14 TrackSmith annotations, and zero exact leakage across the local
evaluation/holdout boundary. The current Logic 12.3 campaign contains 191
`not_run`, 9 `partial`, and 0 `complete` identities. The current source
also contains validator-gated algorithm-version-1 TrackSmith expander/gate,
fixed-time feedback delay, and bounded algorithmic-room candidates. Their
implementation and custom-host evidence do not close the G3 promotion,
perceptual, or installed-host gates.

## Frozen predecessor

Production Intelligence v1 is a frozen, proven baseline. Its closure record is
[`evidence/PRODUCTION_INTELLIGENCE_V1_CLOSURE_2026-07-27.md`](evidence/PRODUCTION_INTELLIGENCE_V1_CLOSURE_2026-07-27.md).
This milestone may add new evidence and compatible behavior, but it must not rewrite
that record, weaken its proof boundary, or silently change the development bundle,
Audio Unit, App Group, processing-plan, capture, conversation, or state identities.

The pre-expansion checkpoint is
[`evidence/PRODUCTION_MASTERY_V1_BASELINE_2026-07-27.md`](evidence/PRODUCTION_MASTERY_V1_BASELINE_2026-07-27.md).
Every release-candidate gate must compare against it.

## Authority and claim boundary

- The AUv3 owns bounded capture, deterministic real-time DSP, its parameters,
  bypass, and restorable state.
- The companion owns conversation, provider access, analysis, offline rendering,
  preview, audition, revision, evidence presentation, and durable conversation state.
- App Group messages remain typed, instance-bound, runtime-bound, capture-bound,
  correlated, bounded, and fail-closed.
- Providers may propose semantic interpretations and bounded hypotheses. They do not
  emit executable DSP, access raw audio, manipulate Logic, access arbitrary files,
  change AU state, override locks, or invent measurements.
- Every audible graph remains TrackSmith-generated, `PlanValidator`-gated,
  deterministic, editable, source-preserving, and recoverable.
- Documentary behavior, professional-practice heuristics, TrackSmith measurements,
  inferred consequences, and listening results remain separate provenance classes.
- Logic-native knowledge remains advisory and grants no host-control authority.
- Objective measurements are guardrails and evidence, never proof of artistic
  superiority. Listening results are task-, source-, listener-, and protocol-bound.
- Resynthesis, arbitrary timbre transfer, generative sound design, first-class MIDI
  transformation, ARA, and speculative Logic project control are outside this plan.

## Evidence gates

Work advances only in this order. A later gate may be developed behind an explicit
feature boundary, but it cannot be promoted while an earlier gate is failed.

### G0 — frozen baseline

Pass condition:

- exact revision, tracked-source digest, clean worktree, installed identities, signed
  entitlements, AU component identity, and App Group identity recorded;
- Debug, Release, Thread Sanitizer, three AudioUnitHostProbe modes, heap interposer,
  native Xcode build, installed `auval`, production-language knowledge, Logic
  knowledge, empirical campaign, deterministic fixture, research-corpus,
  source-preservation, state, preview, revision, commit, rollback, and IPC gates pass;
- any deviation from the predecessor record is diagnosed and retained honestly.

Status: passed at plan opening. See the baseline record and ledger.

### G1 — production-judgment failure map

Build one case-level map across vocal, drums/drum buses, bass, guitar, synth/keys,
and full mixes. Cases must include source and role, recording/processing condition,
intended outcome, preserved/prohibited attributes, competing interpretations,
current executable and analysis coverage, missing evidence/capability, clarification
policy, revision expectation, listening decisiveness, and no-processing/non-DSP
possibility.

The map must distinguish directly curated, research/practice-derived, adversarial,
and generated-augmentation provenance. Generated paraphrases are never counted as
independent human evidence. Ranking uses:

1. meaningful request coverage;
2. expected musical value;
3. preservation and collateral-change risk;
4. uncertainty and missing evidence;
5. implementation and evaluation cost only as a tie-breaker.

Exit artifacts:

- `research/evaluation/production-mastery-v1/failure-map.json`;
- a reproducible audit summarizing provenance, source, condition, outcome, ambiguity,
  revision, capability-gap, and listening counts;
- a ranked capability decision recorded in the authoritative ledger.

### G1.5 — annotated natural-audio evidence corpus

Before additional Logic-native profiles or downstream DSP/language/listening
promotion, build a bounded natural-audio corpus because the generated PCM fixtures
cannot represent musical distribution, arrangement interaction, recording defects,
full-song continuity, or human production language.

This is an evaluation-evidence gate, not a training-data land grab. Acquisition is
ranked by material contribution to accepted cases:

1. multitrack datasets with aligned raw recordings, processed stems, mixes, source
   roles, genres, bleed/activity, or section-level annotations;
2. independent known-stem song-scale datasets for reconstruction, cross-track,
   leakage, preservation, and long-form tests;
3. audio-grounded producer conversations and natural music-language datasets;
4. a bounded AudioSet metadata/feature subset for event, noise, and source-presence
   adversarial coverage only.

Every retained payload or link record must declare canonical identity, exact
retrieval identity, version, rights basis, handling class, local-only status,
redistribution boundary, intended evaluation role, limitations, bytes, and SHA-256.
Dataset, annotation, code, model-weight, and underlying-media rights remain separate.
Access-gated or ambiguous material is not silently mirrored or treated as accepted.
Large or restricted payloads remain ignored local research material; tracked
manifests, schemas, indexes, audits, and derived non-audio measurements preserve
reproducibility without publishing the source media.

The TrackSmith overlay must keep these labels distinct:

- dataset-supplied event, source, instrument, activity, pitch, genre, and language;
- mechanically derived PCM integrity, alignment, reconstruction, section, and
  objective measurements;
- directly curated source/role/condition and evaluation-case selection;
- desired, preserved, prohibited, ambiguous, no-op, and non-DSP judgments;
- subjective listening results from real named protocols and non-invented
  participants.

No dataset-supplied label is production preference ground truth. No raw audio is
uploaded to the current providers. No dataset is used for training, shipping, or
redistribution unless that use receives a separate explicit rights decision.

Exit artifacts:

- `docs/evidence/PRODUCTION_MASTERY_V1_AUDIO_EVIDENCE_CORPUS_ACCEPTANCE_2026-07-28.md`;
- `research/evaluation/production-mastery-v1/audio-evidence-corpus/dataset-manifest.json`;
- a rerunnable acquisition ledger with immutable source and artifact hashes;
- a machine-audited natural-audio index and TrackSmith annotation schema;
- duplicate, split-leakage, PCM-integrity, alignment, reconstruction, and coverage
  reports where the retained payload supports them;
- at least one accepted natural multitrack/stem lane and one accepted
  audio-language lane, or an explicit access/rights record plus a validated
  license-compatible substitute;
- a corpus-to-failure-map trace showing which accepted cases, processor priorities,
  DSP fixtures, language cases, and listening tasks the material improves.

Status and evidence live only in the milestone ledger. The partially captured Space
Designer run was checkpointed without promotion before this gate began.

### G2 — Logic-native bounded production profiles

Extend the existing
`research/knowledge/logic-pro-12.3-empirical-campaign.json`; do not create a second
campaign. Direct Logic evidence must use
[`LOGIC_NATIVE_EMPIRICAL_MEASUREMENT_PROTOCOL.md`](LOGIC_NATIVE_EMPIRICAL_MEASUREMENT_PROTOCOL.md)
and its generated PCM fixtures.

Priority remains:

1. Channel EQ;
2. Compressor and production-relevant Vintage modes;
3. DeEsser 2;
4. Noise Gate;
5. ChromaVerb and Space Designer;
6. Stereo Delay, Tape Delay, then Echo;
7. core saturation/distortion/clipping/Bitcrusher behavior;
8. Adaptive Limiter and essential mastering tools;
9. stereo, phase, correlation, and imaging tools;
10. pitch and vocal tools.

A `complete` or bounded production-profile promotion requires every dimension in the
identity's declared campaign profile. Narrower runs remain `partial`. Every run
retains exact Logic/macOS/hardware/project/native-state identity, fixture and artifact
hashes, settled/repeated/bypass/transition/reload evidence, method, tolerances,
uncertainty, rejected attempts, listening boundary, and source-preservation proof.

Logic interaction is manual only. TrackSmith will prepare exact fixtures, project
settings, parameter sheets, filenames, and validation commands before requesting
physical interaction, then verify returned bytes rather than accepting a verbal pass.

Minimum milestone acceptance is the bounded profile set named in the goal:
Channel EQ, Compressor, DeEsser 2, one algorithmic and one convolution reverb, two
delay/echo processors, one nonlinear path, one primary limiter, and one stereo/phase
tool. The ledger must state tested and unknown dimensions for each.

### G3 — ranked TrackSmith-owned deterministic DSP

Select modules from G1, not catalog completeness. Reverb and delay are the default
pair unless the failure map shows a stronger outcome. Add at least one of dynamic EQ,
transient shaping, or gate/expander. M/S EQ and fixed-lookahead true-peak limiting are
optional unless an accepted evaluation case requires them.

Every promoted module requires:

- typed, bounded, versioned plan parameters and strict validation;
- deterministic offline rendering and borrowed-buffer AU processing;
- offline/realtime parity across irregular blocks;
- state round-trip/migration, reset, bypass, nonfinite, rate, and layout tests;
- explicit transition/smoothing behavior;
- bounded CPU/memory with no callback allocation, file/network/log/UI work, locks,
  blocking synchronization, or unbounded loops;
- source-preserving preview/commit, exact rollback, and fail-closed unsupported plans;
- unit, integration, adversarial, state, host, heap, and listening fixtures.

TrackSmith-owned algorithms have their own names and evidence. Logic measurements may
inform expectations and comparisons but never establish clone equivalence.

### G4 — production-language evaluation v2

Extend the current 420-case foundation to at least 1,000 meaningful cases with:

- at least 120 multi-turn revision sequences;
- at least 100 preservation/prohibited-change cases;
- at least 100 genuinely ambiguous cases with competing valid interpretations;
- at least 75 genre/era/role-dependent cases;
- at least 75 metaphorical, emotional, or nontechnical cases;
- at least 50 non-DSP arrangement/recording/performance cases;
- at least 50 unsupported or unsafe cases;
- long ancestry/lock/merge/remove/restore/stale-identity conversations.

Counts may overlap. Trivial permutations and generated paraphrases are not independent
evidence. Evaluation covers interpretation, applicability, hypotheses, clarification,
preservation, prohibited changes, capability honesty, non-DSP diagnosis, reference and
lock resolution, temporal/attribute scope, revision accuracy, stale-result rejection,
provider disagreement, and offline fallback.

No brittle phrase-to-preset mapping may be introduced to pass the corpus. Ambiguous
terms retain competing hypotheses and listening-decisive boundaries.

### G5 — perceptual and workflow evidence

Add a native artifact generator and analyzer for controlled A/B/C or MUSHRA-style
studies. MUSHRA terminology is used only when hidden-reference, anchor, training,
randomization, reproduction, and statistical requirements are met. Ordinary creative
choices use an auditable randomized level-matched A/B/C protocol.

Every result records:

- anonymous participant and experience class without invented people;
- source/excerpt provenance, monitoring context, level-match method, condition order,
  hidden duplicates/anchors, and task wording;
- target success, preservation, naturalness, clarity, production value, excitement,
  preference, and confidence as separate responses;
- raw responses, exclusions fixed before analysis, medians/IQRs, effect sizes,
  confidence intervals, and corrected pairwise comparisons where justified;
- no universal production-truth claim.

Human participation is requested only after fixtures and exact protocols are ready.

### G6 — installed-host and recovery regression

For an accepted release candidate, rerun G0 plus:

- new-node state restore in the production AU;
- installed signed binary and App Group verification;
- `auval`;
- direct Logic capture, preview, revision, lock, exact commit, bypass/restore,
  save/reload, provider-offline playback, instance isolation, and unchanged source;
- representative listening cases and exact approved-result recovery.

No host result is inferred from custom-host success.

### G7 — closure

Closure requires:

- all required gates passed with immutable artifacts;
- all material failures and rejected attempts retained or referenced;
- one criterion-by-criterion audit with bounded claims;
- frozen predecessor evidence unchanged;
- clean source revision and exact installed/evidence identities;
- no unresolved regression in Production Intelligence, DSP, AU, App Group IPC, state,
  security, preview, revision, commit, rollback, save/reload, or source preservation.

## Ledger discipline

`research/evaluation/production-mastery-v1/ledger.json` is the sole milestone status
ledger. Documentation may explain evidence but must not carry a conflicting status.
Every substantive claim names an artifact, command/run record, listening result, or
external source and one provenance class:

- `frozen_predecessor_evidence`;
- `documentary_source`;
- `professional_practice_heuristic`;
- `tracksmith_measurement`;
- `inferred_consequence`;
- `subjective_listening_result`;
- `product_decision`.

Historical evidence is append-only in meaning: corrections are new records that
reference the earlier claim rather than rewriting what an earlier run proved.

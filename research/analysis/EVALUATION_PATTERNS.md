# TrackSmith evaluation patterns

Status: source-grounded evaluation design, batch 1  
Evidence cutoff: 2026-07-16  
Applies to: semantic interpretation, analysis, deterministic DSP, reference use,
cross-track reasoning, repair/separation, preview/revision, and future model providers

## Governing rule

Every evaluation must name the claim it can support. A conformance vector can
validate a measurement implementation. A waveform residual can validate
deterministic replay. A feature metric can show movement along that feature. A
controlled listening study can support preference or appropriateness for its
tested material and listener population. None of those results can be silently
promoted into “TrackSmith behaves like an excellent producer.”

The minimum evidence chain for an executable behavior is:

```text
source claim and scope
-> typed interpretation expectation
-> source-aware observation expectation
-> bounded hypothesis and preservation expectation
-> deterministic plan invariants
-> exact preview/commit render invariants
-> technical guardrails
-> controlled listening/workflow evidence where the claim is perceptual
```

The current architecture already provides the correct seams:

- `AgentCore` represents vocabulary, intent, evidence, hypotheses, plans, and
  deterministic revision;
- `AudioAnalysis` owns measurements and their source/capture conditions;
- `DSPCore` owns deterministic execution;
- `PreviewRenderer`, `PreviewWorkflow`, and `PreviewAudition` preserve exact
  candidates and synchronized comparison;
- `ProductionIntelligence` owns bounded context, provider validation,
  conversation state, and revision; and
- `SessionCore` preserves workflow identity and project persistence.

This document recommends evaluation additions, not core architecture changes.

## Claim-to-evidence matrix

| Claim | Minimum valid evidence | Required controls | What a pass does not establish |
|---|---|---|---|
| Loudness/true-peak implementation is conformant within stated scope | Official standard plus publisher test vectors | Declared sample rate/layout/profile, numerical tolerance, exact algorithm/version | Musical quality, preferred loudness, every layout or renderer |
| Render is deterministic and reversible | Repeated byte/sample comparison plus persisted-plan replay | Same source snapshot, sample rate, channel layout, graph version and state | Artistic correctness |
| A requested attribute moved | Valid scoped descriptor plus before/after direction | Representative window, level control, uncertainty and preservation checks | That the result is preferable or that the descriptor fully represents the term |
| Processing preserved a locked trait | Trait-specific technical and/or listening check | Exact locked scope, meaningful adverse fixture, no-op baseline | Preservation of every unmeasured property |
| Reference matching succeeded | Test matched to the reference problem class | Same-content versus different-content route, explicit target/preserve/prohibit dimensions | Recovery of original settings or artistic intent |
| Cross-track processing helped | Role-aware multitrack comparison and listening | Protected role, no-op, pairwise and whole-mix context, loudness control | That spectral overlap was harmful in general |
| Repair removed a defect | Selection-scoped defect measure plus residual audition and listening | Untouched-region null, artifact anchor, exact selection, latency alignment | General restoration quality or successful source separation |
| Estimated stem is usable | Separation metrics plus role-specific leakage/artifact listening | Mixture reconstruction, known stems where available, original-stem baseline | That it is the original stem |
| Semantic interpretation is correct | Human-labelled intent cases with accepted alternatives | Source/genre/context, negation, preservation, ambiguity and paraphrase | That the chosen DSP sounds good |
| Explanation is calibrated | Fact-level provenance audit and user comprehension task | Counterfactual/abstention cases, hidden ground truth, no fabricated mechanism | Preference for the audio result |
| Workflow improves production | Controlled task study and longitudinal field evidence | Same DAW/task, experience strata, time, revisions, final blind audio rating | Universal producer behavior |

## Lane 1 — source integrity and evidence traceability

### Purpose

Prevent a technically correct result from resting on a missing, corrupted,
duplicate, misclassified, or weakly reviewed source.

### Required checks

1. Canonical URL, immutable local bytes or explicit metadata-only status, SHA-256,
   media type, retrieval date, source version, rights status, and review depth are
   present in `SOURCE_INDEX.jsonl`.
2. Quarantine paths never enter the source ledger, bibliography, corpus index, or
   synthesis references.
3. Patent international copies are attached to one invention family before
   landscape counts are computed.
4. A conclusion records evidence class and source scope. A marketing page cannot
   supply a peer-reviewed result; a tutorial cannot become a normative rule.
5. Every product or engineering consequence resolves to a source/review record,
   a TrackSmith hypothesis label, and an acceptance test.

### Pass condition

The source -> review -> conclusion -> requirement -> candidate implementation ->
test path can be reconstructed without guessing from a filename or prose title.

## Lane 2 — semantic interpretation and ambiguity

### Dataset design

Extend `TRACKSMITH_PRODUCTION_INTENT_CORPUS_V1.json` with cases that vary one
factor at a time:

- source type and musical role;
- genre/aesthetic context;
- desired, preserved, and prohibited attributes;
- reference scope;
- strength and time scope;
- negation and contrast (“brighter, but not harsher”);
- revision/coreference (“keep version two's vocal, but use version one's drums”);
- incompatible requests;
- insufficient evidence and valid abstention; and
- two or more equally plausible interpretations.

### Metrics

Report exact and partial scores separately:

- desired term/direction/strength;
- preservation and prohibition recall (safety-critical, never averaged away);
- source/role/scope binding;
- reference-problem class;
- ambiguity detection;
- correct clarification versus correct multi-candidate route;
- provenance/evidence-class correctness;
- unsupported-claim and invented-mechanism rate; and
- deterministic replay across provider responses.

Do not collapse these into one semantic-accuracy number. A system that identifies
“bright” but drops “do not thin the vocal” has failed the request.

### Adversarial cases

- paraphrases with opposite preservation constraints;
- adjectives whose production consequence changes by source and genre;
- emotionally plausible but acoustically underdetermined requests;
- misleading references with unrelated arrangement or source role;
- prompt injection inside source metadata;
- provider response with valid JSON but unsupported DSP nodes;
- high-confidence explanation contradicted by measured evidence; and
- a request where no processing is the strongest candidate.

## Lane 3 — measurement validity

Each metric needs a `measurement contract`:

```text
metric identity and normative/profile version
input domain and channel/layout assumptions
minimum/representative observation requirement
window, gating, filtering and aggregation definition
known instability and failure conditions
numerical tolerance and test vectors
allowed inference
prohibited semantic inference
```

For the existing loudness work, keep the established distinctions:

- BS.1770 Integrated Loudness, EBU Mode Short-term, EBU rectangular Momentary,
  LRA, true peak, crest factor, spectrum, and sample peak are different facts;
- LRA below sixty seconds remains explicitly unstable under TrackSmith's current
  conservative product policy;
- broadcast delivery targets are profiles, not universal music aesthetics; and
- passing the retained BS.2217 vectors validates only the implemented cases.

Source-aware descriptors must be tested on counterexamples. A sibilance detector
needs sustained cymbal/air false-positive cases. A punch descriptor needs kick,
snare, bass, guitar and full-mix cases where onset-to-body relationships mean
different things. A masking descriptor needs intentionally layered, doubled,
chorused, distorted, ambient and lo-fi material where overlap is desired.

## Lane 4 — reference problem routing

The academic batch requires separate fixtures for at least six routes.

### A. Matched-content inverse recovery

Use the same aligned content and a declared processor class. Generate known gain,
FIR/EQ, delay, polarity, compression, and bounded effect-chain transforms.

Report:

- alignment and polarity result;
- condition number and rank;
- parameter error and bound violations;
- time/frequency residual;
- state-continuity error;
- model-mismatch diagnosis; and
- deterministic replay.

Reject or abstain on missing stems, collinearity, misalignment, undeclared
nonlinearity, physically invalid coefficients, or residual above the declared
model tolerance.

### B. Paired transformation learning

Use aligned input/output pairs with separate songs for train, validation and
test. Clone processor state for perturbation evaluations. Test continuous and
discrete controls, parameter interactions, delay, sample rate, stereo state,
long release/tail behavior, cancellation and plug-in failure.

This lane can validate an offline candidate initializer. It cannot validate
unpaired reference matching or creative judgment.

### C. Synthetic same-song style recovery

Apply known bounded graphs to different sections of one song, retain ground-truth
parameters, and vary whether a single static style is actually appropriate.
Include automation and deliberately different verse/chorus treatments so the
system can learn to reject the shared-style assumption.

### D. Different-content scoped reference

Human annotators must state which traits matter, which must be preserved, and
which are incidental. Include compatible and incompatible source roles,
arrangements and genres. Score each trait separately, include a no-op and simple
deterministic baselines, and use listening to decide appropriateness.

### E. Cross-track relationship control

No external reference is required. Bind every proposal to a protected or leading
role and an explicit context mechanism. Swap roles while keeping the waveforms
unchanged: the measurements should remain stable while the recommendation can
change. This proves that context is not being smuggled into an acoustic metric.

### F. Provenance reconstruction

Given a committed render, query back to source snapshot, selected evidence,
hypothesis, candidate, plan nodes, implementation version, parameters, revision,
and commit. Missing lineage is a failure even if the waveform is correct.

## Lane 5 — deterministic DSP and real-time safety

### Invariants

- same source snapshot plus same serialized plan produces identical samples;
- bypass nulls within declared precision and latency alignment;
- preview samples equal the freshly rendered persisted commit graph;
- a revision changes only authorized nodes and retains locked nodes;
- parameter bounds, smoothing, finite values and stable state are enforced;
- no model, network, file I/O, lock contention, or allocation occurs in the
  real-time audio thread;
- denormal, silence, impulse, step, full-scale, NaN/Inf, channel-layout and sample-
  rate cases are covered; and
- cancellation or failure leaves the last committed state intact.

### Effect-specific tests

| Operation | Technical tests | Perceptual/preservation tests |
|---|---|---|
| Static/dynamic EQ | magnitude/phase response, coefficient stability, automation smoothing, overshoot | timbral direction, transient/body preservation, mono translation |
| Compression/level riding | detector/ballistics, gain-reduction bounds, stereo linking, pumping fixtures | punch, groove, sustain, phrase shape, loudness-controlled preference |
| Limiting | sample/true peak, oversampling, release recovery, distortion/delta | loudness bias, transient loss, low-end distortion, fatigue |
| Saturation | harmonics/aliasing, DC, oversampling, level dependence | density/character versus harshness, transient preservation |
| Reverb/delay | impulse/tail, decay stability, latency, feedback bounds | depth, masking, intelligibility, groove, desired imperfection |
| Stereo operations | correlation, mono null/delta, channel symmetry, phase | center focus, width, source stability, translation |
| Repair/de-ess | selection boundaries, residual, false positives, untouched-region null | defect removal versus lisping, dullness, musical-noise and ambience loss |

The current real-time heap interposer result and deterministic preview/commit
tests remain strong implementation evidence. They do not substitute for the
effect-specific perceptual lanes.

## Lane 6 — audition validity

### Required comparison modes

1. **Task-faithful:** retains any requested level change and answers whether the
   whole requested result is effective.
2. **Loudness-controlled:** removes level advantage so timbre, dynamics, space and
   artifacts can be judged.
3. **Delta/residual:** auditions the aligned difference for limiting,
   compression, repair, de-essing or unmasking when meaningful.
4. **Context/solo:** switches between isolated source and whole-mix context;
   neither alone is sufficient.
5. **Mono/translation:** tests collapse and declared playback conditions.

TrackSmith's current preview path materializes its measured loudness compensation
into the persisted graph so audition and commit are identical. That is a strong
reproducibility property. Product evaluation must still report both task-faithful
and loudness-controlled results because the matched graph intentionally changes
the committed level.

### Switching controls

- all candidates start from the same sample position;
- switch latency and fades are consistent and click-free;
- labels can be hidden and order randomized in formal tests;
- the source, no-op, conservative proposal, alternatives and meaningful degraded
  anchor are available;
- no candidate clips after comparison gain; and
- the user can return to every earlier version without relearning.

## Lane 7 — technical guardrails versus artistic success

Use a vector, not a single quality score:

```text
technical = [finite, truePeak, samplePeak, DC, clipping, phase, mono,
             loudnessValidity, stateContinuity, renderBudget]
preservation = [lockedTerms, untouchedRegions, transient, dynamics,
                spectralBounds, stereoBounds, ambience, sourceRole]
intent = [requestedDirection, strength, timeScope, referenceScope]
complexity = [nodeCount, changedParameters, automationDensity, latency]
perceptual = [appropriateness, preference, artifacts, coherence, confidence]
```

A candidate with a hard technical or preservation failure is rejected. Remaining
candidates form a tradeoff set; they are not collapsed into one scalar unless the
weighting and its evidence are explicit. A technically clean no-op remains a
valid result.

## Lane 8 — repair, separation, and generated assets

### Repair

- preserve exact selection/time/frequency scope;
- null untouched regions;
- compare several settings and include removed-signal audition;
- use known-defect synthetic fixtures and natural defects;
- rate residual defect, collateral loss, modulation/musical noise and ambience;
- test duration/compute boundaries; and
- keep original bytes and every accepted render.

### Separation

- use known-stem mixtures where possible;
- report scale-invariant separation metrics only as technical descriptors;
- test leakage by source role and time-frequency event;
- reconstruct the mixture and report residual;
- include human ratings for usefulness and artifacts in the intended edit;
- identify sensitivity/model/version; and
- serialize output as `estimatedStem`, never `originalStem`.

### Generated assets

- create a new asset identity with provider/model/version/input/seed/parameters;
- test musical timing, pitch/harmony, source identity, artifacts, continuity and
  user intent;
- disclose provider and data path before a cloud call;
- require explicit audition/import/commit; and
- never insert generated media as an invisible deterministic DSP node.

## Lane 9 — long-form and multitrack coherence

Short clips dominate much of the reviewed research. TrackSmith needs a separate
song-scale lane:

- verse, chorus, bridge, intro, outro, breakdown and transition coverage;
- sparse versus dense arrangement sections;
- automation continuity and tail/state carryover;
- whole-song loudness and section-relative dynamics;
- focal-source continuity and intentional hierarchy changes;
- repeated motif consistency without forcing static processing;
- CPU/memory and cancellation on full-length renders; and
- regression after a local revision: unrelated sections remain unchanged unless
  the hypothesis explicitly has whole-song scope.

Report both per-section and song-level results. Averages can hide a failed vocal
entrance, pumping breakdown, clipped transition or destroyed quiet section.

## Lane 10 — human listening and production workflow

### Listening study selection

Use the method that matches the claim:

- **paired preference/ABX** for small specific differences or detectability;
- **multi-stimulus rating** for several candidates on separate attributes;
- **MUSHRA** only when its reference, anchors, training, randomization, panel and
  reporting requirements actually apply; and
- **expert task evaluation** for diagnosis, revision, stopping, explanation and
  DAW workflow.

Always report listener population, experience, monitoring, playback level,
material selection, duration, sample-size rationale, exclusions, randomization,
statistics, effect sizes and uncertainty. Separate intent match, artifact level,
preservation, appropriateness and overall preference.

### Workflow outcomes

- time to a first auditionable proposal;
- number and type of revisions;
- ability to revise one element without collateral change;
- error recovery and version return;
- final blind audio rating independent of speed;
- comprehension of explanation and limits;
- trust calibration: reliance when correct and rejection when wrong;
- educational visibility without forced complexity; and
- longitudinal reuse, override and abandonment patterns.

A faster workflow with a worse final result is not a win. A preferred result that
requires opaque irreversible state is not sufficient for TrackSmith either.

## Lane 11 — competitor black-box protocol

When lawful trials or existing installations are available, use identical,
reproducible input packages:

1. preserve source bytes, stems, mix, references and project notes;
2. record product, exact version, OS, host, sample rate, buffer, account tier and
   network state;
3. run recommended onboarding, then controlled variations of section, profile,
   genre, reference and intensity;
4. export every result and screenshot/document user-visible settings;
5. record analysis time, render time, latency, CPU/memory, data upload and failure;
6. loudness-normalize separate listening copies while preserving raw outcomes;
7. measure technical vectors and residuals;
8. conduct blinded evaluation with no-op and simple TrackSmith baselines; and
9. never infer proprietary implementation from the output alone.

Test adversarially but fairly: wrong profile, too-short selection, silence,
already-mastered input, extreme genre mismatch, poor reference, intentional
distortion, desired dynamics and intentionally layered sources. Record whether
the product abstains, warns, produces one result, or exposes alternatives.

## Lane 12 — future model/provider evaluation

Provider-neutral reasoning is valuable only if it remains bounded by TrackSmith's
validated contracts.

Evaluate:

- schema validity and unsupported-node rejection;
- fact/provenance precision;
- preservation/prohibition recall;
- ambiguity and abstention calibration;
- prompt paraphrase, negation, injection and adversarial metadata;
- consistency across model/provider/version;
- privacy/data-scope enforcement;
- latency, cancellation, retry and replay safety;
- no network/model activity on the render thread; and
- deterministic plan replay after provider output is gone.

Audio-capable models require additional tests: content/source/role grounding,
temporal localization, calibrated uncertainty, long-form consistency, reference-
scope interpretation, and adversarial cases where semantic similarity conflicts
with audible production quality. An embedding improvement cannot authorize a
commit.

## Release evidence levels

| Level | Meaning | Minimum evidence |
|---|---|---|
| Production-ready | Safe, deterministic bounded behavior whose claim fits existing architecture | source-grounded contract, unit/property/conformance tests, exact preview/commit, guardrails, failure/rollback tests, relevant listening where perceptual |
| Prototype-worthy | Plausible mechanism with bounded scope and clear test | primary evidence, explicit assumptions, offline prototype, baselines, negative cases, no production claim |
| Experimental | High uncertainty, proxy metrics, short clips, synthetic or out-of-domain evidence | isolated evaluation lane, provider/model/version pinning, no automatic commit |
| Deferred | Dependency or evidence is missing | recorded prerequisite and falsifiable entry criterion |
| Rejected | Conflicts with architecture, evidence, safety, or user value | explicit reason and evidence; retained to prevent rediscovery |

## Batch-1 priorities

1. Production-ready: retain exact plan/provenance replay, preservation locks,
   no-op candidates, typed cross-track mechanisms, and reference-scope
   clarification.
2. Prototype-worthy: delta/residual audition, matched-content transform recovery,
   role-aware unmasking candidates, and estimated-stem provenance.
3. Experimental: bounded offline multi-objective DSP search and section-aware
   automation proposals.
4. Deferred: generative assets and audio-capable model judgments until provider,
   rights, privacy, calibration and long-form evaluation contracts exist.
5. Rejected: single scalar “mix quality,” unqualified reference copying,
   automatic processing on every request, speech-to-music quality transfer, and
   any model/network work in the real-time audio thread.

## Source anchors

- Normative measurement/listening sources: BS.1770-5, BS.1771-1, BS.2217-2,
  BS.1534-3, EBU R 128 v5 and Tech 3341/3342/3343, represented in the established
  corpus and `TRACKSMITH_DEEP_SOURCE_SYNTHESIS.md`.
- Reference/optimization sources: the eight full-read records in
  `../metadata/deep-review-batch-1-academic.jsonl` and
  `AUTOMATIC_MIXING_REFERENCE_CONTROL_SYNTHESIS.md`.
- Competitor trust/failure patterns: the 18 review records in
  `../metadata/deep-review-batch-1-competitors.jsonl` and
  `COMPETITOR_LANDSCAPE.md`.
- Current implementation evidence: the existing validation report and tests;
  this research milestone does not alter core product code.

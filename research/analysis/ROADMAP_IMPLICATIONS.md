# TrackSmith roadmap implications

Date: 2026-07-16  
Scope: engineering consequences of the research milestone; sequencing guidance,
not authorization to modify core product code

## Outcome

Research supports the established architecture. The next roadmap should deepen
its decision semantics, evidence lifecycle, audition, and persistence before it
adds opaque model or processor breadth. The dependency order is:

```text
evidence identity
-> interpreted production brief
-> competing typed hypotheses
-> bounded deterministic candidates
-> preservation-aware audition
-> branchable user decision
-> exact persistent project memory
-> contextual retrieval and ranking
-> optional offline optimization or frontier-model assistance
```

Skipping an earlier layer makes the later layer difficult to validate and easy to
overclaim.

## Milestone 0 — finish the research substrate

**Status:** active research milestone  
**Affected tools:** ResearchIngestion, corpus index builder, audit scripts,
knowledge artifacts

### Deliverables

- One source ledger that separates intellectual work from payload, includes
  accessibility and rights state, and overlays deep-review evidence without
  mutating immutable archive manifests.
- Claim-level traceability from source to conclusion, requirement, implementation
  hypothesis, prohibited inference, and test.
- Versioned Producer Judgment Corpus, genre map, language ontology, user-pain
  corpus, patent matrix, competitor matrix, repository matrix, and search/gap
  ledgers.
- Deterministic validation for JSON/JSONL/CSV structure, source-reference closure,
  payload hashes, duplicates, and review-depth claims.

### Exit gate

No roadmap claim may cite an unindexed or inaccessible payload as full-text
evidence. Every machine-readable record must resolve to retained bytes or an
explicit link-only/access-failure record. Category coverage and saturation remain
separate from archive size.

## Milestone 1 — make existing reversible behavior exact and inspectable

**Status:** production-ready principles; implementation after research approval  
**Primary modules:** PlanSchema, AgentCore, PreviewRenderer, PreviewWorkflow,
PreviewAudition, SessionCore, SharedIPC

### 1A. Candidate and revision lineage

Add immutable candidate identity, parent candidate, evidence version, affected
source/time/node scopes, preservation set, unresolved notes, renderer version,
plan hash, input hash, and output hash. A scoped revision declares what it may
change and what must remain identical.

**Tests**

- Branch, compare, merge, bypass, and rollback preserve exact lineage.
- Unaffected sources and sections are sample-identical or within an explicitly
  defined DSP boundary.
- An invalidated analysis cannot silently rewrite a committed branch.
- Migration either reproduces an old plan or creates an audible candidate with
  explicit version change.

### 1B. Falsifiable rationale

Represent observation, metric provenance, confidence, interpretation, competing
hypothesis, preservation risk, candidate action, and audition cue separately.
Provider prose is generated from these fields and cannot introduce an executable
operation not present in the validated plan.

**Tests**

- Contradictory evidence lowers confidence or introduces alternatives.
- Unsupported causal and quality claims fail provider-output validation.
- Routing, sidechain, record-arm, latency, and parallel-phase preflight can explain
  setup-dependent false defects before blaming an intelligent processor.

### 1C. Null plan and preservation budget

Every candidate set may include no change. Plans declare protected traits and
bounded acceptable changes. Identity-bearing timing, noise, distortion, ambience,
overlap, dynamics, and prior decisions are not treated as defects solely because a
metric is unusual.

**Tests**

- Purpose-built useful-noise, live-timing, overlap, dynamics, and rough-mix cases
  retain valid null candidates.
- A preservation failure blocks commit or requires explicit user override.
- Arrangement-level or performance-level mismatch yields clarification or
  abstention rather than cosmetic DSP.

### Milestone 1 exit gate

A user can hear, inspect, revise one element, reject, restore, and reopen every
candidate without losing an accepted state or relying on a model/provider to
reconstruct it.

## Milestone 2 — audition as an evaluation instrument

**Status:** production-ready hardening plus bounded prototypes  
**Primary modules:** PreviewAudition, PreviewRenderer, AudioAnalysis, DSPCore

### 2A. Default loudness-controlled comparison

Provide synchronized A/B/n candidate transport, optional labeled unmatched mode,
deterministic gain-match provenance, looped time selection, and listening-level
metadata. Preference and conformance are separate outcomes.

### 2B. Delta and removed-signal modes

Subtractive EQ, repair, clipping/limiting, denoise, and similar actions expose an
aligned residual when subtraction is meaningful. A residual is described as what
the operation changed, not automatically as damage.

### 2C. Guardrail panel

Show true peak, clipping/non-finite state, loudness, crest/transient change,
low-end allocation, stereo/mono translation, latency, and processor-specific
limits. These are vetoes or warnings, not an artistic quality score.

**Tests**

- Gain-only preference trap.
- Delay, polarity, phase, latency, bypass, and transport alignment.
- Residual arithmetic and selection-boundary behavior.
- Clipper/limiter oversampling and true-peak fixtures.
- Compressor pumping, transient loss, and low-frequency detector sensitivity.
- Stereo-width mono and low-band-side constraints.

### Milestone 2 exit gate

An apparent improvement cannot be accepted merely because it is louder, and a
user can inspect the audible cost of a subtractive operation without leaving the
TrackSmith workflow.

## Milestone 3 — scoped references and long-form evidence

**Status:** prototype-worthy  
**Primary modules:** AgentCore, AudioAnalysis, ProductionIntelligence,
PreviewWorkflow, SessionCore

### 3A. Production brief and reference interpretation

Before planning, store:

- target source, bus, mix, relationship, or time scope;
- desired, preserved, and prohibited traits;
- reference relation: sonic, emotional, structural, performance, contextual, or
  metadata-only;
- feature-specific objectives and their confidence;
- unresolved ambiguity and clarification history.

References never become one hidden target vector. Multiple objectives remain
separate, and contradictory objectives can produce named alternatives.

### 3B. Section map and representativeness

Version analysis by input hash, time range, section label/hypothesis, duration,
and representativeness. Compare quiet, loud, sparse, dense, bridge, intro/outro,
and user-selected sections before applying a global action. Event-conditioned
problems use event scope.

### 3C. Long-form consistency checks

Render candidate automation or static settings across the full relevant duration,
then measure non-target section changes, state continuity, and bound violations.

**Tests**

- Whole-mix versus source-only and section-only references.
- Cross-genre references scoped to one trait.
- Bad, contradictory, mastered/unmastered, loudness-confounded, and unrelated
  references.
- Loud-chorus analysis applied to quiet verse.
- Section-transition and stateful-DSP continuity.
- Per-word dynamic correction inactive outside detected events.

### Milestone 3 exit gate

TrackSmith can explain exactly what a reference or adjective applies to, why a
chosen section is representative, and where a proposed global action fails.

## Milestone 4 — whole-mix and cross-track hypotheses

**Status:** prototype-worthy, dependency-gated  
**Primary modules:** AudioAnalysis, AgentCore, DSPCore, SharedIPC,
ProductionIntelligence

### 4A. Role and interaction graph

Represent source-class probability separately from musical-role hypotheses.
Interactions name the evidence and mechanism: shared metering, sidechain context,
remote control, sequential decision context, or true joint objective. Missing
tracks, uncertain roles, and stem provenance are explicit.

### 4B. Deterministic first capabilities

Start with auditable operations that the current DSP model can express:

- relationship-aware gain or automation candidates;
- optional sidechain-informed dynamic EQ/compression;
- focal-source space candidates through bounded level, panning, width, or dynamic
  interaction;
- explicit no-change when overlap is intentional or evidence is insufficient.

Do not label shared analysis as joint optimization.

### 4C. Group preservation

Each group plan protects focal hierarchy, kick/bass allocation, mono translation,
phase, transients, and unrelated tracks. It reports whether the objective is
separation, cohesion, depth hierarchy, translation, or another user-approved goal.

**Tests**

- Wrong source class versus correct musical role.
- Intentional bass/guitar overlap and dense shoegaze texture.
- Kick/808 fundamental and harmonic translation.
- Lead-vocal placement using multiple valid interventions.
- Missing-track and stale-context handling.
- Track-count, sample-rate, channel-layout, latency, and CPU stress.

### Milestone 4 exit gate

No cross-track edit is proposed without complete mechanism, context, role
confidence, affected graph, preservation checks, and an auditable null baseline.

## Milestone 5 — contextual production-judgment retrieval

**Status:** prototype-worthy after the corpus and ontology stabilize  
**Primary modules:** ProductionIntelligence, AgentCore, SessionCore; offline index

### 5A. Decision-case retrieval

Retrieve cases by problem, evidence heard, source and role, section, genre/era,
artistic goal, arrangement, preservation constraint, alternatives, intervention,
and stopping criterion. Retrieval returns provenance-tagged hypotheses, including
contradictory cases.

### 5B. Contextual language senses

Resolve terms against source, role, genre/aesthetic context, current evidence,
requested strength, reference scope, and prior accepted choices. Keep desired,
prohibited, preserved, referential, and descriptive roles separate.

### 5C. Project-specific memory

Remember accepted interpretations and exceptions inside the project. A later
request may cite them but cannot silently convert a prior choice into a permanent
lock. Cross-project learning remains opt-in and deferred.

**Tests**

- Same term across vocal, drums, bass, guitar, synth, and full mix.
- Same term across conflicting genres and eras.
- Negation, “like X but not Y,” rough-mix locks, evolving feedback, and partial
  revision.
- Retrieval with no close precedent and with contradictory precedents.
- Cases where the correct response is source/arrangement change or no processing.

### Milestone 5 exit gate

Retrieved practice improves hypothesis relevance in blinded tasks without reducing
calibration, increasing unsupported parameter certainty, or turning context into a
preset.

## Milestone 6 — asset-producing repair and separation

**Status:** deferred prototype  
**Primary modules:** new offline asset boundary plus PreviewWorkflow and SessionCore

Estimated stems, repaired regions, reconstructed audio, and generated layers are
new assets. They carry input hash, selection, algorithm/model/checkpoint version,
settings, latency/alignment, known leakage or artifact state, rights/consent, and
an explicit import decision. They never masquerade as original stems or ordinary
reversible DSP nodes.

**Tests**

- Known-mixture leakage and label-swap fixtures.
- Residual and recombination error.
- Percussive, harmonic, distorted, reverberant, and overlapping-source stress.
- Host interruption, cancellation, long-session memory, and project reopen.
- Speech versus music-vocal boundary cases.

### Milestone 6 exit gate

A user can compare, reject, replace, or remove an estimated asset, and the project
always retains the original audio and complete generation provenance.

## Milestone 7 — experimental optimization and future models

**Status:** experimental; never on the real-time thread  
**Primary modules:** ProviderEvaluationHarness, ProductionIntelligence, offline
optimizer boundary, PreviewRenderer

### 7A. Multi-objective offline DSP search

Use bounded deterministic nodes and an explicit objective vector. Possible
initializers include differentiable-console prediction, SPSA for safely cloned
continuous black-box effects, or latent search mapped back to white-box controls.
Retain no-op and manually bounded baselines, Pareto candidates, compute/time budget,
random seed, and exact replay record.

Reject or defer when controls are discrete, state cannot be cloned, latency is
unbounded, a target is unscoped, or the objective lacks preservation terms.

### 7B. Audio-capable provider evaluation

Evaluate provider hypotheses on source diagnosis, ambiguity, reference scope,
preservation, alternatives, revision, and calibrated abstention. Compare against
deterministic analysis plus text context and audio-embedding/ranker baselines.
Fluency and generic benchmark performance do not count as production competence.

### 7C. Private preference learning

Only after candidate generation and listening tests stabilize, evaluate whether
contextual user choices predict later choices. Store interpretable factors and
counterexamples, allow reset and project scope, and test drift. Do not build a
single opaque taste score.

**Tests**

- Objective circularity and adversarial high-score/bad-audio candidates.
- Bad references, out-of-domain sources, extreme parameter boundaries, and stateful
  effects.
- Provider version drift, timeout, malformed output, replay, privacy consent, and
  cost ceilings.
- Expert and non-expert preference, genre familiarity, long-form coherence, and
  correction cost.

### Milestone 7 exit gate

An experimental system materially beats simpler baselines on a bounded TrackSmith
task, while every output remains typed, validated, reversible, provider-versioned,
and subordinate to human audition and deterministic execution.

## Module-level consequence matrix

| Existing module/boundary | Research-supported consequence | Readiness | Prohibited shortcut |
|---|---|---|---|
| `AudioAnalysis` | Version observations by source, time scope, context, confidence, and graph/capture provenance; add interaction and preservation features | Production-ready extensions plus prototypes | Metric directly selects a processor |
| `AgentCore` | Separate brief, intent roles, hypotheses, alternatives, preservation, abstention, and affected scope | Production-ready principle | One adjective-to-chain dictionary |
| `PlanSchema` | Candidate lineage, scope, parameter bounds, preservation contract, exact versions and hashes | Production-ready principle | Provider prose becomes executable authority |
| `DSPCore` | Expand only with deterministic bounded processors required by validated cases; expose latency/state/phase behavior | Dependency-driven | Processor-count roadmap detached from user evidence |
| `PreviewRenderer` | Full-duration deterministic candidates, cancellation, state continuity, exact render identity | Production-ready hardening | Short preview assumed valid globally |
| `PreviewAudition` | Synchronized gain-matched candidates, bypass, delta/residual, loops, preference capture | Production-ready hardening | Louder comparison treated as better |
| `PreviewWorkflow` | Candidate sets, invalidation without deletion, branch/merge/rollback, asset import boundary | Production-ready plus deferred asset work | Relearn destroys prior state |
| `SessionCore` | Persist decisions, interpretations, exceptions, evidence versions, provider and DSP versions | Production-ready principle | Silent behavior migration |
| `SharedIPC` / App Group | Transport typed state and bounded audio/context references; retain signing and freshness checks | Existing boundary extension | Arbitrary host or file authority |
| `ProductionIntelligence` | Retrieve evidence and generate typed hypotheses; models remain provider-neutral and untrusted | Prototype-worthy | Model listens and directly executes |
| AUv3 real-time kernel | Deterministic precompiled render only; measure allocation, lock, latency, denormal and CPU behavior | Hard constraint | AI, network, blocking, allocation, or mutable search on audio thread |

## Evaluation gates across all milestones

1. **Source integrity:** payload identity and evidence claim are valid.
2. **Intent correctness:** desired, prohibited, preserved, referential, target, and
   scope fields match the task.
3. **DSP conformance:** the graph performs the declared bounded operation.
4. **Real-time safety:** render-thread constraints and host behavior pass.
5. **Preservation:** non-target and identity-bearing traits remain within declared
   bounds.
6. **Audition validity:** timing, gain, level, and residual comparisons are sound.
7. **Long-form validity:** sections, transitions, automation, and state remain
   coherent.
8. **Listening evidence:** attribute success and preference are measured separately
   with appropriate listeners and loudness control.
9. **Workflow evidence:** time, correction cost, agency, explanation, and trust are
   evaluated, not assumed.
10. **Persistence:** accepted state reopens and reproduces across supported versions.

No downstream gate can repair a failure in an earlier one. In particular, a good
listening score does not excuse an unreproducible plan, and numerical conformance
does not establish artistic success.

## What the roadmap should not prioritize yet

- A larger model before a production-specific evaluation harness.
- More automatic mastering profiles before reference scope and preservation.
- Learned waveform replacement inside the deterministic effect lane.
- Broad genre presets before contextual genre and artist evidence.
- Cloud-only collaboration before local deterministic continuity is complete.
- Automatic arrangement editing before the system can recognize that a problem is
  arrangement-level and abstain.
- A wide processor catalog before the highest-value decision and audition flows are
  exact.

## Roadmap success criterion

The roadmap is succeeding when each new capability increases the set of production
decisions TrackSmith can explain, preview, preserve, revise, and validate—not merely
the number of effects or model outputs it can generate.

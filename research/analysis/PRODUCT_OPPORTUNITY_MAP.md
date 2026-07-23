# TrackSmith product opportunity map

Date: 2026-07-16  
Status: research-derived prioritization; not an implementation authorization

## Decision rule

The opportunities below extend the established AUv3, native companion, signed
App Group, source-aware analysis, typed intent/hypothesis, deterministic DSP,
and preview/revision/commit architecture. They do not assume undocumented Logic
authority, direct model control of audio, or network work on the real-time thread.

Scores are ordinal decision aids, not measured forecasts. Each dimension is 1
(weak) to 5 (strong). The weighted score is:

```text
2 * user value
+ competitor weakness
+ evidence strength
+ 2 * architecture fit
+ technical feasibility
+ 2 * differentiation potential
+ evaluation tractability
```

The maximum is 50. Dependency gates override the numerical order.

| Rank | Opportunity | User | Competitor weakness | Evidence | Fit | Feasibility | Differentiation | Evaluation | Score | Gate | Status |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| 1 | Branchable, element-level revision without collateral change | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 50 | Existing exact state and preview lineage | Production-ready principle |
| 2 | Evidence-to-hypothesis explanations that can be falsified | 5 | 5 | 5 | 5 | 5 | 5 | 4 | 49 | Typed observations and provenance | Production-ready principle |
| 3 | Preservation-first planning, including no-change and abstention | 5 | 5 | 5 | 5 | 5 | 5 | 4 | 49 | Preservation constraints and null-plan validation | Production-ready principle |
| 4 | Loudness-matched candidate, delta, and removed-signal audition | 5 | 4 | 5 | 5 | 5 | 4 | 5 | 46 | Synchronized renderer and deterministic candidates | Production-ready / next hardening |
| 5 | Negotiated reference scope with Pareto alternatives | 5 | 4 | 5 | 5 | 4 | 5 | 3 | 45 | Typed reference interpretation | Prototype-worthy |
| 6 | Long-form, section-versioned evidence and cross-section stability | 5 | 5 | 4 | 5 | 4 | 5 | 3 | 45 | Representative-window model and invalidation rules | Prototype-worthy |
| 7 | Whole-mix and cross-track reasoning with explicit mechanism labels | 5 | 5 | 4 | 5 | 4 | 5 | 2 | 44 | Multitrack context transport and role confidence | Prototype-worthy |
| 8 | Contextual producer-judgment and genre evidence retrieval | 5 | 5 | 4 | 5 | 4 | 5 | 2 | 44 | Evidence corpus, retrieval boundary, no-preset policy | Prototype-worthy |
| 9 | Local-first privacy, deterministic persistence, and version-drift protection | 4 | 4 | 4 | 5 | 5 | 4 | 5 | 43 | State/version schema and migration fixtures | Production-ready principle |
| 10 | Separation/repair as a distinct provenance-bearing asset lane | 4 | 3 | 4 | 4 | 3 | 3 | 3 | 35 | Asset identity, residual/leakage tests, explicit import | Deferred prototype |
| 11 | Private, reversible preference learning | 4 | 4 | 2 | 4 | 2 | 5 | 1 | 34 | Stable evaluation tasks and consent/state model | Experimental |
| 12 | Offline multi-objective DSP parameter optimization | 3 | 3 | 3 | 4 | 2 | 3 | 2 | 30 | Explicit objective vector, bounds, safe cloning, replay | Experimental |
| 13 | Audio-capable frontier-model listening hypotheses | 3 | 3 | 2 | 4 | 2 | 3 | 1 | 27 | Provider-neutral evaluation harness and upload consent | Deferred experiment |

## 1. Branchable, element-level revision

**Evidence.** Users repeatedly want to revise one element without destroying
accepted work (`uf-b1-009-parallel-alternatives`,
`uf-b1-019-granular-revision-preservation`). Ozone exposes four snapshots, but
several competitor assistants still relearn or replace a result rather than retain
its decision lineage. The Black Summer case selected an earlier mix after later
passes and a recall lost the preferred feeling (`pjc-rhcp-005`). The Lukas Graham
case used a section-specific branch when one global vocal chain accumulated
conflicting automation (`pjc-lukas-004`).

**Product requirement.** Every proposal has an immutable parent, exact evidence
version, deterministic graph hash, affected scope, preservation set, and named
alternatives. Revision changes only declared targets unless the system discloses
and obtains approval for a dependency expansion.

**Suggested implementation.** Extend the existing revision coordinator and plan
schema with candidate-set identity, parent/merge lineage, affected-node and
affected-time scopes, unresolved-note state, and exact preview-render identity.

**Acceptance tests.** Rollback reproduces the accepted audio and graph hash;
changing a chorus vocal does not change verse or unrelated tracks; stale evidence
invalidates a child without erasing it; a user can compare siblings at matched
loudness.

**Must not infer.** A later branch is better, or a recall with similar parameter
values is perceptually identical.

## 2. Falsifiable evidence-to-hypothesis explanation

**Evidence.** Opaque automation and weak troubleshooting recur across professional
workflow research, Neutron discussions, Logic Mastering Assistant users, and
product reviews (`uf-b1-001-black-box-control-trust`,
`uf-b1-008-explanation-and-troubleshooting`). Academic masking, semantic, and
reference metrics repeatedly measure a direction without authorizing an edit.

**Product requirement.** Separate observation, confidence, contextual
interpretation, competing hypotheses, proposed action, preservation risk, and
audition instruction. Explanations state what evidence would disconfirm the
hypothesis.

**Suggested implementation.** Keep the language model in the typed hypothesis
layer. Render a concise rationale from deterministic fields; retain the underlying
metrics and provenance for inspection. Configuration/routing checks precede an
algorithmic failure diagnosis.

**Acceptance tests.** Users can make a correct targeted revision from the
explanation; deliberately contradictory fixtures cause uncertainty or
clarification; unsupported causal language is rejected by the output validator.

**Must not infer.** An explanation makes a result correct, or every user wants the
same amount of technical detail.

## 3. Preservation-first planning and abstention

**Evidence.** The 2012 autonomous compression study found no processing or light
processing competitive in several conditions, while heavy processing was poor;
its expert vocal setting also contradicted a global rule. MixGenius patent
experiments preserve the same contradiction. Sonible and Nectar documentation
permit zero or negative intervention in some group/masking states. Professional
cases retained house noise, scratch vocals, band overlap, long bridges, raw early
mixes, and already-baked production (`pjc-zach-holmes-001`, `pjc-lukas-001`,
`pjc-deftones-001`, `pjc-kpop-002`, `pjc-rhcp-005`, `pjc-21savage-001`).

**Product requirement.** A valid hypothesis set always includes no change when
the observation does not establish harm. Preservation constraints are evaluated
before preference ranking. Arrangement- or performance-level problems cannot be
laundered into cosmetic DSP recommendations.

**Suggested implementation.** Add null-plan baselines, preservation-risk budgets,
and explicit abstention reasons to candidate ranking. Store identity-bearing
imperfections as user-confirmed or evidence-supported locks.

**Acceptance tests.** Useful-noise, intentional-overlap, live-timing, and
already-baked fixtures produce no-change alternatives; preservation violations
cannot commit silently; an arrangement mismatch yields clarification or
abstention.

**Must not infer.** Imperfection is inherently authentic, or no-change is always
safer than a well-supported correction.

## 4. Loudness-matched, delta, and residual audition

**Evidence.** Competitor manuals document gain match, bypass, multiple candidates,
and removed-signal listening as trust features. Users report brightness,
overprocessing, pumping, low-end damage, and visual target chasing
(`uf-b1-003`, `uf-b1-004`, `uf-b1-012`, `uf-b1-013`, `uf-b1-014`). Academic
reference-optimization studies show objective improvement can conflict with
distributional quality, and one mastering listening study left a loudness
confound. The KPop case auditioned a clipper residual.

**Product requirement.** Quality comparison defaults to synchronized
loudness-matched A/B; a level-unmatched mode is visibly labeled. Subtractive or
repair actions expose the removed signal. Multiple candidates retain matched
transport, selection, and time scope.

**Suggested implementation.** Harden `PreviewAudition` with deterministic
alignment, gain-match provenance, candidate/delta/residual modes, section loops,
and listening-level metadata.

**Acceptance tests.** Gain-only candidates lose apparent advantage when matched;
residual equals aligned input minus output within tolerance; delay, polarity,
latency, and bypass fixtures remain synchronized; clipper/limiter candidates pass
true-peak and transient-preservation tests.

**Must not infer.** A quieter or less different candidate is better, or an
inaudible residual proves artistic success.

## 5. Negotiated reference scope and Pareto alternatives

**Evidence.** Professional reference research reports whole-mix, source, emotion,
dynamics, spectral, and interaction scopes, frequently clarified with clients.
Ozone, Neutron, Sonible, and LANDR expose distinct target/reference mechanisms,
but none establishes a unique original processing chain. Academic methods span
matched-content inverse problems, synthetic same-song style, and
different-content feature matching; their assumptions are not interchangeable.
Lukas Graham used references for contrasting organic and modern traits
(`pjc-lukas-002`).

**Product requirement.** A reference requires target scope, desired traits,
preserved traits, prohibited traits, relation type, and confidence. Conflicting
objectives yield named alternatives or a Pareto set rather than a hidden weighted
average.

**Suggested implementation.** Add a reference-interpretation object ahead of
planning; keep level, spectrum, dynamics, stereo, ambience, performance,
arrangement, emotion, and identity as separate objectives. Optimize only inside
declared scopes.

**Acceptance tests.** Cross-genre source-only references do not alter unrelated
mix dimensions; bad-reference and contradictory-trait fixtures trigger questions;
feature alignment cannot pass without preservation and quality checks.

**Must not infer.** Similarity means quality, a reference reveals its chain, or a
named artist authorizes broad style imitation.

## 6. Long-form, section-versioned evidence

**Evidence.** Official assistants commonly analyze a chosen passage for several
seconds. Users report section-dependent failure (`uf-b1-006-analysis-window-instability`).
Academic systems are dominated by short excerpts, static controls, and sparse
whole-song evaluation. Producer cases repeatedly make section-specific choices:
parallel vocal density, bridge source changes, vocal-chain branches, and dynamic
arrangement preservation.

**Product requirement.** Evidence records selection, section role, duration,
representativeness, and coverage. TrackSmith distinguishes global, sectional,
event-conditioned, and transient-only hypotheses. A changed mix creates a new
evidence version.

**Suggested implementation.** Build a deterministic section map from user markers
plus audio change evidence; compare candidate parameters and preservation metrics
across sections before allowing a global commit.

**Acceptance tests.** A loud-chorus-only analysis cannot silently alter the verse;
quiet/loud/bridge fixtures expose instability; event-conditioned corrections are
inactive outside labeled events; long renders preserve state and automation.

**Must not infer.** A section classifier knows narrative function, or one loud
passage represents the whole song.

## 7. Whole-mix and cross-track reasoning

**Evidence.** Neutron, Sonible, RoEx, Diff-MST, and automatic-mixing research use
different mechanisms that marketing can flatten into “mix-aware”: shared
metering, remote control, sidechain context, sequential decisions, joint feature
objectives, or rendered multitrack inference. Selective-unmasking work measured
amplitude overlap rather than proving psychoacoustic harm. Producer cases prioritize
whole-mix hierarchy and sometimes preserve overlap as identity.

**Product requirement.** Every cross-track proposal names available sources,
roles and confidence, analysis windows, interaction evidence, objective, mechanism,
and affected graph. Missing context lowers confidence or blocks the proposal.

**Suggested implementation.** Extend source-aware reports with role hypotheses,
interaction graphs, and explicit mechanism enums. Start with deterministic shared
metering and scoped sidechain evidence; keep learned joint ranking offline.

**Acceptance tests.** Missing sources or uncertain roles prevent a false joint
claim; overlap can yield no change; group edits preserve mono, phase, low-end
allocation, focal hierarchy, and unrelated tracks.

**Must not infer.** Spectral overlap is harmful masking, source class equals
musical role, or shared metering constitutes joint optimization.

## 8. Contextual producer-judgment and genre retrieval

**Evidence.** The producer corpus contains explicit rejected alternatives,
preservation tradeoffs, and stopping rules that are absent from preset systems.
Semantic-EQ evidence shows embeddings generalize some descriptors but remain far
from human labels and are source-dependent. Users describe generic and
genre-mismatched results (`uf-b1-005-generic-context-mismatch`).

**Product requirement.** Retrieve analogous decisions by source, role, genre,
era, processing scope, initial evidence, and preservation goal. Present them as
ranked hypotheses with provenance, never universal rules.

**Suggested implementation.** Index decision structures rather than quotations;
use the typed vocabulary and genre map as filters; require current-audio evidence
before any retrieved intervention becomes executable.

**Acceptance tests.** The same adjective yields different candidate sets for
vocal, drums, bass, and full mix; intentional lo-fi, shoegaze, punk, jazz, and
classical fixtures resist generic cleanup; retrieval exposes contradictory cases.

**Must not infer.** A genre label fixes a target curve, or a respected engineer's
decision transfers outside its conditions.

## 9. Local-first privacy and reproducible state

**Evidence.** Cloud workflows add privacy-language, upload, render, license,
support, and entitlement concerns (`uf-b1-010`, `uf-b1-011`, `uf-b1-017`). Users
also report silent engine changes breaking a trusted sound (`uf-b1-023`). The
existing TrackSmith local deterministic boundary directly addresses these risks.

**Product requirement.** Core analysis, preview, DSP, and persistence work without
cloud access. Any future audio upload is explicit, scoped, provider/version tagged,
and revocable. Accepted projects retain the exact executable plan and behavior
version.

**Suggested implementation.** Preserve local fallbacks, signed App Group exchange,
provider consent receipts, model/contract versioning, deterministic migration
tests, and frozen render fallback for obsolete plans.

**Acceptance tests.** Network denial does not break deterministic editing;
provider drift cannot change an accepted plan; old projects either reproduce or
surface a bounded migration with before/after comparison.

**Must not infer.** Local processing alone guarantees privacy or security; the
threat model and logging still require validation.

## Lower-priority experimental lanes

### Separation and repair assets

RX and SpectraLayers show large value but also leakage, source-label, host-state,
and artifact limits (`uf-b1-015`, `uf-b1-016`). Estimated stems are new assets,
not recovered originals. A prototype must retain model/version, input hash,
selection, leakage notes, residual audition, and explicit user import. Speech
enhancement evidence cannot establish music-vocal quality.

### Private preference learning

Preference learning is potentially differentiating only after candidate quality,
preservation, and evaluation tasks are stable. Store user decisions and contexts,
not an unexplained global “taste” vector; allow inspection, reset, per-project
scope, and counterfactual testing. This remains experimental because evidence for
longitudinal professional benefit and preference drift is weak.

### Offline optimization

SPSA, differentiable consoles, and latent inference-time optimization can propose
candidates under paired or explicitly feature-scoped objectives. They remain
offline, bounded, cancellable, and mapped to an inspectable deterministic graph.
Objective improvement never authorizes commit, particularly where AF/reference
alignment conflicts with FAD, preservation, or preference.

### Audio-capable frontier models

Future models may add listening hypotheses, candidate ranking, or ambiguity
resolution. They do not gain render authority. Adoption requires a TrackSmith task
where the model beats deterministic analysis plus text context, with exact
provider/version/input provenance, upload consent, cost and latency ceilings,
calibrated uncertainty, and local fallback.

## Strongest product thesis

TrackSmith should not compete on “AI chooses a chain.” That is crowded in patents,
manuals, and product positioning, and its failure modes are familiar. The stronger
opportunity is an **evidence-grounded production conversation whose every audible
decision is scoped, contestable, reversible, preservation-tested, and exactly
reproducible**. That thesis fits the architecture already proven in the repository
and addresses the most consistent shortcomings across research, professional
practice, competitors, and users.

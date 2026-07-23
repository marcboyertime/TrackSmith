# TrackSmith Open-Source Implementation Patterns

Review date: 2026-07-16
Evidence class: open-source implementation evidence
Companion records: `research/analysis/OPEN_SOURCE_MATRIX.csv`, `research/metadata/deep-review-batch-1-open-source.jsonl`, and `research/metadata/source-manifest-open-source-v1.jsonl`

## Executive conclusion

The 23 pinned repositories reviewed in this batch reinforce TrackSmith's existing architecture rather than justify replacing it. The strongest implementable pattern is still:

```text
source snapshot + declared scope
-> source-aware measurements with feature provenance
-> typed intent and one or more production hypotheses
-> bounded, inspectable ProcessingPlan
-> deterministic native DSP
-> technical validation + loudness-controlled audition
-> revision / commit / bypass / project persistence
```

Open-source systems are particularly useful as algorithm references, conformance oracles, evaluation harnesses, and negative evidence about shortcuts. None of the reviewed repositories demonstrates the whole problem TrackSmith is solving. In particular, none jointly proves professional producer judgment, semantic ambiguity handling, source-aware multitrack reasoning, editable deterministic execution, AUv3 real-time safety, long-form coherence, and preference-validated conversation.

The practical consequence is to keep the AUv3 effect, companion application, signed App Group boundary, `SourceAwareAudioAnalyzer`, `ProductionIntentEngine`, typed `ProcessingPlan`, `DSPCore`, `PreviewRenderer`, revision coordinator, and provider-neutral contract. Add research-derived capabilities at those seams; do not replace the seams with an opaque waveform model or a Python inference graph.

## Review protocol and limits

Each repository was cloned into an isolated temporary checkout, pinned to a full 40-character commit, checked against its configured origin, and required to have an empty `git status --porcelain --untracked-files=all`. The source, license, architecture, relevant algorithms, tests or benchmarks, and integration hazards were inspected. The exact proofs and file lists are in the machine-readable deep-review records.

This is source-code evidence, not a fresh reproduction of every paper result or pretrained checkpoint. No external model weights or training datasets were treated as covered by a repository's code license. Benchmarks reported by a repository are recorded as repository evidence unless independently rerun. A clean checkout proves source identity, not correctness, production readiness, or license compatibility of transitive dependencies.

## Decision map

| Pattern | Evidence strength in reviewed code | TrackSmith disposition |
|---|---|---|
| Native AU render boundary with preallocated state and compile-time nonblocking annotations | Strong official implementation evidence from Apple AudioUnitSDK; broader wrapper evidence from JUCE | Production-ready principle; retain native AUv3 architecture |
| Bounded typed DSP controls separated from a reasoning/controller layer | Repeated across DDSP, DeepAFx-ST, Diff-MST, ITO-Master, DASP, and NablAFx | Production-ready principle; already aligned with `PlanSchema` and `DSPCore` |
| Feature analysis in a companion/offline process with explicit configuration provenance | Strong implementation evidence from Essentia, librosa, libebur128, and x42 meters | Production-ready principle; expand `AudioAnalysis`, never move Python/ML work into the render thread |
| Differentiable optimization as an offline candidate generator | Multiple research implementations; validation is mostly proxy-metric or short-clip | Prototype-worthy behind typed bounds, preservation constraints, and human audition |
| One-to-many candidate generation for ambiguous creative tasks | MEGAMI directly models diversity; other systems usually collapse to one estimate | Prototype-worthy in typed plan space, not hidden effect-embedding space |
| Language or audio-text embeddings as direct proof of a successful edit | Not established; CLAP systems optimize retrieval/embedding proximity, not production success | Reject as acceptance criterion; use only as fallible evidence or ranking feature |
| Global reference matching by aggregate spectrum, level, width, or embedding | Implemented, but underdetermined and source/content dependent | Prototype-worthy only after explicit reference scope; never automatic acceptance |
| LLM output executed after loose parsing | LLM2Fx code exposes this failure mode | Reject; require schema, enum, range, scope, order, capability, and safety validation |
| Copyleft, noncommercial, custom, or unlicensed code copied into TrackSmith | Many strong references are not commercially compatible | Reject absent specialist license review or separate commercial grant |
| Objective metrics as substitutes for preference | Repeatedly contradicted by system design and evaluation limitations | Reject; metrics are guardrails and diagnostic evidence only |

## 1. Audio Unit integration and the real-time boundary

### Direct evidence

Apple's AudioUnitSDK is the most authoritative implementation reference in this batch. Version 1.4.0 adds `[[clang::nonblocking]]`-based real-time annotations through `AUSDK_RTSAFE_TYPE` and `AUSDK_RTSAFE_SECTION`, marks render dispatch `noexcept`, and keeps potentially render-time scope/element access free of locks. Its buffer and scope code also shows that allocation remains necessary during setup and resizing; the annotation does not make every method safe to call from render.

JUCE supplies a much broader format wrapper, including AUv3, host parameter/state conventions, offline-render flags, latency/tail plumbing, and extensive wrapper tests. That breadth is useful as an edge-case catalog. It does not justify moving a working native AUv3 to JUCE, and JUCE's AGPL/commercial licensing boundary is material for a closed product.

DPF demonstrates a small explicit `activate -> run -> deactivate` contract and disciplined separation of parameter/state operations from processing. Its documented/current export surface is centered on LADSPA, DSSI, LV2, VST2, VST3, CLAP, and JACK; although the tree contains legacy Audio Unit wrapper code, it is not evidence of a production AUv3 path and is not a replacement for TrackSmith's native AUv3 boundary. Pedalboard can load Audio Units on macOS and is valuable for external black-box/offline test harnesses, but a Python/JUCE host is not evidence of render-thread suitability.

### TrackSmith pattern

Retain the current native AUv3 and companion arrangement. Strengthen it with two complementary checks:

1. compile-time nonblocking annotations on the render-call graph where the compiler supports them; and
2. the existing runtime heap interposer plus lock/file/network instrumentation.

The render callback should only:

- read an immutable or atomically published compiled-plan snapshot;
- process preallocated channel/state buffers;
- advance bounded processor state;
- publish bounded telemetry through a single-producer/single-consumer structure; and
- return a declared status without throwing.

All plan compilation, coefficient-table growth, FFT-plan construction, model inference, file access, App Group exchange, and UI work belongs outside the callback. A type or function being labelled real-time-safe is not sufficient: tests must cover the reachable call graph.

### Acceptance tests

- zero allocations and zero blocking locks across silence, impulse, step, full-scale, denormal, NaN/Inf rejection, automation, bypass, format changes, and tail rendering;
- maximum callback duration and deadline-miss distribution at supported sample rates, channel layouts, and buffer sizes;
- concurrent parameter publication while rendering, verified with Thread Sanitizer in a non-real-time test build;
- state continuity across variable host blocks and offline render mode;
- deterministic replay from the same source snapshot and serialized plan;
- host-reported latency and tail agree with impulse measurements; and
- no companion or provider failure can invalidate the last committed render plan.

## 2. The DSP graph should be typed, bounded, and deterministic

### Repeated implementation pattern

DDSP's `Processor` splits unconstrained network outputs from physically meaningful controls before signal generation. DASP-PyTorch and DeepAFx-ST normalize controls to `[0,1]`, then map them into declared effect ranges. Diff-MST predicts separate track, effects-bus, and master-bus parameter groups. NablAFx makes controller type and processor chain explicit. These systems differ in quality and scope, but they converge on a useful software boundary:

```text
untrusted proposal
-> validate and normalize
-> typed physical parameters
-> declared processor order
-> deterministic render
```

TrackSmith already has the right abstraction in `PlanSchema` and `DSPCore`. The open-source evidence supports extending the node catalog and validation, not replacing it with a neural audio renderer.

### Required node metadata

Every processing node should declare:

- stable operation and implementation version;
- source/track/bus scope;
- parameter units, legal range, default, neutral value, and smoothing rule;
- channel-layout behavior and stereo-link policy;
- sample-rate assumptions;
- latency, lookahead, and tail behavior;
- state-reset and bypass semantics;
- required oversampling or anti-alias strategy;
- expected metric directions and preservation constraints;
- provenance back to the hypothesis and evidence; and
- a deterministic serialization order.

The planner may generate several candidates, but each candidate must compile to this same explicit graph. The committed result must not depend on a hidden model state or a transient optimizer object.

### Effect-specific lessons

#### EQ and filtering

Signalsmith supplies clear MIT-licensed C++ references for RBJ/bilinear and Nyquist-aware filter designs, while DASP, DDSP, FLAMO, and NablAFx expose differentiable FIR/IIR approximations. The critical hazard is modulation and stability: one Signalsmith biquad variant explicitly does not guarantee stability under audio-rate coefficient changes, and frequency-sampling approximations in research code are clip-level/offline techniques rather than drop-in streaming IIRs.

Use proven native filter implementations with coefficient-domain bounds, smoothing, stability checks, and response tests. Treat differentiable approximations as optimizer surrogates unless their rendered response is proven equivalent to `DSPCore` over the supported domain.

#### Dynamics and limiting

DASP implements a differentiable feed-forward compressor with approximate parallel ballistics. ZamAudio provides readable soft-knee compressor, dynamic-EQ, and maximizer loops. ITO-Master exposes a white-box chain with multiband compression and limiting. Matchering's Hyrax limiter is a useful offline algorithm reference. None is a production-ready TrackSmith limiter by inspection alone.

Required tests include detector and gain-computer curves, attack/release timing, stereo linking, lookahead, oversampling, true-peak compliance, intersample behavior, low-frequency distortion, pumping fixtures, recovery after overload, automation smoothing, and loudness-controlled listening. Loudness must be reported separately from preference.

#### Reverb and delay

Dragonfly's separation of early reflections and late-tail controls is especially valuable for semantic representation: size, predelay, diffusion, modulation, decay, spectral decay, width, and early/late balance should not collapse into one `amount` scalar. FLAMO provides differentiable feedback-delay-network and recursion design patterns. DDSP and DASP supply differentiable convolution/noise-shaped reverberation.

The production renderer still needs bounded stable feedback, denormal handling, tail lifecycle, preset-change behavior, coefficient/update scheduling, and deterministic seed/state. Any parameter update that reallocates or rebuilds an impulse response must occur outside render.

#### Stereo operations and metering

x42 meters demonstrates a broad analyzer surface: correlation, mid/side, goniometer, phase, spectrum, true peak, loudness history, and DR/K meters. Its audio-to-UI path uses bounded buffering rather than doing UI work in the callback. libebur128 provides a compact BS.1770/EBU R128 implementation with conformance and fuzz tests. Matchering's mid/side reference matching shows both the utility and danger of reducing stereo intent to aggregate width.

Stereo metrics should be source- and context-aware evidence. A wider numerical ratio is not automatically better, and mono compatibility is a preservation test rather than a universal target.

## 3. Analysis belongs in the companion and every feature needs provenance

Essentia and librosa expose hundreds of useful MIR operations, but their implementation characteristics make the boundary clear: NumPy/TensorFlow/Python allocation, whole-signal dynamic programming, configurable framing, and model inference are companion/offline work. Essentia's standard/streaming graphs are architecturally useful, yet even a streaming graph does not imply Apple render-thread safety.

Every `SourceAwareAnalysisReport` feature should carry, directly or through an analysis-version identifier:

- implementation and model version;
- sample rate and channel transform;
- window, hop, FFT, padding, centering, aggregation, and gating parameters;
- time range and source snapshot identity;
- validity range and missing/silence behavior;
- calibration/reference corpus when learned;
- uncertainty or repeatability information; and
- the source role/class used for interpretation.

This matters because librosa's centered windows and padding, CLAP's 10-second cropping, loudness gating, stereo fold-down, and feature aggregation can materially change the conclusion. A feature name without configuration is not reproducible evidence.

Recommended near-term conformance oracles:

- libebur128 for integrated/short-term/momentary loudness, LRA, and true-peak test vectors;
- librosa for offline feature/time-axis cross-checks;
- Essentia for descriptor-family comparison and adversarial fixtures; and
- x42 meters for analyzer UX and stereo-diagnostic coverage.

Do not ship these repositories as product dependencies without a separate need and license decision. Native TrackSmith implementations should be verified against pinned fixtures and independent oracles.

## 4. Differentiable DSP is an optimizer lane, not the render architecture

### What the code directly demonstrates

- DASP-PyTorch differentiates through gain, distortion, a six-band EQ, compressor/expander, noise-shaped reverb, stereo operations, and a stereo bus. Its examples optimize effect parameters and learn style-transfer controllers.
- Magenta DDSP provides physically constrained processor controls, DAG composition, differentiable synthesis/effects, and multi-scale spectral losses with substantial unit coverage.
- FLAMO differentiates frequency-domain LTI systems including series and recursive structures, biquads, delays, matrices, and feedback-delay networks, with explicit time-alias mitigation.
- NablAFx compares black-box and gray-box effect models, static/dynamic controllers, recurrent state, multiple architectures, losses, and CPU real-time-factor/FLOP scripts.
- DeepAFx-ST compares autodiff, neural proxy, TCN, and SPSA routes for a fixed EQ-plus-compressor style-transfer chain.
- ITO-Master optimizes a reference embedding while keeping a white-box or black-box converter fixed.

### Safe TrackSmith use

An optimizer may propose bounded parameters or parameter deltas outside the render thread. It must optimize through either:

1. the exact production renderer; or
2. a documented surrogate whose error against the production renderer is bounded on the candidate domain.

The optimizer result is never committed directly. It becomes a `ProductionHypothesis`/candidate with:

- objective vector, not only a scalar sum;
- initial state, seed, iterations, convergence and boundary-hit information;
- preserved and locked nodes;
- parameter deltas and audible-risk estimates;
- a no-op baseline and at least one simple deterministic baseline;
- technical validation; and
- a level-matched audition artifact.

Use Pareto candidates when objectives conflict. A single weighted scalar hides whether an improvement in spectral distance was purchased with worse dynamics, width, artifacts, or loudness.

### Required experiments

- exact synthetic recovery where the generating graph and parameters are known;
- surrogate-versus-production response and gradient disagreement;
- optimizer stability across seeds, starting points, excerpt choices, and sample rates;
- preservation constraints with deliberately tempting destructive minima;
- boundary saturation and invalid-gradient behavior;
- long-tail/stateful effects across chunk boundaries;
- short-clip versus full-song generalization; and
- preference tests against no-op, simple heuristic, and human alternatives.

## 5. Reference matching must remain a typed interpretation problem

Matchering makes the simplest reference-matching strategy concrete: compare loudest portions, align RMS, form smoothed target/reference spectral ratios in mid and side, convolve with FIRs, correct levels, then limit. Diff-MST conditions multitrack console settings on a reference mix. ITO-Master refines a reference embedding against audio-feature or CLAP loss. DeepAFx-ST predicts EQ/compressor settings from input/reference embeddings.

These are useful candidate-generation mechanisms. They also expose why an unqualified `match this reference` action is unsafe:

- aggregate spectrum confounds instrumentation, notes, arrangement, mix balance, and mastering;
- RMS/peak matching rewards level and may erase intentional dynamics;
- mid/side ratios conflate arrangement and production width;
- learned embeddings inherit crop, dataset, and task biases;
- many parameter sets match the same summary statistics;
- a reference may be supplied for only one trait; and
- section-dependent production choices can make a single global style wrong.

TrackSmith should require or infer a typed `ReferenceInterpretation` containing desired traits, prohibited traits, preservation constraints, scope, source compatibility, excerpt, and confidence. Low confidence or conflicting traits should trigger clarification or multiple labelled interpretations. A reference metric may rank candidates within that declaration; it must not create the declaration.

## 6. Automatic mixing needs relationships, roles, and alternatives

Diff-MST's explicit channel-strip/master-bus graph is closer to TrackSmith than end-to-end waveform generation because the result remains editable. Its code nevertheless predicts mostly static global controls from track/reference embeddings, trains against a narrow console and proxy feature losses, and contains research-grade tests rather than production assurance.

MEGAMI adds an important product insight: mixing is one-to-many. Its conditional diffusion model generates per-track effect embeddings and uses a separate neural effects processor. That diversity premise transfers; the opaque effect-embedding/black-box renderer does not fit TrackSmith's editability and deterministic replay requirements.

Implement diversity at the plan level:

```text
same request and evidence
-> conservative interpretation
-> character-preserving interpretation
-> bolder interpretation
```

Each alternative must explain which hypothesis differs, which nodes change, what is preserved, and what evidence would discriminate among them. Source roles and cross-track relationships must be first-class. A waveform-invariant role swap should leave acoustic measurements unchanged while legitimately changing the recommendation; this is a crucial test that the system reasons about production context rather than only statistics.

## 7. Semantic control requires a strict executable contract

LLM2Fx is the most direct code evidence for text-to-effect control in this batch. The first system asks a general LLM to emit EQ or reverb JSON from a timbre word, instrument, prompt instructions, DSP code, audio features, and few-shot examples. Its evaluation uses an effect-encoder embedding distribution. LLM2Fx-Tools fine-tunes audio-conditioned LLMs to emit ordered effect tool calls, using synthetic random chains and LLM-generated conversation/reasoning data.

The reusable concept is a typed tool vocabulary. The dangerous implementation shortcut is executing loosely parsed dictionaries. The reviewed parser accepts an object containing `name` and `arguments`, and the executor dispatches recognized names without a complete schema/range/scope/order/safety validation boundary.

TrackSmith already has the stronger route: provider output becomes `ModelIntentContract`, passes `ModelOutputValidator`, becomes a source-aware `ProductionIntentInterpretation`, then a deterministic planner emits `ProcessingPlan` nodes. Preserve that architecture.

Before any model-proposed action reaches rendering, validate:

- operation enum and capability availability;
- processing scope and source identity;
- every required and forbidden argument;
- units, finite values, bounds, and neutral behavior;
- node ordering and incompatible combinations;
- latency/tail/resource budget;
- preservation constraints and locked prior decisions;
- rationale/provenance separation from executable fields;
- ambiguity and confidence; and
- deterministic canonicalization.

Never train a reasoning trace merely because another model produced a plausible explanation. Synthetic chain labels can teach inversion and tool syntax; they do not supply producer judgment. Generated rationales should be treated as untrusted metadata unless grounded in known transformations or human-reviewed decisions.

## 8. Audio-language embeddings are evidence, not an edit judge

LAION-CLAP maps audio and text to a shared space and supports retrieval/zero-shot classification. The source shows 48 kHz preprocessing, approximately 10-second inputs, crop/fusion choices, and checkpoints trained on datasets with separate rights constraints. ITO-Master uses CLAP loss for audio or text targets. LLM2Fx evaluates outputs with an effect encoder. MEGAMI uses CLAP-domain adaptation as part of a larger effect-embedding model.

No reviewed repository establishes the implication:

```text
higher text/audio embedding similarity
=> better production edit
```

Embeddings may support query expansion, candidate retrieval, weak semantic evidence, diversity clustering, or an experimental ranking feature. They require:

- fixed model and preprocessing version;
- deterministic crop/excerpt policy;
- calibration by source type, term, genre, and operation;
- adversarial tests for loudness, content, artist, and instrumentation leakage;
- abstention thresholds;
- comparison with simpler acoustic baselines; and
- human labels of whether the requested change actually succeeded.

Do not optimize a production render solely toward a broad prompt such as a genre name. Genre similarity is not a mastering instruction.

## 9. Evaluation must combine conformance, diagnostics, and listening

webMUSHRA implements MUSHRA, BS.1116-style tests, paired comparison/ABX, ranking, Likert pages, randomization, looping, sample-aligned switching, anchors, training pages, and CSV export. It is a strong workflow reference, but its custom license needs review and its browser/PHP implementation is not automatically suitable for product telemetry or confidential studies.

Pedalboard is a useful prototype for an offline plug-in evaluation harness: chunked processing, reset/state retention, latency compensation, serial/parallel chains, parameter/state inspection, and macOS Audio Unit loading. libebur128 brings conformance and fuzz tests. NablAFx brings CPU real-time-factor/FLOP scripts. Together they support three separate lanes:

1. **DSP conformance:** response, state, bounds, latency, tail, true peak, determinism, and render-thread behavior.
2. **Diagnostic metrics:** loudness, crest, spectral, stereo, artifacts, and preservation deltas, each reported separately.
3. **Perceptual judgment:** trained listening, loudness-controlled comparisons, hidden reference/anchors where appropriate, explicit task and preservation questions, and participant/excerpt provenance.

For creative alternatives, paired preference or best-worst/ranking may be more faithful than MUSHRA's quality-distance framing. For transparent codec-like degradation, MUSHRA/BS.1116 patterns are appropriate. The test method must match the decision.

Every candidate should generate an evaluation bundle containing:

- input, candidate, no-op, and relevant baseline renders;
- task-faithful and loudness-controlled variants;
- sample-aligned switch points and loop regions;
- source/plan/renderer fingerprints;
- objective metrics with configuration provenance;
- hidden condition randomization metadata;
- listener instructions and response schema; and
- analysis code/version and exclusion rules.

## 10. License and supply-chain boundary

License compatibility is independent of technical quality.

### Lower-friction source references

- Apache-2.0: Apple AudioUnitSDK, DASP-PyTorch, Magenta DDSP.
- MIT: FLAMO, NablAFx, libebur128, Signalsmith DSP.
- ISC: DPF, librosa.
- CC0-1.0 source: LAION-CLAP, with separate weight/data/dependency review.

Even here, retain notices, verify file-level exceptions, inventory dependencies, and separately license model weights and datasets.

### Restricted or copyleft references

- JUCE: AGPL-3.0 or a separate commercial license.
- Essentia: AGPL-3.0 or a separate commercial license.
- GPL repositories: Dragonfly Reverb, Matchering, Pedalboard, x42 meters, and ZamAudio.
- Noncommercial research licenses: DeepAFx-ST, Diff-MST, ITO-Master, and MEGAMI.
- Custom license requiring review: webMUSHRA.
- No declared repository license: LLM2Fx; absence of a license is not permission to copy.

For these sources, retain architecture/algorithm knowledge and independently implement from primary technical descriptions where appropriate. Do not copy code, tests, weights, assets, or distinctive tables into TrackSmith without a recorded license decision.

## Module-level engineering consequences

| Existing module/boundary | Consequence | Status | Minimum acceptance evidence |
|---|---|---|---|
| AUv3 target / `DSPCore` | Add compiler-supported nonblocking annotations and keep runtime allocation/lock probes | Production-ready | heap/lock/network zero; host deadline, latency, tail, format tests |
| `PlanSchema` | Ensure every DSP node declares units, bounds, neutral state, smoothing, latency/tail, scope, provenance, and version | Production-ready | encode/decode/canonical hash; invalid-plan and neutral/bypass fixtures |
| `AudioAnalysis` | Add feature-configuration provenance and oracle comparisons | Production-ready | versioned fixtures across sample rates, channels, silence, excerpts, and adversarial signals |
| `ProductionIntentEngine` | Represent ambiguous terms as contextual hypotheses, not direct parameter maps | Production-ready principle | source-role/genre/context swaps, clarification and alternative-generation cases |
| `DeterministicPlanner` | Generate labelled bounded alternatives and preserve locked nodes | Prototype-worthy | deterministic seeds, delta authorization, no-op/conservative/bold candidates |
| `PreviewRenderer` / audition workflow | Emit task-faithful and loudness-controlled aligned comparisons | Production-ready principle | sample alignment, render fingerprint, level-control verification, blind condition map |
| `ProviderEvaluationHarness` | Add strict tool-contract adversaries and semantic success listening labels | Prototype-worthy | malformed/range/order/scope injection suite; human-grounded success set |
| Future offline optimizer | Optimize an objective vector under typed preservation constraints | Experimental | exact recovery, surrogate mismatch, Pareto stability, long-form and listening tests |
| Future audio-language model lane | Use embeddings as calibrated evidence only | Experimental | task/source calibration, abstention, leakage/adversarial tests, preference lift over acoustic baselines |

## Priority experiments

### P0 — render and state invariants

1. Annotate the native AU render path as nonblocking where supported and fail the build for newly reachable unsafe calls.
2. Expand the heap interposer into allocation/lock/file/network counters over every `DSPCore` node, automation, bypass, tail, and host format transition.
3. Add independent response/latency/tail/conformance fixtures for EQ, compression, limiting, reverb/delay, saturation, and stereo nodes.

### P1 — analysis provenance and oracles

1. Version the full feature configuration in `SourceAwareAnalysisReport`.
2. Compare loudness/true-peak fixtures against libebur128 and selected MIR fixtures against pinned librosa/Essentia outputs.
3. Add excerpt/crop/centering/gating sensitivity reports so the reasoning layer sees measurement instability.

### P1 — semantic contract hardening

1. Fuzz `ModelOutputValidator` with malformed tool calls, unknown nodes, unit confusion, out-of-range values, NaN/Inf, contradictory scopes, unsafe order, and locked-node mutations.
2. Require executable plan fields to be canonical and separate from explanations.
3. Add ambiguity cases where the correct result is clarification or multiple interpretations.

### P2 — bounded offline candidate optimization

1. Start with exact synthetic recovery of TrackSmith's own EQ/dynamics renders.
2. Compare direct parameter search, a differentiable surrogate, and simple heuristics.
3. Preserve transients, dynamics, mono compatibility, and level as explicit constraints rather than one weighted loss.
4. Advance only if loudness-controlled listeners prefer candidates beyond no-op and heuristic baselines.

### P2 — one-to-many production alternatives

1. Generate conservative, character-preserving, and bold typed plans from the same intent.
2. Measure whether users can understand and revise the difference.
3. Learn rankings only from source-, genre-, goal-, and listener-scoped preferences; never collapse them into a universal preset.

## Prohibited overclaims

This batch does not establish that:

- a differentiable loss measures artistic quality;
- a CLAP or effect embedding understands a production request;
- matching a reference spectrum, RMS, crest factor, width, or embedding reproduces its production judgment;
- a real-time factor measured in a Python research benchmark is AUv3-safe;
- a fixed short excerpt represents a whole song;
- static effect parameters are sufficient for arrangement-aware mixing;
- a model-generated explanation is faithful to the audio or parameters;
- an open repository's pretrained weights share the source-code license;
- a clean checkout is tested or production-ready; or
- a repository README's human-level or professional-quality claim is independently demonstrated by its code.

## Remaining implementation gaps

- No reviewed open-source project offers a production-grade native Swift/C++ AUv3 graph with TrackSmith's exact reversible plan and App Group model.
- There is no strong open dataset of producer conversations linked to source-aware diagnoses, rejected alternatives, editable plans, and level-controlled outcomes.
- Long-form automation, section-aware revision, and project-persistence evaluation are weak across the reviewed research systems.
- Differentiable surrogates are not yet calibrated against TrackSmith's production DSP nodes.
- Learned audio metrics remain insufficiently validated for source-specific production success and preservation.
- The corpus still needs a dedicated review of compatible native oversampling, true-peak limiting, dynamic EQ, transient shaping, de-essing, and saturation implementations with numerical test vectors.
- A TrackSmith-native listening-test artifact generator and analysis pipeline remains to be specified; webMUSHRA is a reference, not a drop-in dependency.

## Repository coverage

The exact matrix covers:

- AU/plugin frameworks: Apple AudioUnitSDK, JUCE, DPF, Pedalboard;
- native/readable DSP: Signalsmith DSP, libebur128, x42 meters, ZamAudio, Dragonfly Reverb, Matchering;
- MIR/embeddings: Essentia, librosa, LAION-CLAP;
- differentiable DSP/modeling: DASP-PyTorch, Magenta DDSP, FLAMO, NablAFx, DeepAFx-ST;
- automatic mixing/mastering/reference control: Diff-MST, ITO-Master, MEGAMI;
- semantic/tool control: LLM2Fx; and
- listening tests: webMUSHRA.

Later batches should extend coverage, not count forks or international mirrors as new evidence. The next strongest additions would be native permissive oversampling/limiting libraries, Audio Unit host conformance fixtures, source-separation/MIR systems with explicit model-weight rights, and modern listening infrastructure with auditable statistics and privacy controls.

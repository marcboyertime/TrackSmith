# Automatic Mixing and Reference Control: Academic Deep Review, Batch 1

Review date: 2026-07-16  
Status: full-text deep review complete for all eight assigned sources  
Machine-readable companion: `research/metadata/deep-review-batch-1-academic.jsonl`

## Executive finding

The eight papers do not establish one general method called “reference matching.”
They study at least five materially different problems:

1. recovering a known linear transformation from the same aligned content;
2. learning or optimizing a processor against paired input/output audio with the
   same musical content;
3. transferring a small set of measured mix attributes between different songs;
4. cross-adapting processors from relationships among tracks without a reference;
5. representing effects, implementations, parameters, transformations, and
   provenance so that the resulting action remains queryable.

Those problems have different identifiability, evidence, and evaluation
requirements. None of the papers can infer why a user supplied a reference, which
parts of it matter, what must remain unchanged, or whether measured similarity is
artistically desirable. TrackSmith's existing architecture therefore remains the
right boundary:

```text
reference asset
-> explicit reference interpretation
   (scope, desired traits, preserved traits, prohibited traits, uncertainty)
-> one or more typed production hypotheses
-> source-aware measurements
-> bounded, inspectable DSP candidates
-> technical guardrails + loudness-controlled audition
-> revise / commit / bypass with provenance
```

A reference is negotiated evidence, not an unqualified target vector. Exact
matched-content inverse problems are a narrow exception: when the target and
inputs contain the same aligned material and the transformation class is known,
an estimator may recover that transformation directly. That exception must be a
separate typed route, not silently generalized to different-content style
references.

## Review protocol and source identity

All 56 PDF pages were read from the immutable archive objects. Text extraction was
used for navigation, then 41 pages were rendered at 120 dpi and visually inspected
to verify equations, diagrams, tables, plots, captions, and page layout. The
recorded SHA-256 values were recomputed from the local bytes and matched the
current manifests. No abstract-only source influenced a conclusion.

| Resource | Version; pages | Verified SHA-256 and immutable archive path | Rendered pages | Evidence class and review scope |
|---|---:|---|---:|---|
| `arxiv-2105-04752-black-box-audio-effects` — Martinez Ramirez et al., *Differentiable Signal Processing With Black-Box Audio Effects* | arXiv:2105.04752v1; 5 | `b88d6dc850173f228f6bf213bea51f821d2f343f372272a304c3f57ccd047090`<br>`research/library/tracksmith-research-archive/objects/b88d6dc850173f228f6bf213bea51f821d2f343f372272a304c3f57ccd047090.pdf` | 2-4 | Directly demonstrated peer-reviewed evidence, bounded to three paired-data tasks and a small listening test. All sections, equations, task data, evaluation, and conclusions read. |
| `arxiv-2407-08889-diff-mst` — Vanka et al., *Diff-MST: Differentiable Mixing Style Transfer* | arXiv:2407.08889v1 / ISMIR 2024; 8 | `688debaa3bc2889bda7b8ff78c51caaaea2bf1cdab35e3adea96ee95c357c330`<br>`research/library/tracksmith-research-archive/objects/688debaa3bc2889bda7b8ff78c51caaaea2bf1cdab35e3adea96ee95c357c330.pdf` | 2-7 | Directly demonstrated peer-reviewed evidence, objective-only for the proposed system. Architecture, differentiable console, losses, two training regimes, datasets, baselines, tables, discussion, ethical statement, and limitations read. |
| `arxiv-2506-16889-ito-master` — Koo et al., *ITO-Master* | arXiv:2506.16889v3 / ISMIR 2025; 8 | `65ad45a78a02d7ddb2fca6c8c206a9ba4c35be5313ee01632cd0bc43fc493177`<br>`research/library/tracksmith-research-archive/objects/65ad45a78a02d7ddb2fca6c8c206a9ba4c35be5313ee01632cd0bc43fc493177.pdf` | 2-7 | Directly demonstrated peer-reviewed evidence with limited objective and small-panel subjective evaluation. Full methods, white/black-box chains, objectives, datasets, results, text steering, and limitations read. |
| `dafx-2008-selective-unmasking` — Perez Gonzalez and Reiss, *Improved Control for Selective Minimization of Masking Using Inter-Channel Dependency Effects* | DAFx-2008 proceedings; 7 | `632fe2f923e5abd58cb5e8b8d9e475e576cadd269e925278b8602a5df9db865b`<br>`research/library/tracksmith-research-archive/objects/632fe2f923e5abd58cb5e8b8d9e475e576cadd269e925278b8602a5df9db865b.pdf` | 2-6 | Empirical but limited research evidence: implementation and a self-referential metric, without a listening test or reported corpus. Full algorithm, interface, metric, results, and caveats read. |
| `dafx-2009-automatic-target-mixing` — Barchiesi and Reiss, *Automatic Target Mixing Using Least-Squares Optimization of Gains and Equalization Settings* | DAFx-2009 proceedings; 8 | `6cc36a21e377647c76e20ca06f7df7c6ee0700896db1d08cd7fe4df820660e39`<br>`research/library/tracksmith-research-archive/objects/6cc36a21e377647c76e20ca06f7df7c6ee0700896db1d08cd7fe4df820660e39.pdf` | 2-7 | Empirical but limited research evidence on synthetic, same-content linear recovery. Complete derivations, experiments, plots, limitations, and future-work boundary read. |
| `dafx-2011-audio-effects-ontology` — Wilmering, Fazekas, and Sandler, *Towards Ontological Representations of Digital Audio Effects* | DAFx-2011 proceedings; 4 | `ab3c3203e1a694892e1d0937e7d60bf8ed03aa3f7983f272fff3e84d3a59b2d0`<br>`research/library/tracksmith-research-archive/objects/ab3c3203e1a694892e1d0937e7d60bf8ed03aa3f7983f272fff3e84d3a59b2d0.pdf` | 2-4 | Directly demonstrated peer-reviewed representation/query example; no empirical validation of perceptual mappings or product usability. Full schema argument, examples, query, and conclusions read. |
| `dafx-2012-autonomous-multitrack-drc` — Maddams, Finn, and Reiss, *An Autonomous Method for Multi-Track Dynamic Range Compression* | DAFx-2012 proceedings; 8 | `4357282d22dd85e51ad451061cc4cff6548757b8386f0925cd197c9e5f040a88`<br>`research/library/tracksmith-research-archive/objects/4357282d22dd85e51ad451061cc4cff6548757b8386f0925cd197c9e5f040a88.pdf` | 2-7 | Empirical but limited research evidence: seven selected excerpts and 15 listeners, with acknowledged heuristic assumptions. All equations, modes, selection criteria, listening tests, plots, and limitations read. |
| `dafx-2017-reference-controlled-drc` — Sheng and Fazekas, *Automatic Control of the Dynamic Range Compressor Using a Regression Model and a Reference Sound* | DAFx-2017 proceedings; 8 | `caf708230662aef1170cd6711540f7ca8540171795c572536ac93c8d882cea4b`<br>`research/library/tracksmith-research-archive/objects/caf708230662aef1170cd6711540f7ca8540171795c572536ac93c8d882cea4b.pdf` | 2-7 | Empirical but limited research evidence on isolated violin/snare notes and 3-5 s monophonic violin loops; no listening test. Full features, workflows, training, tables, plots, and limitations read. |

The corresponding current manifests are at
`research/library/tracksmith-research-archive/manifests/current/<resource-id>.json`.
They record the canonical and retrieval URLs, retrieval time, source version,
rights basis, byte count, and validated-payload status. The machine-readable
review file repeats those operational facts so a downstream conclusion does not
need to infer them from prose.

Exact sections inspected:

- `arxiv-2105-04752-black-box-audio-effects`: abstract; 1 Introduction;
  2 Method (2.1-2.4); 3 Experiments (3.1-3.3); 4 Results & Analysis
  (4.1-4.3); 5 Conclusion; references.
- `arxiv-2407-08889-diff-mst`: abstract; 1 Introduction (including 1.1);
  2 Method (2.1-2.6); 3 Experiment Design (3.1-3.3); 4 Objective
  Evaluation; 5 Discussion; 6 Conclusion; acknowledgments; ethical statement;
  references.
- `arxiv-2506-16889-ito-master`: abstract; 1 Introduction; 2 Related Works
  (2.1-2.2); 3 Methodology (3.1-3.4); 4 Experiments (4.1-4.4); 5 Results
  (5.1-5.3); 6 Conclusion; references.
- `dafx-2008-selective-unmasking`: abstract; 1 Introduction (1.1-1.2);
  2 Implementation (2.1-2.4); 3 Results; 4 Conclusions; references.
- `dafx-2009-automatic-target-mixing`: abstract; 1 Introduction; 2 Solving
  the Optimization Problem; 3 Target Equalization (3.1-3.2); 4 Estimators
  Evaluation; 5 Conclusions and Further Research; references.
- `dafx-2011-audio-effects-ontology`: abstract; 1 Introduction; 2 Semantic
  Web; 3 Music and Studio Ontology Frameworks; 4 Audio Effects Ontology
  (4.1-4.2); 5 Querying Metadata; 6 Conclusions; references.
- `dafx-2012-autonomous-multitrack-drc`: abstract; 1 Introduction;
  2 Dynamic Range Compression; 3 Loudness and Loudness Range; 4 System Design
  (4.1-4.4); 5 Evaluation (5.1-5.2); 6 Conclusions and Future Work;
  references.
- `dafx-2017-reference-controlled-drc`: abstract; 1 Introduction;
  2 Related Work; 3 Methods (3.1-3.2.4); 4 Evaluation (4.1-4.3);
  5 Conclusion and Future Work; acknowledgements; references.

## The reference-control problem must be typed before it is optimized

| Problem class | Evidence in this batch | Relationship between source and target | What is identifiable | What is not established | TrackSmith route |
|---|---|---|---|---|---|
| Matched-content linear inverse | DAFx-2009 | Same stems, same timing, same musical events; target created by linear gains/FIRs | Linear coefficients under alignment, rank, model-order, and conditioning assumptions | Different-song style, compression, nonlinear saturation, reverberation, panning, automation, listener preference | `matchedContentInverseProblem`; offline diagnostic/recovery only |
| Paired same-content black-box transformation | DeepAFx | Input and target are aligned versions of the same content processed by a stateful plug-in chain | A control predictor can be trained when paired examples and a suitable continuous parameterization exist | Unpaired learning, discrete/unstable controls, arbitrary plug-ins, long-form mastering judgment | `pairedTransformationLearning`; experimental offline training or candidate generation |
| Same-song synthetic style transfer | Diff-MST method 1; ITO-Master training | Two sections of one song share a synthetically imposed processor style | Recovery of generated processor attributes within the simulated console/chain | That mastering style is constant through a song; transfer to human-produced styles; preservation of section-dependent decisions | `syntheticStyleRecovery`; test harness and pretraining lane |
| Different-content feature matching | Diff-MST method 2; ITO-Master evaluation; DAFx-2017 realistic workflow | Reference and input differ in musical content, sometimes only loosely matched by genre/instrument | Movement toward selected summary features or embeddings | Why those traits were desired; unique parameter solution; artistic quality; arrangement/role equivalence | `scopedStyleReference`; only after typed scope and candidate-level evaluation |
| Cross-adaptive relationship control | DAFx-2008; DAFx-2012 | No external reference; processing depends on other tracks | Bounded relationships such as spectral overlap, loudness, or an LRA-derived heuristic | Which source should dominate, whether overlap is undesirable, or how much character to preserve | `crossTrackHypothesis`; protected role and user intent are mandatory inputs |
| Effect/provenance representation | DAFx-2011 | Metadata links concepts, implementations, transforms, parameters, events, and source tracks | Queryable identity and lineage if metadata is captured during production | Acoustic truth, perceptual correctness, or a complete universal taxonomy | Existing typed contracts, plans, snapshots, and provenance; RDF is optional |

### Why matched-content inverse recovery is not ordinary reference matching

DAFx-2009 minimizes the distance between a target mix and a mix reconstructed
from the same constituent tracks. For a linear feature map and gain vector
`alpha`, the least-squares solution is reported as:

```text
alpha_hat = (A^T A)^-1 A^T t
```

The FIR extension solves correlation-derived normal equations for a separate
filter on each track. This can work because musical content is held constant: the
remaining difference is attributable to the modeled linear processing. The
paper's six-track, 30 s experiments synthesize targets with a 256-tap extreme
multiband filter, an eighth-order 1 kHz Butterworth low-pass, and six random
128-tap FIR filters. Increasing FIR order drives Euclidean error toward zero for
those constructed cases.

The paper itself states that when target and input contain different music, its
method is not directly applicable because estimated parameters depend on content
as well as mixing. It also omits nonlinear dynamics, saturation, reverberation,
panning, time variation, regularization, alignment error, and perceptual
evaluation. Although the geometric discussion describes a positive-coefficient
subspace, the displayed unconstrained least-squares solution does not itself
enforce positivity. TrackSmith must therefore reject or constrain negative,
unbounded, ill-conditioned, or physically meaningless solutions.

### Why different-content matching is underdetermined

Diff-MST and ITO-Master use content-independent summary losses so audio with
different notes can be compared. That is necessary but not sufficient. Many
processor settings—and many artistically distinct mixes—share similar RMS, crest
factor, Bark-band spectrum, stereo width, stereo imbalance, learned embedding, or
Fréchet statistics. Optimizing such a loss selects one point in a broad
equivalence class; it does not discover the user's intended point.

The evidence directly exposes this problem:

- Diff-MST evaluates primarily with the same handcrafted audio-feature loss used
  to train its strongest system. Human mixes can score worse because engineers
  may make creative decisions the metric does not represent. The paper includes
  no listening test.
- ITO-Master improves audio-feature alignment while sometimes worsening all
  reported FAD embeddings. Its authors explicitly describe a tradeoff between
  alignment objectives and distributional realism, and warn that a poor
  reference can produce a poor result despite high alignment.
- DAFx-2017 moves crest factor and MFCC/GMM divergence toward reference notes,
  but it provides no human evidence that this sounds like the desired compressor
  behavior. Its more realistic workflow replaces the unavailable unprocessed
  reference with the new input itself, which changes the meaning of the feature
  ratio and generally degrades performance.

For TrackSmith, feature matching is therefore a proposal mechanism or comparison
signal. It is never the sole acceptance criterion.

## What the evidence supports measuring

### Strong or bounded measurement uses

- **Known-transform recovery.** With identical aligned content, a declared
  linear processor class, adequate model order, and a well-conditioned design
  matrix, least squares can estimate gains/FIR coefficients. This is useful for
  regression tests, transform auditing, and controlled reverse-engineering of
  TrackSmith's own renders.
- **Delay and polarity tolerance.** DeepAFx aligns output and target by
  cross-correlation and minimizes the smaller L1 error under zero- or
  180-degree phase. Its combined time/frequency loss is a useful regression-test
  pattern when a processor introduces group delay or polarity inversion.
- **Processor-state continuity.** DeepAFx correctly treats effects as stateful:
  non-overlapping frames are fed sequentially and separate plug-in instances are
  required for forward and perturbation evaluations. TrackSmith tests should
  likewise distinguish a stateless clip comparison from a stateful render.
- **Explicit production attributes.** RMS, crest factor, band energy, stereo
  width/imbalance, integrated loudness, true peak, gain reduction, and parameter
  trajectories can establish direction, bounds, and preservation failures when
  their scope is explicit.
- **Cross-track descriptors.** Spectral overlap or per-track dynamic descriptors
  can identify a condition worth auditioning. They do not decide which track is
  important or whether the condition is aesthetically wrong.
- **Provenance.** The DAFx-2011 separation among effect concept, implementation,
  transform/application, parameter state, timeline event, and source origin is
  directly useful. Correctly recorded metadata can answer questions that would
  otherwise require uncertain post-hoc inference.

### Measurements requiring qualification

- DAFx-2008 calls its meter perceptual, but its masking index is a thresholded
  FFT-power difference between one channel and the sum of the others. It is an
  amplitude-overlap indicator, not a psychoacoustic masking model. The paper uses
  a 1024-point FFT without a window and quantizes each bin as masked/unmasked;
  its improvement percentage is calculated from the same criterion the algorithm
  directly manipulates.
- DAFx-2012 adapts EBU loudness range from 3 s windows to 400 ms windows because
  10 ms appeared peak-like and 3 s appeared too smooth on its material. The
  authors call this choice somewhat arbitrary and state that perceived dynamic
  range across instruments and genres is not well understood. `Delta LRA` is a
  candidate descriptor, not a universal compressor objective.
- Diff-MST's feature weights—RMS 0.1, crest factor 0.001, Bark spectrum 0.1,
  stereo width 1.0, stereo imbalance 1.0—were chosen empirically. They define the
  optimization geometry and should not be interpreted as perceptual importance
  constants.
- ITO-Master's DRV is the channel-mean standard deviation of top-quartile detected
  peaks. It is a purpose-built proxy for compression consistency, not a general
  measure of preferred dynamics.
- MFCC, CLAP, codec embeddings, and FAD may describe particular similarity or
  distribution shifts. None is an oracle for transparent mastering, semantic
  instruction adherence, preservation, or expert preference.

## What isolated audio cannot establish reliably

The batch provides no reliable method for inferring the following from one
reference waveform alone:

- whether the user means overall mix, one source, an interaction, dynamics,
  spectral balance, space, emotional effect, arrangement, era, or genre context;
- which traits are desired versus merely present;
- which existing choices must be preserved or prohibited from changing;
- whether an apparent tonal or dynamic difference comes from production, source
  selection, performance, arrangement, recording, or mastering;
- whether a source should lead, support, mask intentionally, or remain imperfect;
- whether one numerical optimum is preferable to other valid interpretations;
- whether a short-section setting should remain static over a whole song;
- whether movement toward an embedding or handcrafted feature vector sounds
  better, more appropriate, or more like the user's intent.

TrackSmith should ask for clarification when these alternatives would produce
meaningfully different plans. When clarification is not required, it should
generate a small set of labeled interpretations rather than collapse ambiguity
into one hidden optimization target.

## Evidence reconciliation by technical question

### Can differentiable or approximate-gradient control help TrackSmith?

Yes, as an offline experimental optimizer with explicit bounds and a conventional
DSP render path.

DeepAFx predicts continuous controls for a stateful black-box chain. A deep
encoder consumes a 1.85 s context and a 46 ms current frame at 22.05 kHz, then
SPSA estimates a parameter-gradient direction with two perturbed effect
evaluations independent of parameter count `P`, instead of `2P` evaluations for
finite differences. With batch size `M`, the paper needs approximately `3M`
effect instances for forward and two-sided perturbations, versus `(2P+1)M` for
finite differences. Its tasks learn 21 tube-emulation controls, 17 gate controls,
and 50 mastering-chain controls.

This demonstrates a useful optimization pattern, not universal plug-in control.
Parameters are continuous; attack/release are fixed at 10 ms in the reported
model because the control frame is 46 ms; the mastering task is mono at 22.05
kHz; training is paired; and the authors list discrete controls, gradient
accuracy, paired-data dependence, and black-box brittleness as open problems.

Diff-MST and ITO-Master make the more TrackSmith-compatible design choice of
predicting or optimizing controls for an explicit DSP graph. This preserves
editability and avoids neural waveform-synthesis artifacts, but it does not make
the processing itself artifact-free or correct. Poor parameter choices can still
pump, distort, over-brighten, narrow, or erase character.

Consequence: keep inference/optimization outside the real-time audio thread;
produce bounded `ProcessingPlan` candidates; render with `DSPCore`; expose every
parameter delta; and let `PreviewWorkflow`, `StateStore`, and the revision path
retain the original and every accepted state.

### Does a fixed console provide a useful inductive bias?

Moderately. Diff-MST's per-track gain -> four-band EQ -> compressor -> pan chain,
followed by stereo master EQ and compression, constrains learning to interpretable
operations. Shared track encoders and self-attention provide a variable-track
architecture. The paper reports a 190 M-parameter controller and spectrogram
encoding system trained on 10 s excerpts from MedleyDB/Cambridge, with MTG-Jamendo
references for its different-content regime.

However:

- the model degrades when input track count exceeds what it was trained on;
- it predicts static settings, not automation;
- it omits reverb;
- whole-song embeddings may be too sparse;
- it does not explicitly model every relevant context or source role;
- objective metrics miss masking, balance, and creativity;
- the three main examples cover electronic, pop, and metal and have no listening
  evaluation.

The transfer is the inspectable-console pattern, not the learned parameter model
or its claim of arbitrary-track generalization.

### Can inference-time latent optimization improve a learned converter?

ITO-Master provides direct but limited evidence that it can improve the converter
on the objective it optimizes. The model trains on two 11.8 s sections of the
same synthetically processed song, assuming shared mastering style. At inference,
it holds the converter fixed and performs at most 100 RAdam steps on a 2,048-D
reference embedding using a content-independent auxiliary loss. The differentiable
white-box chain has 46 controls across six-band parametric EQ, distortion,
three-band compression, make-up gain, stereo imaging, and limiting; a black-box
TCN waveform converter is also evaluated.

On 200 30 s Jamendo songs, ITO improves the optimized audio-feature score and
some reference-embedding measures, but generally worsens the reported FAD values.
Direct optimization of all white-box parameters for up to 2,000 steps performs
poorly under the same content-independent objective. This is evidence that the
learned latent provides a useful prior and that the objective is inadequate for
unconstrained parameter search—not that latent search is inherently safer or
artistically correct.

The subjective study has ten participants with two to five years of production
experience, eight 30 s questions, an unprocessed low anchor, no high anchor, and
different-content references selected to be similar in genre/instrumentation.
The paper reports pairwise `p < 0.05` but does not provide the full score table,
multiple-comparison correction, or a formal MUSHRA design. Its text-conditioned
examples use one 11.8 s instrumental-rock excerpt and the prompts “Classic
Music,” “Metal Music,” and “Hip-Hop Music”; the analysis is qualitative and leans
on genre stereotypes. It is prototype evidence only.

### Does automatic multitrack compression converge on one good rule?

No. DAFx-2012 is useful precisely because its results reveal the limits of its
own rule.

The system equalizes per-track integrated loudness, automates make-up gain,
derives attack/release from spectral flux, and chooses threshold or ratio so
tracks with greater 400 ms LRA receive more compression. It targets a reduction
in the difference between highest and lowest per-track LRA:

```text
LRA_target(i) = LRA(i) - DeltaLRA_reduction *
                (LRA(i) - LRA(min)) / (LRA(max) - LRA(min))
```

Light, medium, and heavy touches target 3, 6, and 9 LU reductions. Parameter
values are found iteratively because the authors observe that LRA reduction is
not monotonic for every signal and cannot be predicted reliably in advance.

The seven 20 s excerpts were selected to have at least 9 LU reducible `Delta LRA`,
all tracks active, and audible differences among automatic modes. That selection
conditions the result. Fifteen critical listeners completed three modified
MUSHRA-like tests; one or two participants were removed from two test results
after correlation-based and manual inspection. All candidate mixes were
loudness-normalized. Light automatic compression scored competitively, heavy
compression scored poorly, and the no-compression mix often ranked among the
best. No mix averaged above “fair.” One expert result depended on heavily
compressing a vocal by 13.5 LU—more than the supposedly heavy automatic target—
showing that role-specific judgment can legitimately violate the global rule.

The product consequence is not “normalize track LRA.” It is:

- use cross-track dynamics as one hypothesis feature;
- preserve source role and transient/sustain intent;
- include `no change` as a serious candidate;
- prefer a bounded touch control over hidden aggressive automation;
- test on material that does not preselect for the algorithm's feasible region;
- do not claim expert parity from this small, low-scoring experiment.

### What does selective unmasking contribute?

DAFx-2008 contributes an early cross-adaptive control pattern: the user selects a
master channel, and other channels are attenuated as a Gaussian function of their
spectral-class distance from that master. An accumulative spectral-decomposition
classifier assigns each channel to one of `K=N` filter classes, where `N` is the
track count. The master remains at unity gain; dependent channels receive
full-band attenuation rather than EQ.

This is technically interesting but weak evidence for audible unmasking. The
classification resolution changes with track count; the decomposition filter
bank boosts lows and rolls off highs; the analysis updates every 1 ms; the metric
uses an unwindowed 1024-point FFT; and no dataset, listening test, numeric
benchmark, CPU budget, or psychoacoustic model is reported. A proposed
pseudo-stereo/directional extension is speculative.

TrackSmith may borrow the explicit protected-role control and cross-track feature
dependency. It should not borrow automatic full-range ducking as a default or
call the metric psychoacoustic masking.

### What should the semantic/effect representation preserve?

DAFx-2011 argues that one hierarchy is insufficient because perceptual,
implementation, and audio-engineering views answer different questions. It uses
RDF/OWL triples to distinguish:

- an effect as a perceptual/physical phenomenon;
- a processor or implementation;
- a transformation/application event;
- a parameter set;
- a timeline event created by processing;
- the original track and project provenance.

Its SPARQL example queries an onset created by an echo transform and follows that
event back to the implementation and source track. This supports TrackSmith's
typed/provenance design. It does not validate the paper's cited mapping from
effects to perceptual attributes, demonstrate a complete ontology, or require
TrackSmith to adopt Semantic Web technology. Existing Swift types and JSON
contracts can preserve the same distinctions more naturally.

### Can a regression model infer compressor settings from a reference sound?

Only in the very narrow DAFx-2017 setup. The paper trains separate linear and
random-forest regressors for threshold, ratio, attack, and release. Training
examples are synthesized by varying one parameter at a time on 60 violin notes
or 12 snare samples from RWC while holding the others fixed. Features include
framewise RMS mean/variance, spectral-centroid and spectral-variance summaries,
attack/release envelope descriptors, and a ratio between processed and original
features.

The first workflow unrealistically requires both processed and unprocessed
versions of the reference. The “realistic” workflow substitutes the new input for
the unavailable unprocessed reference. Objective crest-factor and MFCC/GMM
divergence usually move toward the reference, but results worsen and are
instrument dependent. The 3-5 s loop experiment treats an entire monophonic loop
as one note, reports only modest divergence changes, and is unsatisfactory for
threshold. There is no polyphony, multitrack context, make-up gain, knee, parameter
interaction study, source generalization, or listening test. The authors call the
similarity model a starting point and the research early phase.

This paper supports source-conditioned feature design and a cheap candidate
initializer. It does not support production deployment or the inference that one
reference sound uniquely determines compressor parameters.

## Contradictions and tensions that TrackSmith must preserve

| Tension | Evidence | Resolution for TrackSmith |
|---|---|---|
| “Arbitrary number of tracks” versus degradation beyond trained track count | Diff-MST architecture is permutation/track-count flexible, but discussion reports performance decline beyond training count | Separate architectural capability from validated operating range; stress-test track counts and expose out-of-distribution uncertainty |
| “Avoids artifacts” versus ordinary DSP failure | Diff-MST avoids neural waveform-generation artifacts by rendering a deterministic console | Say only that synthesis artifacts are avoided; still test pumping, clipping, phase, harshness, instability, and character loss |
| Feature alignment versus perceived quality | ITO improves AF/embedding metrics while FAD often worsens; Diff-MST trains/evaluates on related AF features | Treat objectives as competing signals; use Pareto candidates and listening, not one scalar |
| “User control” versus latent opacity | ITO optimizes a 2,048-D embedding; black-box converter parameters are not inspectable | Only white-box parameter deltas count as editable control; latent state is internal proposal machinery |
| “Perceptual masking” versus amplitude overlap | DAFx-2008 uses thresholded FFT-power differences and no listening evidence | Name the measurement spectral-overlap evidence; do not infer audibility or importance |
| LRA-coherence rule versus source role | DAFx-2012 light global rule competes with no DRC; expert vocal decision violates proportional allocation | Add role, musical function, transient/sustain goal, and `no change`; do not globalize one descriptor |
| “Target mixing” versus different-content references | DAFx-2009 succeeds only because target and stems share content; paper says general target case is not directly applicable | Route matched-content recovery separately and fail closed on content mismatch |
| “Realistic reference workflow” versus laboratory simplicity | DAFx-2017 uses isolated notes and 3-5 s monophonic loops, no listening | Classify as early prototype evidence; require polyphonic/source/context/listening validation |
| Mastering similarity versus loudness bias | DeepAFx's mastering listening samples were not loudness-normalized because loudness was part of the task | Re-run both task-faithful and loudness-controlled comparisons; never let loudness alone decide preference |
| Genre-prompt steering versus genre knowledge | ITO's three text examples are qualitative on one rock excerpt | Treat as prompt sensitivity, not a genre/aesthetic map or proof of semantic understanding |

## Engineering consequences and acceptance tests

No core product code is changed by this review. The table maps evidence to future
work within the architecture already present.

| Evidence-grounded consequence | Reliability and conditions | Affected module(s) | Suggested implementation pattern | Must not be inferred | Acceptance test | Status |
|---|---|---|---|---|---|---|
| Require a typed reference-problem class before feature extraction or optimization | Strong architectural consequence from incompatible problem definitions across all eight sources | `AgentCore.ProductionIntelligenceContracts`, `ProductionIntelligenceCoordinator`, `ProductionHypothesisEngine` | Add/extend a reference interpretation carrying scope, relationship (`sameContent` / `differentContent`), desired/preserved/prohibited traits, confidence, and clarification state | A waveform or song name supplies scope automatically | Ambiguous reference requests cannot produce an executable plan until clarified or represented as multiple labeled hypotheses | Production-ready design requirement |
| Keep matched-content inverse recovery separate | Direct synthetic evidence under linear, aligned, full-rank conditions | Future offline analysis utility, `AudioAnalysis`, `DSPCore` test tooling | Constrained/regularized least squares with condition-number, alignment, coefficient-bound, and residual diagnostics | Recovery generalizes to unrelated songs or nonlinear effects | Recover known gains/FIRs; reject misalignment, collinearity, missing stems, negative/unbounded coefficients, and nonlinear targets with explicit diagnostics | Prototype-worthy |
| Use differentiable/SPSA/latent search only outside the real-time audio thread | Direct algorithm evidence; runtime, state, and brittleness limits remain | Future offline optimizer, `PreviewRenderer`, `DSPCore`, `PlanSchema` | Optimize bounded controls on cloned state; emit an ordinary inspectable `ProcessingPlan`; never run model/network work in render callback | A gradient is stable, a local optimum is good, or every plug-in is differentiable | State-continuity, deterministic replay, bounded parameters, cancellation, discrete-control, crash/brittleness, CPU/memory, and no-real-time-allocation tests | Experimental |
| Prefer explicit deterministic processor graphs as the execution surface | Moderate cross-paper support and strong architecture fit | `DSPCore`, `PlanSchema`, `PreviewWorkflow` | Learned/semantic layer proposes controls; deterministic graph renders; every node and delta remains editable/bypassable | Explicit DSP makes a result artistically correct or artifact-free | Parameter round-trip; identical replay; bypass null; revision changes only authorized nodes; artifact guardrail suite | Production-ready principle |
| Treat content-independent style metrics as candidate objectives, never approval oracles | Direct contradictions among AF, FAD, embeddings, and human creativity | `AudioAnalysis`, `ProviderEvaluationHarness`, future evaluation tooling | Multi-objective vector with separate style-direction, preservation, quality, constraint, and complexity terms; retain Pareto alternatives | Lower AF/FAD/embedding distance means “better” | Construct adversarial candidates with equal summary features but audible faults; metric must not auto-commit them | Prototype-worthy |
| Include `no change` and multiple touch/interpretation candidates | DAFx-2012 listeners often favored no DRC; heavy mode failed | `ProductionHypothesisEngine`, `PreviewWorkflow`, `ProductionRevisionCoordinator` | Generate conservative/alternate/no-op candidates with explicit expected effects and preservation tradeoffs | Every diagnosed deviation requires processing | Loudness-matched blinded test includes no-op; system can select/retain no-op without manufacturing an intervention | Production-ready design requirement |
| Cross-track metrics require an explicit protected/leading role | DAFx-2008 control is user-selected; DAFx-2012 exception is role-specific | `SourceAwareAnalysis`, `ProductionHypothesisEngine` | Compute relationships first, then bind action to a role-aware hypothesis; prefer targeted EQ/level/pan candidates over unconditional full-band attenuation | Spectral overlap is masking, and masking is always undesirable | Same spectra with swapped musical roles produce different hypotheses but identical measurements; no action without role evidence | Prototype-worthy |
| Preserve effect concept, implementation, execution, parameter state, result, and source provenance separately | Direct representation/query demonstration; no need for RDF | `ProductionIntentVocabulary`, `PlanSchema`, `StateStore`, `SessionCore` | Stable typed IDs, versioned implementations, transaction/snapshot lineage, created-event provenance | Ontology membership proves an audible effect | Round-trip and migration tests; query any committed result back to source snapshot, plan node, implementation version, parameters, and revision | Production-ready principle |
| Evaluate static versus time-varying control and section consistency explicitly | Diff-MST static limitation; DeepAFx frame control; DAFx-2009 time-varying extension unresolved | `AudioAnalysis`, future optimizer, `PreviewWorkflow` | Section-aware analysis with smoothing/automation proposals bounded by musical landmarks; retain static baseline | One short-window optimum is valid for a whole song | Verse/chorus/bridge stress set; automation continuity, overshoot, long-term loudness, and section-preservation tests | Experimental |
| Text/audio embedding steering must pass semantic, acoustic, and stereotype checks | ITO qualitative demonstration only | Future provider-neutral reasoning/evaluation lane; not DSP core | Use embedding only to rank explicit hypotheses; require terms to resolve through vocabulary and source context | CLAP response proves genre competence or production quality | Prompt paraphrase, negation, source mismatch, genre stereotype, and preservation-adversarial cases with human review | Deferred/experimental |

## Suggested bounded optimization contract

If TrackSmith later implements offline parameter search, the objective should not
be one reference-distance scalar. A safer formulation is:

```text
minimize over bounded theta:
    lambda_style     * L_scoped_style(render(theta), reference)
  + lambda_preserve  * L_preservation(render(theta), original, locks)
  + lambda_quality   * L_technical_guardrails(render(theta))
  + lambda_change    * ||theta - theta_current||_weighted

subject to:
  theta_min <= theta <= theta_max
  all prohibited-change checks pass
  loudness / true-peak / stability constraints pass
  render is deterministic and state-continuous
```

The system should retain several nondominated candidates when objectives conflict.
The frontier model may explain why candidates differ and ask which tradeoff the
user wants; it must not silently rewrite the bounds or execute audio processing.

Minimal routing pseudocode:

```text
interpretation = resolveReference(request, registry, sourceContext)

if interpretation.scopeIsMateriallyAmbiguous:
    return clarificationOrMultipleHypotheses(interpretation)

switch interpretation.problemClass:
case matchedContentInverse:
    require alignedSameContent && declaredTransformFamily
    candidates = constrainedInverseSolve(...)
case scopedDifferentContentStyle:
    candidates = boundedMultiObjectiveSearch(...)
case crossTrackRelationship:
    require protectedRole
    candidates = roleAwareCrossTrackHypotheses(...)

for candidate in candidates:
    require preservationChecks(candidate)
    require technicalGuardrails(candidate)
    exportInspectablePlanAndPreview(candidate)
```

## Evaluation design implied by the batch

One benchmark cannot answer every claim. TrackSmith should maintain four distinct
lanes.

### 1. Transform-recovery tests

Purpose: determine whether a known processing transformation can be recovered or
replayed.

- same aligned content;
- synthetic known gains, FIR/EQ, compression, and controlled black-box chains;
- report parameter error, waveform residual, delay/polarity tolerance, condition
  number, bound violations, and deterministic replay;
- stress alignment offsets, polarity, noise, collinear tracks, missing stems,
  model mismatch, discrete controls, and stateful effects.

Passing this lane says nothing about different-song style or preference.

### 2. Scoped attribute-transfer tests

Purpose: determine whether a declared trait moved in the requested direction.

- different-content input/reference pairs with human-authored scope labels;
- separate target traits, preserved traits, prohibited traits, and source role;
- include multiple valid interpretations and incompatible-reference cases;
- report each feature separately rather than only a weighted aggregate;
- include a no-op and simple deterministic baselines;
- evaluate same genre, cross genre, source mismatch, arrangement mismatch, and
  poor-reference cases.

Passing this lane says that selected attributes moved, not that the result is a
good mix.

### 3. Technical and preservation guardrails

Purpose: reject unsafe or collateral processing.

- sample/true peak, loudness, DC, NaN/Inf, phase/mono, stereo imbalance, spectral
  outliers, clipping, pumping, silence/noise amplification, transient damage;
- render-thread allocation and timing; state continuity; repeatability;
- locked-node and locked-attribute enforcement;
- local revision: changing one accepted element leaves all others bit-identical
  or within declared tolerances;
- parameter bounds, smoothing, automation continuity, and bypass null tests.

Passing this lane is necessary but not evidence of artistic success.

### 4. Human production judgment

Purpose: test appropriateness, preference, explanation, and workflow.

- loudness-controlled and task-faithful variants reported separately;
- blinded randomized comparisons with no-op, conservative baseline, competing
  hypothesis, and meaningful degraded anchors where appropriate;
- source/genre/experience stratification and adequate power;
- separate ratings for intent match, source role, preservation, artifacts,
  coherence, preference, and confidence;
- record rejected alternatives and stopping reasons;
- do not call a study MUSHRA unless its reference/anchor/training/reporting design
  actually satisfies the applicable standard.

## Source-level transfer limits and non-claims

### DeepAFx (`arxiv-2105-04752-black-box-audio-effects`)

Direct evidence:

- SPSA can train a continuous controller through selected stateful black-box
  effects with two perturbation evaluations per gradient estimate;
- sequential framing and separate effect instances address state corruption;
- a delay/polarity-tolerant time/frequency loss supports paired training;
- on five examples per task and 17 participants, the reported mastering result
  was rated closer to the hidden reference than the tested online mastering
  service.

Limits/non-claims:

- mastering samples were monophonic, 22.05 kHz, four seconds, and not
  loudness-normalized; paired data came from 138 Cambridge tracks;
- the online service version/settings and generality are not established;
- the result does not prove expert mastering, unpaired transfer, arbitrary plug-in
  robustness, discrete-control optimization, or long-form coherence.

### Diff-MST (`arxiv-2407-08889-diff-mst`)

Direct evidence:

- an explicit differentiable console can be driven by a shared-track encoder and
  transformer to predict editable static controls;
- the AF-trained 16-track model obtains the lowest reported AF loss and FAD among
  evaluated automatic baselines on the authors' objective setup;
- self-supervised same-song and unrelated-reference training regimes are feasible.

Limits/non-claims:

- no listening test; only three main songs and 100 unseen objective cases;
- metric circularity, inconsistent evaluation loudness normalization, random
  unrealistic reference pairs, static settings, no reverb, track-count decline,
  and missing full-song context;
- does not prove arbitrary-track robustness, human-quality mixing, correct
  reference interpretation, or artifact-free DSP.

### ITO-Master (`arxiv-2506-16889-ito-master`)

Direct evidence:

- optimizing a learned reference embedding for at most 100 steps can improve the
  selected AF/reference objectives more efficiently than 2,000-step direct
  parameter optimization in the reported setup;
- a 46-control differentiable mastering chain keeps white-box outputs inspectable;
- a small subjective study favors proposed variants over tested baselines.

Limits/non-claims:

- synthetic training styles, same-song style-stationarity assumption, 10 listeners,
  eight questions, no high anchor, incomplete statistical reporting;
- AF-versus-FAD conflict and explicit bad-reference risk;
- text steering is a qualitative one-excerpt demonstration, not semantic or genre
  validation; black-box latent control is not inspectable user control.

### Selective unmasking (`dafx-2008-selective-unmasking`)

Direct evidence: an implemented control contour can attenuate channels according
to a master-selected spectral class and increase its own binary FFT-overlap
metric.

Limits/non-claims: no psychoacoustic model, listening test, corpus, parameter
benchmark, or computational report; track-count-dependent classes and an
unwindowed FFT. It does not establish perceptual unmasking, preference, or a
default production strategy.

### Automatic target mixing (`dafx-2009-automatic-target-mixing`)

Direct evidence: least squares and correlation-derived FIR estimation recover
constructed linear transforms increasingly well as model order approaches the
target under same-content conditions.

Limits/non-claims: no unrelated reference, listening, nonlinear/time-varying
processor, regularization, alignment stress, or constrained coefficients. It is
not evidence for general reference-song matching.

### Audio-effects ontology (`dafx-2011-audio-effects-ontology`)

Direct evidence: multiple taxonomic views and explicit transform/provenance links
can represent and query an effect-created event.

Limits/non-claims: no user study, coverage metric, acoustic validation, or proof
that perceptual links are correct. RDF/OWL is an implementation option, not a
product requirement.

### Autonomous multitrack DRC (`dafx-2012-autonomous-multitrack-drc`)

Direct evidence: on deliberately eligible 20 s excerpts, light-touch LRA-based
automation scored competitively with one expert-manual condition; heavy
automation was disliked and no DRC was often competitive.

Limits/non-claims: seven selected excerpts, one expert manual mixer, 15 listeners,
participant exclusions, modified MUSHRA design, low average scores, arbitrary
400 ms LRA adaptation, and a priori global hypothesis. It does not establish
expert parity or universal LRA allocation.

### Reference-controlled DRC (`dafx-2017-reference-controlled-drc`)

Direct evidence: random forests generally estimate separately varied compressor
parameters better than linear regression and move selected objective features
toward reference on in-domain notes/loops.

Limits/non-claims: one parameter varied at a time, tiny instrument set, isolated
or monophonic material, feature-ratio shortcut, no listening test, no full
compressor interactions or mix context. It does not establish perceived
similarity, unique settings, or production readiness.

## Product implications ranked

1. **Production-ready requirement — typed reference interpretation.** Make the
   matched-content/different-content distinction, scope, desired/preserved/
   prohibited traits, and uncertainty explicit before planning.
2. **Production-ready principle — deterministic, editable execution.** Preserve
   the existing explicit DSP graph, preview/revision/commit/bypass workflow, and
   provenance. Research models may propose; they must not become an opaque audio
   authority.
3. **Prototype — multi-objective candidate evaluation.** Add style-direction,
   preservation, technical-quality, and minimal-change scores as separate outputs,
   then retain nondominated candidates.
4. **Prototype — controlled inverse/recovery harness.** Use matched-content
   synthetic cases to verify TrackSmith's own analysis and renders, not as a
   consumer-facing “copy this record” feature.
5. **Prototype — role-aware cross-track hypotheses.** Use overlap and dynamics
   evidence only after identifying protected role and musical context.
6. **Experimental — offline bounded parameter optimization.** Compare a simple
   search, SPSA, differentiable control, and learned-latent initialization on the
   same explicit graph, with deterministic replay and guardrails.
7. **Deferred — embedding-led text/genre steering.** The batch does not support
   deployment without substantially stronger semantic, preservation, long-form,
   and listening evidence.

## Bottom line

The strongest transferable idea is not automatic matching. It is a disciplined
separation of concerns:

- professional intent determines the reference's scope;
- source-aware analysis establishes what is actually present;
- a typed hypothesis states the proposed interpretation and what must not change;
- optimization may search only within that contract;
- deterministic DSP produces an editable candidate;
- objective metrics verify direction and guardrails;
- human audition decides whether the production judgment is right;
- provenance keeps every decision reversible and explainable.

That design is more conservative than one-shot reference matching and more useful
to an excellent producer: it knows when a mathematical inverse is identifiable,
when a reference is ambiguous, when several answers are valid, when no processing
is preferable, and when a metric cannot stand in for listening.

# Corpus review and disposition

## Package 005 — Automation candidate boundary

`research/community_knowledge/packages/tracksmith-corpus-005-automation/` is an immutable
`tracksmith-corpus-package/1.0` input (sequence 5). Its registry-aware preflight resolves
the four declared standardized dependencies through the explicit legacy map to Packages
1–4; legacy package identities retain `contract_version: null` and are not recast as the
new contract. Package 005 contains 240 canonical candidates, 5,280 utterances, 720
scenarios, 1,200 retrieval evaluations, 36 contradictions, 44 myths, 63 sources, and
240 each claim, strategy, procedure, and provenance records. The shared
`CommunityCandidateCorpus` ships only a compact candidate projection and is still
`lexical_structured_provisional` through `search_candidate_corpus`.

All P5 canonical, utterance, scenario, evaluation, contradiction, myth, claim, strategy,
procedure, and provenance records remain `candidate_not_yet_human_reviewed`. Procedures
remain `candidate_unverified_on_installed_logic`, `execution_authority:false`, and are
represented at runtime only by candidate ID plus status: no steps, locations, show-me or
visual queries, navigation, scenario, test, or evaluation data ship in the app resource.
The 32 documentary source records retain `candidate_reviewed_documentary`; the other 31
retain `candidate_not_yet_human_reviewed`, with original evidence class/access/version
scope preserved and conservatively mapped A/B/C. No source or candidate is promoted.

The explicit P5 disagreement map covers all 36 contradictions and 44 myths. Every target
is a P5 canonical card with a source intersection, is reachable, and is capped at three
contradictions, two myths, and four combined attachments. Retrieval accounting is stored
separately: supplied normalized unique exact is 480 and nonexact is 720; the runtime-safe
projection recomputes those counts after recursive leak scanning rather than assuming
them. Current projection evidence is 480 runtime-safe exact and 720 runtime-safe nonexact.
This is migration integrity, not a claim of listening, installed-Logic verification, or
automation execution authority.

This catalog records how every unique PDF family in the original 70-source pre-Logic supplied
and manifest-driven corpus affects the product. Duplicate copies and alternate
publication downloads are counted once. “Core” means full-text engineering review;
“supporting” means method/results/limitations review; “peripheral” means systematic
screening with no current MVP dependency. Following the 2026-07-19 full relevant
MusicSem review, those 70 PDFs comprise 27 Core/full-read, 35 Supporting, and eight
Peripheral payloads. The four separately governed, completely read Logic Pro
manuals made the original combined review cohort 74 unique PDFs and 31 deep/Core-
equivalent, 35 Supporting, and eight Peripheral. They are no longer the complete
current archive denominator.
Supporting and Peripheral are valid dispositions, but they are **not** claims of
full-text deep review. The per-slot [SOURCE_AUDIT.md](SOURCE_AUDIT.md) remains scoped to
the original 61-unique-PDF supplied snapshot; the nine-paper expansion ledger is in
[TRACKSMITH_PRODUCER_JUDGMENT_EXPANSION.md](TRACKSMITH_PRODUCER_JUDGMENT_EXPANSION.md),
and the four Logic manuals are covered by their dedicated atlases.

## Producer judgment, language, workflow, and quality

| Source | Review | Product consequence |
|---|---|---|
| Communication and Reference Songs in the Mixing Process | Core | Treat rough mixes and references as negotiated, scoped intent with preservation constraints and iterative feedback. |
| MixAssist | Supporting | Evaluate audio grounding separately from fluent instructional dialogue; favor an explainable teaching assistant over autonomous mixing. |
| AI's Impact on Workflow in Music Production | Core | Optimize speed and menial work while preserving appropriation, correction, and creative agency. |
| Word Embeddings for Automatic Equalization | Core | Semantic embeddings can seed source-aware hypotheses but remain below human labels and cannot define universal EQ presets. |
| Preference-Bearing Intent in Music Queries | Core | Keep desired, rejected, and referential attributes distinct; similarity mentions are not automatically positive targets. |
| MusicSem | Full relevant source read | Cover descriptive, contextual, situational, atmospheric, and metadata language while retaining subjectivity, metric, model-assisted-construction, and dataset-bias boundaries. |
| Semantic Timbre Dataset for Electric Guitar | Core | Use source-specific vocabularies and magnitude tests; do not generalize synthetic monophonic-guitar mappings to other sources. |
| Trends in Audio Mixes and Masters | Core | Use population patterns to prioritize QA, never as universal tonal, dynamics, width, or loudness targets. |
| Emotion and Music Production Quality | Supporting | Stratify listening tests by expertise and keep emotional outcomes separate from technical defect measures. |

## Core production, DSP, analysis, and standards

| Source | Review | Product consequence |
|---|---|---|
| Digital Dynamic Range Compressor Design—A Tutorial and Analysis | Core | Branching feed-forward detector, explicit time convention, soft knee, artifact tests. |
| Parameter Automation in a Dynamic Range Compressor | Core | Time-varying crest/flux control and loudness-based makeup; retain user meta-control. |
| Intelligent Multitrack Dynamic Range Compression | Core | Dynamics decisions are spectral and cross-track; do not normalize isolated stems blindly. |
| Intelligent Audio Production Strategies Informed by Best Practices | Core | Mixing is context/masking/structure dependent; use hindsight and reject universal rules. |
| Style Transfer of Audio Effects with Differentiable Signal Processing | Core | Audio-domain objectives over visible DSP parameters are preferable to parameter error. |
| ST-ITO | Core | Offline bounded search can control arbitrary deterministic effects; specialized style metric required. |
| Automatic Multitrack Mixing with a Differentiable Mixing Console | Core | Shared console is a useful inductive bias; avoid opaque waveform output for stable core. |
| Automatic Equalization for Individual Instrument Tracks | Core | Contextual target spectra, response-domain loss, bounded stable bands, real-world data. |
| Essentia | Core | Modular, versioned descriptors and aggregation; semantic inference must be separate. |
| YIN | Core | Monophonic F0 plus aperiodicity/confidence; no default pitch correction. |
| Perception & Evaluation of Audio Quality in Music Production | Core | Quality is multidimensional and listener/context dependent; bands are descriptive only. |
| SRMR Variants | Core | Optional calibrated room cue for speech/vocals, not a universal music dereverb score. |
| ITU-R BS.1770-5 | Core | Normative K-weighted gating and true-peak implementation. |
| EBU R 128 | Core | Programme loudness workflow; -23 LUFS is not an artistic target. |
| ITU-R BS.1534-3 MUSHRA | Core | Anchors, hidden reference, training, randomization, power, robust statistics. |
| Deep Learning and Intelligent Audio Mixing (WIMP 2017) | Core | Expert mixes beat merely clean automation; domain knowledge and creative goals remain necessary. |

## Intelligent mixing, mastering, and workflow evidence

| Source | Review | Product consequence |
|---|---|---|
| Automatic Music Mixing with Deep Learning and Out-of-Domain Data | Core | Domain normalization and professional listening tests; production value, clarity, excitement remain separate. |
| Deep drum mixing with Wave-U-Net | Supporting | End-to-end stem transformation is feasible but less inspectable; use as future comparison baseline. |
| Machine Learning in Audio Mastering: A Comparative Study | Supporting | Mastering models require matched data and perceptual evaluation; no universal black-box master. |
| AI-Assisted Music Production: A User Study on Text-to-Music Models | Core | Partial revision, DAW integration, tempo/key control, and result preservation matter more than one-shot generation. |
| HAIM: Human-AI Music Datasets for AI Music Production Tracking | Supporting | Preserve provenance at stage/node/snapshot level; binary “AI” labels do not describe hybrid workflows. |
| AI Mastering Detector web abstract | Peripheral | Detection artifacts are not quality features and should not drive processing decisions. |

## Foundation-model audio editing

| Source | Review | Product consequence |
|---|---|---|
| Audio Editing in the Era of Foundation Models: A Survey | Core | Evaluate target change, preservation, naturalness, coherence, and instruction adherence separately. |
| AUDIT | Supporting | Instruction/input/output triplets and preservation-aware training; future offline asset module only. |
| Audio Editing with Non-Rigid Text Prompts | Supporting | User language can underspecify scope; planner must resolve editable and preserved attributes. |
| Token-Based Audio Inpainting via Discrete Diffusion (paper and alternate paper-page PDF) | Supporting | Bounded gaps are more tractable than arbitrary restoration; require explicit region and new asset. |
| SemanticAudio | Supporting | Semantic/acoustic factorization is promising but short-context evaluation and proxy metrics limit claims. |
| Audio ControlNet | Supporting | Temporal control signals help insertion/removal; not a substitute for deterministic production DSP. |
| AUDEDIT | Supporting | Flow-based inversion-free editing is a future optional engine; preservation tests remain mandatory. |
| Unsupervised Single-Channel Separation with Diffusion Source Priors | Supporting | Separation is expensive and uncertain; keep out of MVP and preserve mixture source. |
| FlowEdit project capture | Peripheral | Cross-modal method context only; no direct stable-MVP dependency. |

## Audio-language models and reasoning

| Source family | Review | Product consequence |
|---|---|---|
| Surveys of large audio/speech language models (four surveys) | Supporting | Provider abstraction, calibration, privacy, and task-specific evaluation; no model gets direct DSP authority. |
| AIR-Bench (two publication copies plus project page) | Supporting | Audio comprehension benchmarks are broader than captioning but do not validate mix engineering. |
| AudioDER | Supporting | Deduplication matters for benchmark validity; maintain contamination-aware planner tests. |
| SALMONN (multiple copies/model page) | Supporting | General hearing interfaces are promising; hallucination and domain limitations require typed tools. |
| Qwen2-Audio and Qwen2.5-Omni | Supporting | Candidate providers only; shipped behavior remains schema-validated and manually editable offline. |
| Moshi and codec explainer/project page | Peripheral | Real-time dialogue architecture informs UX latency, not the audio render thread. |
| video-SALMONN | Peripheral | Audio-visual reasoning is outside initial scope. |
| Audio-Visual Intelligence in Large Foundation Models | Peripheral | Future multimodal session understanding only. |
| Music I Care About benchmark | Supporting | Music reasoning must be tested on user-selected music and explicit tasks, not assumed from generic scores. |

## Learned representations and objective metrics

| Source | Review | Product consequence |
|---|---|---|
| Human-CLAP | Supporting | Human-aligned embeddings may improve ranking but still need production-effect calibration. |
| Large-scale CLAP | Supporting | Useful for semantic prompt/audio alignment, not transparent edit quality or preservation. |
| Adapting Fréchet Audio Distance for Generative Music | Core | FAD depends on sample size, embedding, reference quality, and genre; never a single-preview quality oracle. |
| Benchmarking Music Generation Models and Metrics via Human Preferences | Supporting | Human preference remains gold standard; metric correlations vary by quality dimension. |
| TTA-Bench (journal/arXiv variants) | Supporting | Evaluate quality, robustness, generalization, fairness, and safety as distinct dimensions. |
| Objective speech quality metrics for neural codecs | Supporting | Codec/speech metrics are degradation-specific and not validated as music-production judges. |
| Robustness of ViSQOL, PESQ, and POLQA | Supporting | Metric rankings change with noise/network conditions; do not transplant speech MOS claims. |
| ViSQOL repository and objective-metrics web captures | Peripheral | Candidate regression tooling only after music/edit calibration. |

## Generative audio/music and codecs

| Source family | Review | Disposition |
|---|---|---|
| AudioLDM 2 and AudioLDM project/docs | Supporting | Future sound-generation/edit provider; explicit upload and new-asset workflow. |
| MusicGen, MusicGen-Stem, and benchmark page | Supporting | Stem-conditioned generation is outside MVP; provenance and alignment remain relevant. |
| Persian MusicGen | Peripheral | Valuable evidence for cultural/domain bias; no current DSP dependency. |
| Score-aware and state-space text-to-music papers | Peripheral | Generation training research outside initial product scope. |
| Symbolic music prompting paper/page | Peripheral | MIDI generation is an explicit non-goal for MVP. |
| Vision-to-Music survey | Peripheral | Outside initial scope. |
| DAC-JAX, DAC docs/repository, and neural-codec sources | Supporting | Possible future model transport/representation; never in the real-time stable graph without profiling. |
| TTA and detector comparison blogs | Peripheral | Product/web claims are not scientific evidence and do not drive architecture. |

## Non-PDF sources requiring explicit evidence boundaries

| Source | Review | Product consequence |
|---|---|---|
| Multimodal Auditory Intelligence pasted synthesis (item 036) | Non-evidence | Navigation aid only. It is a secondary synthesis, so every claim used by the product must be checked against the cited primary source. |
| AuditEval repository (item 041) | Supporting | Candidate preservation/quality evaluation tooling; it is not yet validated for this product's stable DSP graph. |
| AudioCraft CLAP-consistency API documentation (item 076) | Peripheral | Implementation reference only; an API definition is not perceptual validation. |
| CLAP feature-extraction blog (item 079) | Peripheral | Navigation and implementation context only; it is not primary research evidence. |

## Corpus-level observations

- Duplicate publication copies were common; content hashes prevent double counting.
- The current live audit contains 131 non-quarantined searchable PDF paths
  representing 104 unique payloads plus seven quarantined PDF paths. It contains 81
  non-quarantined searchable HTML paths representing 79 hashes, of which 78 are
  usable and one is empty; two non-usable paths share that empty digest. Three HTML
  paths remain quarantined. These current archive counts do not alter the original
  70-PDF disposition cohort above.
- The two supplied TXT source payloads are now content-hash indexed separately. Item 023 is a fallback extraction recovered by the standalone WIMP 2017 PDF; item 036 is a pasted synthesis and is not independent evidence.
- TTA-Bench item 074 is recovered through item 023 and the supplied WIMP 2017 PDF for *Deep Learning and Intelligent Audio Mixing*. Item 075, *Hybrid Transformers for Music Source Separation*, has no supplied payload; the gap is recorded and is nonblocking because source separation is outside the stable MVP.
- A newly discovered untracked part-02 directory contributes one PDF path and one HTML path but no new payload hash. It remains untouched as user-supplied research and is not part of the commit scope.
- Several sources are 2026 preprints. They inform experiments, not production promises.
- Many generative papers evaluate short clips and use proxy metrics. Long-form continuity and non-target preservation remain weakly established.
- The most mature evidence for the MVP is classic DSP, standards-compliant measurement, immutable state, and structured user control.
- The most promising research path after MVP is effect-sensitive offline parameter optimization over the same deterministic graph.
- Archive/index completeness and review depth are separate. In the original
  70-PDF review cohort, 43 payloads remain below Core/full-read depth. The current
  104-PDF archive uses the unified per-payload source ledger; no derived claim is made
  that the newly visible payloads have equivalent review depth.

## Implemented consequences verified against this review

- Preview export now measures each level-matched option against its preceding viable sibling and rejects a collapsed option below the bounded pairwise difference gate. The manifest retains the pairwise metrics, so distinctness is auditable rather than inferred from strength labels.
- Analysis schema 1.1 now carries versioned, bounded metric series: 200 ms RMS and crest-factor timelines with nominal 50% overlap (maximum 2,048 selected windows), plus normalized positive spectral-flux timelines (maximum 512 analyzed spectral windows).
- Tests cover sibling identity/distinctness and confirm that the crest timeline is level invariant and that the timeline bounds are enforced.

## Vocal + Quantization Candidate Corpus v1

`research/knowledge/community-vocal-quantization-v1/` is an immutable,
content-addressed input package. The package validator and importer verify its
manifest hashes before any projection is generated.

The import registers 34 sources in the existing general Tutor source registry
and creates 642 native queue entries: 214 claims, 214 strategies, and 214
procedure candidates. The initial import leaves every entry in
`awaitingReview`; its original package status is retained in
`originalReviewStatus`. Later deterministic regenerations preserve valid named
review events while refreshing package/provenance fields. There is no named
review event, promotion, or trusted candidate created by this initial import.

The generated `CommunityCandidateCorpus` is a read-only query/evaluation
projection with 214 canonical cards, 3,290 utterance links, and 428 scenarios.
It carries only candidate teaching material and partitioned provenance:

- Tier A source IDs are documentary support.
- Tier B source IDs are professional-practice candidate support.
- Tier C source IDs are discovery language and hypothesis context only.

Tier C cannot ground a trusted material claim, whether it is popular or not.
Mixed-source records retain all provenance; Tier C never adds authority to the
Tier A/B portions. Candidate procedure bodies remain in the native review
queue only and are excluded from the runtime candidate projection,
`TutorProcedureCatalog`, and `get_logic_procedure`.

Candidate numeric language is starting guidance, never a preset. The candidate
search tool returns at most one canonical card, proposes one reversible first
experiment, and uses exact Logic instructions only through the existing
reviewed procedure tool after a named documentary/installed-version review.

## Level Balancing + EQ Candidate Corpus v1

`research/knowledge/community-level-balancing-eq-v1/` is a second immutable,
content-addressed candidate package. Its 238 cards (92 level balancing and 146
equalization), 4,007 utterances, 23 contradictions, and 30 myths stay
provisional. Its 714 six-turn scenarios and 714 retrieval cases are
evaluation-only synthetic migration-integrity fixtures, not independent human
or semantic-retrieval evidence.

The unified external-resource store preserves package identity, version,
manifest digest, source type, evidence class, Logic-version scope, and context
metadata. Runtime retrieval is explicitly `lexical_structured_provisional`:
exact normalized language gets a deterministic boost, results collapse to one
canonical card, and filters constrain the selected candidate. It is not a claim
of completed semantic retrieval. The source registry namespaces only the two
documented package-2 source-ID collisions and retains `originalSourceID`.

## Compression, Arrangement + Frequency Allocation Candidate Corpus v1

`research/knowledge/community-compression-arrangement-frequency-allocation-v1/`
is the immutable third candidate package. Its 350 cards, 7,700 utterances,
1,050 scenarios, and 1,750 mixed evaluation cases remain unreviewed. The five
evaluation kinds are 350 each of retrieval, paraphrase, clarification,
tradeoff, and myth resistance. The 700 retrieval and paraphrase cases are
exact-match migration-integrity fixtures; the 1,050 clarification, tradeoff,
and myth-resistance cases are non-exact and make no semantic-quality claim. The runtime resource excludes evaluation data and
Logic procedure bodies. Its 91 sources add 1,050 awaiting-review candidates;
the fixed 12 collisions are namespaced and retain `originalSourceID`.

## Reverb + Delay Candidate Corpus v1

`research/knowledge/community-reverb-delay-v1/` is the immutable fourth
candidate package. Its 300 cards (160 reverb, 140 delay), 6,600 utterances,
900 synthetic scenarios (600 four-turn and 300 six-turn), and 1,500 synthetic
retrieval fixtures remain provisional/test-only. Runtime carries only bounded
candidate diagnostic and reversible-experiment evidence; it excludes scenarios,
retrieval cases, the supplied SQLite database, and all Logic procedure bodies.
The immutable raw package has 316 uniquely exact retrieval fixtures and 1,184
non-exact lexical fixtures. Runtime safety redaction deliberately removes the
navigation-bearing `eval.delay.logic_pro_specific.logic_region_delay.1` exact
utterance, so the test-only fixture records 315 runtime-safe exact and 1,185
runtime-safe non-exact cases; it is not restored into the app resource.

All 105 sources retain native `reviewState=acquired` and immutable
`originalReviewStatus=source_registered_not_full_claim_review` (42 Tier A, 43
Tier B, 20 Tier C).
The queue carries 300 claims, 300 strategies, and 300 procedures, all
`awaitingReview`; procedure rows separately preserve
`originalReviewStatus=candidate_not_yet_human_reviewed` and
`originalVerificationStatus=candidate_unverified_on_installed_logic`, plus
`execution_authority=false` and `user_performs_every_action=true` in the
immutable payload. The runtime descriptor deliberately does not expose those
procedure fields because no procedure data is shipped; the queue and pipeline
audit are the authoritative verification boundary. Only the three documented
source collisions are namespaced, with every nested source reference rewritten.

## Saturation + Harmonic Distortion + Transient Shaping Candidate Corpus v1

`research/community_knowledge/packages/tracksmith-corpus-006-saturation-transient-shaping/`
is an immutable stable-contract 1.0 input package. Its 384 candidate cards (204
saturation/harmonic-distortion and 180 transient-shaping), 8,448 utterances,
1,152 six-message scenarios, and 1,920 supplied exact retrieval evaluations are
candidate retrieval evidence only. The runtime-safe projection preserves the
honest 1,920 unique exact / 0 nonexact accounting because its navigation safety
scan redacts no P6 fields. Independent adversarial diagnostics remain a
separate semantic guard, not a claim of model listening or installed-Logic
verification.

Its 82 sources retain their original evidence and review classes: 46 official
documentation, 14 primary research, 11 professional-practice, 10 specialist,
and one community-pattern source. Primary research is carried in its own
provenance partition; it is never relabeled as official documentation. All
1,152 queue candidates await review. P6 procedure payloads remain outside the
production resource and preserve `candidate_unverified_on_installed_logic`,
`execution_authority=false`, and user-only execution. Runtime cards expose only
candidate distinctions, reversible level-matched experiments, listening cues,
tradeoffs, stop/undo language, non-processing hypotheses, and a procedure
candidate identifier/status—never steps, locations, visual targets, or a
mutation capability.

## Recording Latency, Monitoring, Signal Flow, Comping + Punch Candidate Corpus v1

`research/community_knowledge/packages/tracksmith-corpus-012-recording-latency-monitoring-comping-punch/`
is an immutable stable-contract 1.0 Package 012 staged through the
repository-owned no-follow CAS path. Its archive, package manifest,
integration manifest, inventory, and 47-file tree are independently pinned.
The package has 480 unreviewed canonical cards across four 120-card domains,
11,040 raw utterances, 1,440 six-message scenarios, 2,400 classified retrieval
evaluations, 52 contradictions, 64 myths, and 84 sources.

Its runtime is deliberately canonical-card-only: 480 cards and zero utterances,
contradictions, myths, procedures, scenarios, evaluations, exact aliases,
SQLite, or mutation capability. The test bundle holds only the 480
`exact_unique` fixture rows. The remaining 1,920 retrieval rows are
diagnostic-only; the accounting is raw 480 exact / 1,920 nonexact and runtime
0 exact / 2,400 nonexact. Exact fixture aliases are test-only linkage data and
are absent from production lookup.

The 84 source records retain their native evidence/review/access distinctions:
36 official-documentation documentary/public-HTML, 2 primary-research
reviewed-primary-research/search-discovery-only, 21 professional-practice
reviewed-professional/public-HTML, 5 specialist manual-seed-only, 19 specialist
search-discovery-only, and one community-pattern manual-seed-only. In
particular, primary research remains discovery-only provenance, not open
documentation or installed-Logic authority. Every claim, strategy, and
procedure remains awaiting human review; procedures preserve their original
candidate synthesis, unverified installed-Logic status, false execution
authority, and user-only action boundary. GeneralTutor receives exactly the 84
source records for traceability and no P12 advice, concept, strategy, claim, or
contradiction promotion.

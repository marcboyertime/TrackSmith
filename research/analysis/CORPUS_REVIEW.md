# Corpus review and disposition

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

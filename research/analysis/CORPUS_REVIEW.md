# Corpus review and disposition

This catalog records how every unique PDF family in the supplied corpus affects the product. Duplicate copies and alternate publication downloads are counted once. “Core” means full-text engineering review; “supporting” means method/results/limitations review; “peripheral” means systematic screening with no current MVP dependency.

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

## Corpus-level observations

- Duplicate publication copies were common; content hashes prevent double counting.
- Several sources are 2026 preprints. They inform experiments, not production promises.
- Many generative papers evaluate short clips and use proxy metrics. Long-form continuity and non-target preservation remain weakly established.
- The most mature evidence for the MVP is classic DSP, standards-compliant measurement, immutable state, and structured user control.
- The most promising research path after MVP is effect-sensitive offline parameter optimization over the same deterministic graph.


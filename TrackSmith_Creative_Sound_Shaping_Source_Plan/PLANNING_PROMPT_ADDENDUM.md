## Mandatory planning and source-review stage

Before implementing creative sound shaping, retrieve and deeply analyze the supplied `CORE_SOURCES.csv` and `OFFICIAL_DOCS_AND_REPOS.csv` through TrackSmith's existing immutable research-ingestion pipeline.

Do not treat the papers as a feature checklist. Produce an evidence-backed architecture decision for each transformation lane:

1. deterministic effects and modulation;
2. MIDI/MPE transformation and controller generation;
3. vocoding and source-filter resynthesis;
4. DDSP/harmonic-plus-noise resynthesis;
5. audio-to-MIDI plus modeled/sample/neural instrument synthesis;
6. latent timbre translation;
7. diffusion/flow instruction editing;
8. effect-chain inference-time optimization;
9. explicit generated-asset creation.

For every source and candidate lane, extract:

- exact task and assumptions;
- preserved and damaged musical attributes;
- mono/polyphonic behavior;
- short-clip and long-form limits;
- audio/MIDI/sample-rate requirements;
- real-time versus offline feasibility;
- latency, memory and hardware requirements;
- training data, weights, code and license availability;
- quality of listening tests and evaluation metrics;
- known artifacts and failure modes;
- controllability and editability;
- provenance and rollback implications;
- fit with TrackSmith's AUv3, companion and explicit-new-asset boundaries.

Create:

- `docs/CREATIVE_TRANSFORMATION_TECHNICAL_PLAN.md`
- `docs/TRANSFORMATION_LANE_MATRIX.md`
- `docs/CREATIVE_MODEL_AND_DATA_AUDIT.md`
- `docs/BUILD_VS_INTEGRATE_DECISIONS.md`
- `docs/CREATIVE_EVALUATION_PROTOCOL.md`

The planning stage must make separate build-versus-integrate decisions for these initial vertical slices:

1. tempo-aware wah on synth audio and MIDI;
2. vocal-to-brass as (a) brass-colored vocal, (b) voice/trumpet hybrid and (c) trumpet-performance reconstruction;
3. underwater but intelligible vocal;
4. huge metallic impact from a drum/instrument hit.

Do not select one mechanism for all tasks merely for architectural simplicity. A hybrid architecture is expected if supported by evidence.

Before productionizing resynthesis, timbre transfer or generative editing, build bounded offline spikes for the leading candidates. Render the same provenance-recorded fixtures and compare them using:

- level-matched blinded listening;
- melody/pitch-contour preservation;
- timing/onset preservation;
- dynamics/articulation preservation;
- intelligibility where relevant;
- source leakage and unwanted identity retention;
- transformation relevance;
- latency and compute cost;
- determinism or reproducibility;
- user control and revision behavior.

Select the production path from audible results and controllability, not abstract benchmark superiority. Explicitly record when a convincing result requires a rendered new asset rather than an editable effect graph.

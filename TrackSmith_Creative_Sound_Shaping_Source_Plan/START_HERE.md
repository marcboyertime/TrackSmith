# TrackSmith Creative Sound-Shaping Research Starter Pack

This pack is a curated retrieval and analysis plan for expanding TrackSmith beyond mixing into semantic sound design, MIDI expression, resynthesis, timbre transformation, and explicit generative editing.

The environment that produced this pack could not fetch the PDF binaries directly, so `CORE_SOURCES.csv` provides canonical open-access paper/PDF locations for the coding agent to retrieve through TrackSmith's existing immutable research-ingestion pipeline.

## First six sources to deep-read

1. **DDSP: Differentiable Digital Signal Processing** - establishes interpretable pitch/loudness-conditioned synthesis and timbre transfer.
2. **MIDI-DDSP** - connects notes, expressive performance, and synthesis controls; central for ordinary-language MIDI shaping.
3. **Audio Editing in the Era of Foundation Models: A Survey** - current taxonomy of editing methods, datasets, preservation, and evaluation.
4. **AUDIT** - instruction-guided audio editing with explicit preservation concerns.
5. **Style Transfer of Audio Effects with Differentiable Signal Processing** - maps style to visible effect controls rather than opaque waveform replacement.
6. **ST-ITO** - searches arbitrary effect chains offline and provides a benchmark for production-style matching.

## Core architectural lesson

Do not force every creative request through one technology. TrackSmith should explicitly distinguish:

1. deterministic effects and modulation;
2. MIDI/MPE transformations and controller generation;
3. interpretable vocoding or DDSP resynthesis;
4. audio-to-MIDI plus instrument synthesis;
5. latent/diffusion timbre transfer;
6. instruction-guided generative editing;
7. explicit new-asset generation.

A request such as “make the synth go wah-wah-wah” belongs primarily to lane 1 or 2. “Make my voice sound more like a trumpet” needs multiple interpretations and may use lanes 3, 4, or 5. “Turn this hit into a metallic impact” may combine deterministic layers with a new-asset lane.

## Required output of the planning review

Before production implementation, the agent should produce:

- `docs/CREATIVE_TRANSFORMATION_TECHNICAL_PLAN.md`
- `docs/TRANSFORMATION_LANE_MATRIX.md`
- `docs/CREATIVE_MODEL_AND_DATA_AUDIT.md`
- `docs/CREATIVE_EVALUATION_PROTOCOL.md`
- `docs/BUILD_VS_INTEGRATE_DECISIONS.md`

It should then build small offline comparison spikes for the leading approaches and select production mechanisms based on audible quality, preservation, editability, latency, provenance, licensing, and deployment risk—not paper metrics alone.

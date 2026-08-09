# TrackSmith Vocal v1 — speech-cleanup research boundary

Status: `STUDY_ONLY`

Audit source: `research/analysis/open_source_audio_audit/`

External reference: RNNoise at pinned commit `70f1d256acd4b34a572f999a05c87bf00b67730d`

This document defines a TrackSmith-owned experiment boundary. It does **not** approve RNNoise for
shipping, import RNNoise code, import a model/checkpoint, authorize dataset use, or claim that a
speech denoiser is suitable for sung vocals. No third-party code, model, weights, training data,
sample audio, or generated output is present in this milestone.

## Purpose and non-goals

The narrow question is whether a speech-only, noise-gated cleanup proposal can improve a noisy
test vocal without weakening performance identity, transients, consonants, breath detail, pitch,
timing, or ambience. The experiment is a research comparison on TrackSmith-owned or explicitly
licensed fixtures. It is not a general music denoiser, an AU render-thread stage, an automatic
commit action, a provider-selected DSP path, or evidence of production readiness.

RNNoise is classified `STUDY_ONLY` because the audited BSD-style code notice does not resolve the
downloaded model and training-data lineage. The inspected source assumes 48 kHz, 480-sample speech
frames and has no TrackSmith Apple-Silicon, allocation, deadline, or cross-vector replay evidence.
Any future reconsideration requires a new written code/model/data/patent/license decision.

## Mandatory execution boundary

- Run only in an offline CLI or a companion-owned off-render worker.
- Never initialize a model, resample, allocate, lock, perform file I/O, or infer in the AU render
  callback.
- Disable runtime network access. Provision any separately cleared research artifact explicitly,
  record its SHA-256, and keep it outside product resources.
- Use bounded 48 kHz framing in the experiment. Record the resampler identity/version, channel
  policy, padding, latency, state reset, compiler flags, CPU architecture, and exact artifact hash.
- Give each channel independent state. Never share mutable inference state across threads.
- Treat output as a proposal asset. It may be previewed or rejected but cannot overwrite source
  audio or directly choose arbitrary TrackSmith code, nodes, or parameters.
- Bind every result to request ID, capture ID, source ID, source revision, source SHA-256, algorithm
  identity, model SHA-256 when applicable, and destination asset SHA-256.
- Reject stale, mismatched, non-finite, oversized, or unprovenanced output before preview.

## Noise-floor gate for the variability defect

The historical `p90 - p10` calculation over only `isFinite` RMS frames is invalid for phrase-level
vocal dynamics: near-silent frames around -300 dBFS survive, put P10 in inter-phrase silence, and
turn the result into loudest-versus-silence. The experiment must retain the raw timeline but compute
performance variability only over frames that pass a documented speech-activity/noise-floor gate.

For a frozen fixture, record all of the following:

1. `finiteFrameCount`: finite RMS frames before gating.
2. `calibratedNoiseFloorDBFS`: derived from an explicit pre-roll/noise-only region when available.
3. `gateMarginDB`: a fixed, fixture-manifested margin; the first study value is 9 dB.
4. `absoluteGateFloorDBFS`: a bounded backstop; the first study value is -72 dBFS.
5. `gateThresholdDBFS = max(calibratedNoiseFloorDBFS + gateMarginDB, absoluteGateFloorDBFS)`.
6. `retainedFrameCount` and `retainedFraction = retainedFrameCount / finiteFrameCount`.
7. `gatedVariabilityDB = gatedP90 - gatedP10`, only when enough voiced frames remain.

The fixed study policy is:

- Reject any non-finite threshold, percentile, fraction, or result.
- Require at least 30 retained frames and at least 200 ms of total retained time.
- If `retainedFraction < 0.20`, report `INSUFFICIENT_VOICED_EVIDENCE`; do not emit a confident
  dynamics number.
- Otherwise multiply the pre-gate analysis confidence by
  `min(1, retainedFraction / 0.50)`. Thus confidence falls continuously when gating discards most
  frames and is not restored by a numerically large percentile spread.
- Surface raw and gated counts, threshold, retained fraction, confidence before/after adjustment,
  and the insufficiency reason. Never silently substitute the old ungated number.

These values are an initial deterministic research protocol, not product-tuned constants. Any
change is an algorithm-version change and requires fixture regeneration and replay comparison.

## Experiment sequence

1. Freeze a TrackSmith-owned noisy spoken-vocal fixture set and a separate sung-vocal safety set.
   Record consent/rights, capture identity, source SHA-256, sample rate, channels, frames, and the
   original untouched location.
2. Create immutable source copies in an isolated research workspace. Confirm the before/after
   source hashes are identical after every run.
3. Run the TrackSmith gate and confidence policy on the raw RMS timeline. Include long phrase gaps,
   near-silent digital tails, breath-only passages, and low-level consonants.
4. If a separately licensed research implementation/model is ever authorized, run it only through
   the off-render boundary. Otherwise use a TrackSmith deterministic mock to exercise contracts.
5. Produce immutable derivative assets. Record input, output, executable/build, algorithm, model,
   parameter, resampler, and environment hashes.
6. Level-match source and candidates within the evaluation protocol’s declared tolerance.
7. Use the TrackSmith-owned Vocal evaluation runner. Keep identities blind until judgment and label
   the result exactly `SINGLE_LISTENER_FORMATIVE_EVIDENCE`.
8. Score target relevance, source preservation, naturalness, intelligibility, temporal coherence,
   usefulness, preference (including none/no-preference), confidence, conditions, and fatigue.
9. Do not promote a candidate based on metrics alone. A failed source-preservation, rights,
   allocation, stale-result, rollback, or listening gate stops the experiment.

## Required deterministic fixtures

Every fixture is TrackSmith-owned or separately documented and has source/render SHA-256 values.

- Speech with multi-second digital silence between phrases, including approximately -300 dBFS RMS
  timeline values. The gate must exclude silence from P10.
- Quiet speech just above a calibrated floor. The gate must preserve low-level voiced frames.
- All-silence and noise-only inputs. Both must yield insufficient voiced evidence rather than a
  fabricated dynamics result.
- Sustained background noise with sparse speech. Confidence must decrease with retained fraction.
- Breath, fricatives, plosives, sibilants, vibrato, pitch slides, and word onsets.
- Sung vocal, harmony, and vocal-with-bleed safety cases. Speech cleanup must not be generalized
  from spoken results.
- Odd lengths, partial final frames, mono/stereo policies, sample-rate conversion, zero frames,
  oversized input, NaN, positive infinity, and negative infinity.
- Stale source revision, wrong capture hash, wrong model/build hash, interrupted render, cancellation,
  save/reload, exact rollback, and repeated replay.

## Evidence gates before any classification change

- **Licensing:** complete code, dependency, model, checkpoint, training-data, fixture-content, notice,
  and patent/usage manifest approved in writing. Dataset URLs are not licenses.
- **Source preservation:** original audio and MIDI hashes remain exact; all outputs are isolated
  derivatives with ancestry and reversible deletion.
- **Determinism:** identical fixed input/build/model/state/config produces bitwise-identical output,
  or a predeclared tolerance-backed result across each supported CPU/compiler vector path.
- **Parity:** offline whole-buffer and companion off-render chunked execution agree under the frozen
  framing/state-reset contract. This is not permission to execute inference in the render callback.
- **Allocation and concurrency:** allocation instrumentation, AddressSanitizer, UndefinedBehaviorSanitizer,
  ThreadSanitizer, cancellation, per-channel ownership, and long-run memory checks pass.
- **Latency and headroom:** measured Apple-Silicon CPU, memory, resampling cost, framing delay, and
  worst-case deadline data exist for the exact reviewed artifact.
- **Safety:** non-finite, malformed, oversized, stale, mismatched, replayed, and tampered results are
  rejected; no provider output selects executable code or arbitrary DSP.
- **Lifecycle:** save/reload, source-preservation, offline/chunked parity, rollback, cancellation,
  crash recovery, and stale-result tests pass without orphaned or overwritten assets.
- **Listening:** blinded, level-matched owner evidence is recorded with no-preference available.
  Results remain formative and cannot establish expert, population, or production-ready claims.

Until every gate is satisfied, RNNoise and every model-bearing derivative remain `STUDY_ONLY` and
outside TrackSmith’s shipping dependency graph.

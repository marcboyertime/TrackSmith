# Test plan

## Automated command

```sh
swift run -c release TestRunner
```

On 2026-07-12 this passed 20/20 checks: plan round-trip, bounds rejection, bypass
identity, limiter/nonfinite safety, five rates by six buffer sizes, WAV round-trip,
known sine/noise spectrum analysis, BS.1770 997 Hz calibration, relative gating, inter-sample true
peak detection, PCM24 round-trip, capture wrap chronology, three variants/
revision, adversarial prompt rejection, level matching, transactional audible export
with source-byte preservation, long-preview BS.1770 matching, snapshot undo/redo,
and IPC round-trip. The export check now also validates safe session reload and
rejects a manifest path-traversal attempt.

This Command Line Tools installation includes neither XCTest nor Swift Testing, so
the repository uses a dependency-free executable harness. After full Xcode is
installed, migrate checks into XCTest without removing the release harness, which
remains valuable for CI and installed-toolchain diagnostics.

## Required expansion

- DSP: analytic biquad response, impulse/sweep/noise, compressor transfer and time
  constants, smoothing/automation, repeated bypass/reset, denormal timing, latency,
  mono/stereo independence, randomized invalid/nonfinite plans.
- Analysis: remaining sample-rate loudness vectors, known hum/noise floor/envelopes/onsets,
  stereo frequency-dependent phase, tolerances for every declared metric.
- Golden audio: generated fixtures only, tolerant numeric comparisons, metric diff,
  documented intentional baseline updates.
- Agent: ambiguous references, locked limiter, impossible constraints, stale source,
  version-node merge, prompt injection from every metadata field.
- State: corrupt/truncated migrations, branch history, partial preview cleanup,
  provider and IPC interruption at every transaction state.
- Performance: release callback percentiles and deadline misses at all formats,
  module/graph CPU, memory stability, analysis/preview latency, app/UI responsiveness.

## Perceptual release tests

Follow ITU-R BS.1534-3 discipline where an impairment reference exists: listener
training, hidden reference, meaningful anchors, randomized conditions, identical
loops, documented reproduction, and power-aware statistics. Creative production
tests additionally rate target success, preservation, naturalness, clarity,
production value, and excitement separately. Use level-matched blinded conditions,
hidden duplicates, raw-distribution plots, medians/IQRs, effect sizes, confidence
intervals, and corrected pairwise comparisons. Full rationale is in the research
synthesis.

## Host matrix

No Logic-host row has passed yet. Track macOS, Logic, hardware, app version, signing
identity, format, buffer, channel, insertion scope, low-latency/offline mode, number
of instances, result, logs, and saved-project fixture hash. Cover empty/large
projects, audio/instrument/bus/output/stack/frozen tracks, network/app absent,
permission denied, format changes, save/reload, freeze and bounce.

Exact procedures are in `MANUAL_LOGIC_TESTS.md`. A generated Xcode project is not a
host test, and `auval` success is not equivalent to Logic workflow success.

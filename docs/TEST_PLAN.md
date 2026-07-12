# Test plan

## Automated command

```sh
swift run -c release TestRunner
```

On 2026-07-12 this passed 13/13 checks: plan round-trip, bounds rejection, bypass
identity, limiter/nonfinite safety, five rates by six buffer sizes, WAV round-trip,
known sine analysis, capture wrap chronology, three variants/revision, adversarial
prompt rejection, level matching, snapshot undo/redo, and IPC round-trip.

This Command Line Tools installation includes neither XCTest nor Swift Testing, so
the repository uses a dependency-free executable harness. After full Xcode is
installed, migrate checks into XCTest without removing the release harness, which
remains valuable for CI and installed-toolchain diagnostics.

## Required expansion

- DSP: analytic biquad response, impulse/sweep/noise, compressor transfer and time
  constants, smoothing/automation, repeated bypass/reset, denormal timing, latency,
  mono/stereo independence, randomized invalid/nonfinite plans.
- Analysis: calibrated loudness/true peak, known hum/noise floor/envelopes/onsets,
  stereo frequency-dependent phase, tolerances for every declared metric.
- Golden audio: generated fixtures only, tolerant numeric comparisons, metric diff,
  documented intentional baseline updates.
- Agent: ambiguous references, locked limiter, impossible constraints, stale source,
  version-node merge, prompt injection from every metadata field.
- State: corrupt/truncated migrations, branch history, partial preview cleanup,
  provider and IPC interruption at every transaction state.
- Performance: release callback percentiles and deadline misses at all formats,
  module/graph CPU, memory stability, analysis/preview latency, app/UI responsiveness.

## Host matrix

No Logic-host row has passed yet. Track macOS, Logic, hardware, app version, signing
identity, format, buffer, channel, insertion scope, low-latency/offline mode, number
of instances, result, logs, and saved-project fixture hash. Cover empty/large
projects, audio/instrument/bus/output/stack/frozen tracks, network/app absent,
permission denied, format changes, save/reload, freeze and bounce.

Exact procedures are in `MANUAL_LOGIC_TESTS.md`. A generated Xcode project is not a
host test, and `auval` success is not equivalent to Logic workflow success.

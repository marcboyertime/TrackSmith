# Known limitations

## Host and packaging

- Full Xcode is absent. The AUv3/SwiftUI targets are generated but uncompiled,
  unsigned, unnotarized, not `auval`-validated, and untested in installed Logic.
- Example bundle IDs, App Group ID, manufacturer and signing configuration must be
  replaced before distribution.
- Logic project selection, source files, channel strips, plug-in insertion/reorder,
  arbitrary automation, tracks/regions and bounce are not stable capabilities.
- ARA 2 has not been licensed or integrated. Accessibility, Core MIDI and control-
  surface adapters are not implemented.

## Audio engine

- The AU scaffold applies only output gain. Shared DSP and capture are not wired to
  host buffer pointers and graph publication yet.
- `CompiledGraph` is verified offline; its Swift-array `AudioBuffer` must not be
  passed through a real-time callback as-is.
- Limiting is zero-lookahead sample peak, not true peak. `lookaheadMS` is constrained
  to zero until a fixed-latency lookahead implementation exists.
- Dynamic EQ, expander/gate, de-esser, transient shaper, M/S EQ, delay and reverb are
  schema entries but intentionally throw unsupported-node errors in DSP compilation.
- Parameter automation is block-level in the AU scaffold; sample-accurate AU render
  events and smoothing for all parameters are unfinished.
- Capture concurrency is single-producer. Snapshot consistency under continuous
  wrap needs an overwrite/version retry protocol before production.

## Analysis and intelligence

- No true peak, LUFS/LRA, calibrated noise/hum, transient, source-aware vocal/drum,
  room, masking, time-varying tonal, learned quality or reference analysis exists.
- Spectrum is a naive first-window DFT and is suitable only for deterministic early
  tests, not production diagnosis.
- Recipe parsing is keyword-based, source support is shallow, and only a few revision
  forms are implemented. No cloud/local LLM adapter is connected.
- Preview “loudness matching” currently matches whole-interval RMS, not gated LUFS.
- The CLI writes audible preview WAVs but has no synchronized player, waveform UI,
  instant switching, or blind comparison mode.

## State and operations

- Snapshot storage is in memory; SQLite/App Group persistence, migrations, cache
  garbage collection, named snapshots and restart recovery are pending.
- File IPC is a proof, not the final authenticated/wake-up protocol.
- The license is all-rights-reserved pending an owner decision.

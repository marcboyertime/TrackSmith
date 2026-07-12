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

- BS.1770 integrated loudness and a four-phase true-peak estimate are implemented;
  formal external conformance vectors across every sample rate are still required.
  LRA, calibrated noise/hum, source-aware vocal/drum, room, masking, frequency-band
  spatial, learned-quality, and reference analysis do not yet exist.
- Spectrum is averaged over time with a deterministic FFT, but mono fold-down can
  hide anti-phase content and descriptive bands do not prove boxiness, harshness,
  or sibilance.
- Recipe parsing is keyword-based, source support is shallow, and only a few revision
  forms are implemented. No cloud/local LLM adapter is connected.
- Preview matching uses gated BS.1770 loudness when at least one complete block is
  available and explicitly falls back to RMS for shorter captures. It is not a
  substitute for synchronized blinded listening.
- The CLI writes audible preview WAVs but has no synchronized player, waveform UI,
  while the package-built native audition app now provides synchronized playback,
  waveform, measurements, and instant switching. It is not yet packaged, signed,
  notarized, or integrated into the full companion session browser. It loads all
  variants into memory and currently supports rewind but not waveform seeking.

## State and operations

- Snapshot storage is in memory; SQLite/App Group persistence, migrations, cache
  garbage collection, named snapshots and restart recovery are pending.
- File IPC is a proof, not the final authenticated/wake-up protocol.
- The license is all-rights-reserved pending an owner decision.

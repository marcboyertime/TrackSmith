# Known limitations

## Host and packaging

- Xcode 26.6 builds an Apple-development-signed, sandboxed AUv3/SwiftUI app.
  `auval` discovers it out of process and passes its complete validation run, but
  it is not notarized or tested inside Logic yet. The remaining validator warnings
  are a deprecated preset-property recommendation and a non-failing transient
  1-input/2-output bridge probe; the render allocator accepts only equal mono or
  stereo layouts.
- Development bundle IDs now use `com.marcboyer.logicaudioassistant`; App Group,
  manufacturer-code ownership, release signing, and notarization remain distribution work.
- Logic project selection, source files, channel strips, plug-in insertion/reorder,
  arbitrary automation, tracks/regions and bounce are not stable capabilities.
- ARA 2 has not been licensed or integrated. Accessibility, Core MIDI and control-
  surface adapters are not implemented.

## Audio engine

- The AU callback uses borrowed noninterleaved Float32 host pointers and the same
  deterministic graph as offline rendering; parity is tested across irregular host
  blocks. The Swift-array `AudioBuffer` remains offline-only.
- A graph can be staged only while render resources are deallocated. Lock-free,
  verified whole-graph publication during playback is not implemented.
- Limiting is zero-lookahead sample peak, not true peak. `lookaheadMS` is constrained
  to zero until a fixed-latency lookahead implementation exists.
- Dynamic EQ, expander/gate, de-esser, transient shaper, M/S EQ, delay and reverb are
  schema entries but intentionally throw unsupported-node errors in DSP compilation.
- Parameter automation is block-level in the AU scaffold; sample-accurate AU render
  events and smoothing for all parameters are unfinished.
- Capture is single-producer with atomic Float32 payloads, release/acquire frame
  publication, reserved overwrite guard frames, and bounded snapshot retry. Sustained
  host-load performance and callback timing still require Logic measurement.

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
- The AU compact UI reports input activity and output gain, but capture controls,
  waveform, analysis, prompt entry, preview selection, and plan commits are not yet
  connected to the companion.
- The license is all-rights-reserved pending an owner decision.

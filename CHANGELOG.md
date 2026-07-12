# Changelog

## 0.1.0 - 2026-07-12

- Created the native Swift package and generated Xcode project.
- Added a versioned plan schema and fail-closed validator.
- Added deterministic gain, polarity, high/low-pass, parametric EQ, compression,
  saturation, stereo width, and limiting kernels.
- Added a lock-free bounded capture ring and initial signal analysis.
- Added immutable snapshots, transactions, deterministic planning, revisions,
  three-way preview rendering, and level matching.
- Added WAV analysis/offline-render tools, IPC probes, and a release test runner.
- Added a transactional prompt-to-three-WAV preview workflow, PCM24/PCM32 input,
  per-variant plan/manifest export, and deterministic demo-audio generation.
- Fixed macOS hidden flags propagating from the preview staging directory.
- Added ITU-R BS.1770-5 gated programme loudness and Annex 2 true-peak analysis,
  with calibration, gating, inter-sample peak, and preview-matching tests.
- Replaced first-window spectral analysis with time-averaged FFT descriptors for
  rolloff, flatness, slope, bands, positive flux, and transient density.
- Made compressor recipes source-level- and crest-aware, widened preview strengths,
  and exported objective preview-difference warnings and matching provenance.
- Added a hash-deduplicated research workflow, complete corpus disposition, and
  research-to-engineering synthesis for 61 unique supplied papers.
- Added a directly buildable native audition app with synchronized AVAudioEngine
  A/B switching, waveform, keyboard control, measurements, and processing cards.
- Added a fail-closed preview-session loader that verifies artifact containment,
  saved plans, snapshot IDs, variant uniqueness, and WAV format consistency.
- Added AUv3 and SwiftUI scaffolds; host validation remains blocked by missing Xcode.

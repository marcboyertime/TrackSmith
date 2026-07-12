# Logic Audio Assistant

A native, reversible conversational audio-production assistant designed around a
reliable Audio Unit effect for Logic Pro. Natural-language intent compiles into a
typed, validated processing graph; deterministic code renders and measures three
level-matched options; the user remains in control of commit, revision, bypass,
and restoration.

## Current status

Milestones 0 and 1 are partially implemented. The portable core builds and runs:

- Typed processing-plan schema with bounded parameters, locked-node protection,
  stale-snapshot rejection, gain limits, and deterministic Codable state.
- In-place mono/stereo DSP for trim, polarity, high/low-pass and peaking EQ,
  linked compression, saturation, width, limiting, bypass, and finite-value safety.
- Bounded single-producer capture ring with C11 atomic publication and no render-
  side allocation.
- Initial peak, RMS, DC, clipping, crest, spectral-band, centroid, and stereo-
  correlation analysis with units, confidence, version, window, and limitations.
- Conservative, balanced, and strong recipes; loudness-matched preview rendering;
  immutable snapshot history; selective compression revision; mock model provider.
- PCM16/24/32 and Float32 WAV input, Float32 WAV output, analysis, three-preview,
  test-signal, and offline-render CLIs.
- Atomic file-message IPC prototype and companion/plugin process probes.
- Generated SwiftUI companion and AUv3 effect project scaffolds.

On the development Mac, `swift run -c release TestRunner` passes 15/15 checks and
the two release processes exchange a heartbeat. The installed environment is
Apple Silicon, macOS 26.3, Logic Pro 11.2.2, Swift 6.2.1, but only Command Line
Tools are installed. Consequently, the AUv3 bundle and SwiftUI app have **not**
been compiled, signed, validated by `auval`, or tested inside Logic. The AU scaffold
currently demonstrates pass-through plus output gain; the complete DSP graph and
capture ring are not yet wired into its render block. See
[`KNOWN_LIMITATIONS.md`](docs/KNOWN_LIMITATIONS.md).

## Build and test

Requirements for the portable core: macOS 14+, Apple Swift 6.1+, and XcodeGen.
Full Xcode is required for the app extension.

```sh
make verify
make demo
make preview-demo
```

Direct commands:

```sh
swift build -c release
swift run -c release TestRunner
swift run AnalysisCLI input.wav
swift run PreviewCLI input.wav --source vocal --prompt "make this clearer and more controlled"
swift run OfflineRenderer input.wav processing-plan.json output.wav
xcodegen generate
```

After full Xcode is installed and selected, follow
[`MANUAL_LOGIC_TESTS.md`](docs/MANUAL_LOGIC_TESTS.md). Do not treat project
generation alone as plug-in validation.

## Try audible previews now

On this development checkout, a verified demo session is available at
`fixtures/generated/demo-vocal-previews`. If generated files are absent in a fresh
clone, run `make preview-demo`. Open the resulting directory and audition
`00-original.wav`, then the three numbered variants.

To process your own Logic-exported WAV:

```sh
swift run -c release PreviewCLI "/path/to/My Vocal.wav" \
  --source vocal \
  --prompt "make this clearer, warmer, and more controlled" \
  --output "/Users/marcboyer/Desktop/My Vocal Preview 1"
```

The output directory must be new. It contains four audible WAVs, one plan per
variant, `manifest.json` with measurements and parameters, and `AUDITION.txt`.
The input is never modified. See [`HANDS_ON_TESTING.md`](docs/HANDS_ON_TESTING.md)
for drum/full-mix examples, supported prompt vocabulary, and verification steps.

## Repository map

- `packages/`: host-independent schema, DSP, analysis, state, planner, preview,
  IPC, and Logic adapter boundaries.
- `plugins/AudioUnit/`: AUv3 extension scaffold.
- `apps/CompanionMacApp/`: native SwiftUI application scaffold.
- `apps/CompanionApp/`: buildable command-line product slice.
- `tools/`: preview/audio generation, offline renderer, analysis CLI, and integration probes.
- `tests/TestRunner/`: dependency-free executable verification harness used because
  this Command Line Tools installation supplies neither XCTest nor Swift Testing.
- `docs/`: product, architecture, capability, safety, test, and integration records.

## Product workflow target

Insert the effect, explicitly capture recent/next playback, enter a request,
audition three level-matched results, inspect every node, commit one graph, revise
only selected nodes, and revert perfectly. Project-wide Logic editing remains an
optional adapter and never a dependency of the audio product.

## Privacy default

Core measurement, recipes, graph execution, preview rendering, and manual editing
are local. No audio upload path or telemetry is implemented. Future providers must
obtain explicit consent and all responses remain untrusted plan proposals.

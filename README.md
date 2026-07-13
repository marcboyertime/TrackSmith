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
  side allocation; capture payloads are atomic and the ring reserves an overwrite
  guard so analysis can safely copy while playback continues.
- BS.1770 gated loudness and true peak; peak/RMS/DC/clipping/crest; time-averaged
  spectral centroid, rolloff, slope, flatness, bands and flux; stereo correlation,
  all with units, confidence, version, window, and limitations.
- Signal-relative conservative, balanced, and strong recipes; labeled BS.1770/RMS
  preview matching and objective preview-difference measurements;
  immutable snapshot history; selective compression revision; mock model provider.
- PCM16/24/32 and Float32 WAV input, Float32 WAV output, analysis, three-preview,
  test-signal, and offline-render CLIs.
- Native SwiftUI/AVFoundation audition app with synchronized sample-position A/B,
  waveform/playhead, keyboard switching, measurements, warnings, and plan cards.
- Atomic file-message IPC prototype and companion/plugin process probes.
- Compiled native SwiftUI companion plus AUv3 effect with borrowed host-buffer DSP,
  dry-input capture, live input status, automatable output gain, serialized plan
  state, and safe mono/stereo format validation.

On the development Mac, `TestRunner` passes 22/22 checks. `AudioUnitHostProbe`
instantiates the real `AUAudioUnit` class, renders its serialized graph through
borrowed mono and stereo buffers at 44.1 and 96 kHz, verifies capture, and verifies
`fullState` restoration. Xcode 26.6 builds the companion and extension; LaunchServices
recognizes the extension metadata. The installed
environment is Apple Silicon, macOS 26.3, Logic Pro 11.2.2, and Swift 6.2.1.

The first installed build was ad-hoc signed (`TeamIdentifier=not set`), Gatekeeper
rejected it, and the system therefore did not register it with `auval`. The installer
now fails closed unless Xcode has an Apple Development certificate and verifies that
the app and extension have the same Team ID. No Logic-host success is claimed until
that development-signed build passes the tests below. See
[`KNOWN_LIMITATIONS.md`](docs/KNOWN_LIMITATIONS.md).

## Build and test

Requirements for the portable core: macOS 14+, Apple Swift 6.1+, and XcodeGen.
Full Xcode is required for the app extension.

```sh
make verify
make native-verify
make native-install
make demo
make preview-demo
```

Direct commands:

```sh
swift build -c release
swift run -c release TestRunner
swift run AnalysisCLI input.wav
swift run PreviewCLI input.wav --source vocal --prompt "make this clearer and more controlled"
swift run -c release AuditionApp "/path/to/preview folder"
swift run -c release AudioUnitHostProbe
swift run OfflineRenderer input.wav processing-plan.json output.wav
xcodegen generate
```

Before the first Logic insertion test, add an Apple Account in Xcode Settings →
Accounts and create an Apple Development certificate under Manage Certificates.
Then run `make native-install`, close Logic if it is open, launch
`~/Applications/Logic Audio Assistant.app` once, and reopen Logic.
Then follow [`MANUAL_LOGIC_TESTS.md`](docs/MANUAL_LOGIC_TESTS.md). A successful
Xcode build or in-process probe is not the same as Logic-host validation.

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

For sample-position-synchronized comparison, open that folder in the native app:

```sh
make audition SESSION="/Users/marcboyer/Desktop/My Vocal Research Preview 3"
```

Press Space to play/pause, `0`–`3` to select a version, and `A` to toggle the
selected result against the original. The loader validates file containment,
audio formats, snapshot identity, and saved plans before playback.

## Repository map

- `packages/`: host-independent schema, DSP, analysis, state, planner, preview,
  IPC, and Logic adapter boundaries.
- `plugins/AudioUnit/`: compiled AUv3 extension and reusable host-probe core.
- `apps/CompanionMacApp/`: native SwiftUI application scaffold.
- `apps/CompanionApp/`: buildable command-line product slice.
- `tools/`: preview/audio generation, offline renderer, analysis CLI, and integration probes.
- `tools/AuditionApp/`: directly buildable native preview player for blinded-style A/B work.
- `tests/TestRunner/`: dependency-free executable verification harness used because
  it runs consistently under both CI/Command Line Tools and full Xcode.
- `docs/`: product, architecture, capability, safety, test, and integration records.
- `research/analysis/`: deduplicated-corpus method, complete disposition catalog,
  and the research-to-engineering synthesis.

## Product workflow target

Insert the effect, explicitly capture recent/next playback, enter a request,
audition three level-matched results, inspect every node, commit one graph, revise
only selected nodes, and revert perfectly. Project-wide Logic editing remains an
optional adapter and never a dependency of the audio product.

## Privacy default

Core measurement, recipes, graph execution, preview rendering, and manual editing
are local. No audio upload path or telemetry is implemented. Future providers must
obtain explicit consent and all responses remain untrusted plan proposals.

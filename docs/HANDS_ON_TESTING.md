# Hands-on testing

You can test the audible core now; this does not require Xcode or the Logic plug-in.

## Audition the already-generated demo

```sh
open "/Users/marcboyer/LogicAudioAssistant/fixtures/generated/demo-vocal-previews"
```

Listen in this order at one unchanged monitoring volume:

1. `00-original.wav`
2. `01-conservative.wav`
3. `02-balanced.wav`
4. `03-strong.wav`

All four files are mono, 48 kHz, eight seconds, and matched using gated BS.1770
loudness. Their different SHA-256 hashes confirm they are distinct renders. The generated
source is deliberately artificial and boxy; it tests mechanics, not production
quality on a real performance.

For a much better comparison than Finder playback, launch the native audition app:

```sh
cd "/Users/marcboyer/LogicAudioAssistant"
make audition SESSION="/Users/marcboyer/Desktop/My Vocal Research Preview 3"
```

The app validates every artifact, loads all versions into one audio engine, and
keeps them at the same sample position. Controls:

- Space: play or pause.
- `0`, `1`, `2`, `3`: original, conservative, balanced, strong.
- `A`: toggle the selected processed result against the original.
- Command-period: stop and rewind.
- Command-O: open another preview folder.

Selecting a result reveals its loudness match, true peak, audio delta, every DSP
node, parameter, confidence, and rationale.

`AUDITION.txt` gives a short summary. `manifest.json` contains analysis, every node,
parameter, rationale, confidence and rejection status. The `*-plan.json` files can
be passed directly to `OfflineRenderer`.

## Regenerate the demo

```sh
cd "/Users/marcboyer/LogicAudioAssistant"
make demo-audio
swift run -c release PreviewCLI fixtures/generated/demo-vocal.wav \
  --source vocal \
  --prompt "make this clearer and more controlled"
```

The last command prints a newly timestamped output directory. Open that directory:

```sh
open "/path/printed/by/the/command"
```

## Test one of your own Logic exports

Export or bounce a short representative section as mono/stereo WAV. PCM16, PCM24,
PCM32 and Float32 are accepted; the original sample rate, channel count and frame
count are retained. Then run, using a new output directory name each time:

```sh
cd "/Users/marcboyer/LogicAudioAssistant"
swift run -c release PreviewCLI "/path/to/My Vocal.wav" \
  --source vocal \
  --prompt "make this clearer, warmer, and more controlled" \
  --output "/Users/marcboyer/Desktop/My Vocal Preview 1"
```

Drum bus example:

```sh
swift run -c release PreviewCLI "/path/to/Drums.wav" \
  --source drumBus \
  --prompt "make the drums punchier without making the cymbals harsher" \
  --output "/Users/marcboyer/Desktop/Drum Preview 1"
```

Full mix example:

```sh
swift run -c release PreviewCLI "/path/to/Mix.wav" \
  --source fullMix \
  --prompt "make this clearer and warmer without increasing harshness" \
  --output "/Users/marcboyer/Desktop/Mix Preview 1"
```

Supported source values are `vocal`, `vocalBus`, `drums`, `drumBus`, `bass`,
`guitar`, `keyboard`, `synth`, `fullMix`, `reference`, and `unknown`.

The planner is currently deterministic and keyword-based. Useful request concepts
are clear/clarity, professional, warm, controlled/compressed, punch/hit harder,
harsh/cymbal, sibilance, boxy/muddy, and wide. Unsupported words do not create new
DSP capabilities; inspect the emitted plan instead of assuming they were honored.

## Inspect and verify

Analyze any output:

```sh
swift run -c release AnalysisCLI "/path/to/preview.wav"
```

Render a saved plan again:

```sh
swift run -c release OfflineRenderer \
  "/path/to/original.wav" \
  "/path/to/02-balanced-plan.json" \
  "/path/to/re-rendered.wav"
```

Run the complete automated verification:

```sh
make verify
```

The current expected result is `SUMMARY passed=22 failed=0`, followed by:

```text
PASS Audio Unit instantiated and rendered mono/stereo host buffers
```

## Test the native Audio Unit in Logic

Save your Logic project, then quit Logic before installing so its Audio Unit
registry can observe the new extension cleanly.

In Xcode, open Settings → Accounts, add your Apple Account, select its team, open
Manage Certificates, and create an Apple Development certificate. This is required:
an ad-hoc “Sign to Run Locally” build has no Team ID and is not registered as this
AUv3 on the current machine.

```sh
cd "/Users/marcboyer/LogicAudioAssistant"
make native-verify
make native-install
open "$HOME/Applications/Logic Audio Assistant.app"
auval -v aufx LgAA ExAI
```

`make native-install` detects either a keychain-listed or Xcode account-managed
certificate and its Team ID, development-signs both nested bundles, and refuses
installation if their Team IDs do not match. The first signing attempt may present
a macOS private-key authorization dialog; approve it locally and never share the
password. If
`auval` still cannot find that build, send its complete output before clearing any
caches or terminating shared audio services.

In Logic:

1. Create a disposable project and add a mono or stereo audio track.
2. Choose an Audio FX insert, then Audio Units → Marc Boyer → Logic Audio Assistant.
3. Play audio. The compact UI should change from “Waiting for audio” to a green
   “Audio arriving” line with a peak value.
4. Move Output gain to `-12.0 dB`; the track should become quieter without clicks.
5. Return it to `0.0 dB`, bypass repeatedly, save, quit, reopen, and confirm the
   plug-in and parameter state reload.

This first UI build continuously retains only the latest 30 seconds in memory. It
does not yet expose the captured waveform or run conversational planning inside
Logic; those remain companion-integration work.

## Safety behavior to expect

- The input file is never changed or overwritten.
- The output directory is assembled through a staging directory and published only
  after every file succeeds.
- An existing output directory is refused.
- Rejected variants are recorded in the manifest but their audio is not presented.
- The audition loader rejects unsafe artifact paths, missing/changed plans, duplicate
  strengths, and WAVs whose rate/channel/frame metadata does not match the manifest.
- Preview matching uses gated BS.1770 loudness for captures of at least 400 ms and
  labels an RMS fallback for shorter captures. Ceiling verification uses estimated
  true peak, while the real-time limiter itself remains a zero-lookahead sample-peak
  limiter. These are early-product limitations, not mastering claims.

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

Expected current result: `SUMMARY passed=20 failed=0`.

## Safety behavior to expect

- The input file is never changed or overwritten.
- The output directory is assembled through a staging directory and published only
  after every file succeeds.
- An existing output directory is refused.
- Rejected variants are recorded in the manifest but their audio is not presented.
- Preview matching uses gated BS.1770 loudness for captures of at least 400 ms and
  labels an RMS fallback for shorter captures. Ceiling verification uses estimated
  true peak, while the real-time limiter itself remains a zero-lookahead sample-peak
  limiter. These are early-product limitations, not mastering claims.

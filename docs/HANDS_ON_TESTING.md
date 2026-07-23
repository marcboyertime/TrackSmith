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

Selecting a result reveals its loudness match, approximate true-peak measurement,
audio delta, every DSP node, parameter, confidence, and rationale.

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

`PreviewCLI` uses the deterministic offline interpreter, so its useful language is
bounded by the checked-in production vocabulary. The native companion can select an
OpenAI or Gemini semantic adapter for free-form text, but only after a Keychain
credential and explicit cloud-reasoning consent; those adapters still cannot create
new DSP or Logic capabilities. Inspect the typed interpretation, evidence,
hypotheses and emitted graph instead of assuming every word was honored.

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

For the current source, require `SUMMARY passed=42 failed=0`, followed by:

```text
PASS Audio Unit rendered, captured, previewed, committed, and reverted
```

That host probe executes the complete local session without Logic: AU rendering,
heartbeat discovery, recent capture, SHA-256 artifact verification, three previews,
exact commit, EQ lock, “use less compression” revision, undo/redo, `fullState`
reload, global bypass/restore, two-instance isolation, offline/AU output parity, and
bit-exact dry revert.
The current HostProbe source additionally checks null/pointer-replacing host buffers,
bounded scheduled output-gain events, reset-versus-bypass automation, conservative
silence/tail reporting, and one graph per callback. Do not proceed to Logic if any
of those cases fail.

To rerun the redacted real-audio proof with a legally owned vocal WAV and a new
output directory:

```sh
swift run -c release VerticalSliceCLI \
  "/absolute/path/to/vocal.wav" \
  --source vocal \
  --prompt "make this clearer, warmer, and more controlled" \
  --output "/absolute/path/to/new-proof-directory"
```

Require `overallPassed: true` and all 18 entries in `evidence.json` to pass. The
runner hashes the external source before and after, but it is an offline public-API
proof; it does not host the AU or Logic. The recorded run and exact metric boundaries
are in [`evidence/MVP_VERTICAL_SLICE_2026-07-13.md`](evidence/MVP_VERTICAL_SLICE_2026-07-13.md).

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
certificate and its Team ID, builds Release, development-signs both nested bundles,
strict-verifies a fresh staging bundle, and replaces the installed bundle exactly.
It refuses installation if the Team IDs do not match. The first signing attempt may
present a macOS private-key authorization dialog. On this development Mac, do not
enter an administrator name or password unless the user has opened the authorized
SafeSight maintenance window; never bypass the delay, disable protection, alter
SafeSight, or share the password. If
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

Then test the companion session path:

1. Keep the AU inserted and open `~/Applications/Logic Audio Assistant.app`.
2. Within five seconds, select the active insert shown under **Logic Audio Units**.
   Confirm the sample rate/channel count and input peak respond to playback.
3. Play a representative section, stop, then click **Analyze Recent Playback**.
   The current request asks for up to the most recent 15 seconds from the AU's
   continuously bounded dry-input ring. The ring holds at most 30 seconds and 24 MiB,
   so high-rate stereo formats may retain less. It does not arm the next playback.
4. Confirm a waveform and capture duration appear. Choose a source, enter a supported
   request, and click **Create 3 Previews**.
5. Play the preview and switch among Original, Conservative, Balanced, and Strong.
   All loaded versions should remain at the same sample position and show their
   loudness-match gains. A collapsed or constraint-violating option may be rejected
   rather than presented as valid.
6. Select a processed result and inspect every change card's module, parameters,
   rationale, category and confidence.
7. Click **Use as Working**, lock an EQ card, enter “use less compression” under
   revision, and click **Render Revision**. Confirm the locked EQ and unrelated cards
   are unchanged, then test **Undo Edit** and **Redo Edit**.
8. Click **Commit Working Plan**, resume Logic playback, and confirm that the sound
   matches the audition. Toggle **Bypass All** and **Restore Processing**; bypass must
   not discard the graph. Then click **Revert** and confirm the pre-capture graph
   returns.
9. After preserving any previews you want, choose **Delete Local Audio Cache** in the
   companion toolbar and confirm. Captures and rendered previews should disappear;
   the Logic source, inserted AU, committed graph, and active-instance discovery must
   remain intact.

Direct current-build testing on 2026-07-13/14 completed steps 1–8 in Logic Pro
11.2.2 on a disposable 44.1 kHz stereo runtime, including verified recent capture,
three previews, inspection, locked-EQ revision, commit, bypass/restore, project
save/reload, and isolation between two instances. Source-file hashes remained
unchanged. The measurements, command/state IDs, fingerprints, and exact proof
boundary are recorded in
[`evidence/LOGIC_MVP_VALIDATION_2026-07-14.md`](evidence/LOGIC_MVP_VALIDATION_2026-07-14.md).
Cache deletion is separately automated and tested but was not performed on the
preserved Logic evidence session.

A matching commit acknowledgement or heartbeat means the graph was applied and
published for a callback, not that callback audio was observed or compared.
There is no old/new graph crossfade yet, so listen for a click at commit/revert and
record it as a failure if heard.

During Computer Use/permission testing, Logic displayed an instability alert and
recovered. The disposable insert was undone, no plug-in crash report was present,
and `SkyComputerUseService` did crash. A lifecycle/status race was fixed afterward
as a plausible contributor, but no root cause is claimed. If the alert recurs after
permission is granted, stop the case, undo the test insert, and preserve the exact
time and diagnostic report.

## Safety behavior to expect

- The input file is never changed or overwritten.
- The output directory is assembled through a staging directory and published only
  after every file succeeds.
- An existing output directory is refused.
- Rejected variants are recorded in the manifest but their audio is not presented.
- The audition loader rejects unsafe artifact paths, missing/changed plans, duplicate
  strengths, and WAVs whose rate/channel/frame metadata does not match the manifest.
- Preview matching uses gated BS.1770 loudness for captures of at least 400 ms and
  labels an RMS fallback for shorter captures. Ceiling verification and commit-time
  rejection use approximate true peak: Annex 2 only at 48 kHz and a bounded
  windowed-sinc estimate at other rates. The real-time limiter remains a
  zero-lookahead sample-peak limiter. These are early-product limitations, not
  mastering or non-48-kHz conformance claims.

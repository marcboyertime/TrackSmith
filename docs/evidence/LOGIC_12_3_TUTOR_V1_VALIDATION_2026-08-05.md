# Direct Logic Pro 12.3 tutor validation (2026-08-05)

Executed on the development Mac on 2026-08-05 against the checklist in
[`MANUAL_LOGIC_TUTOR_TESTS.md`](../MANUAL_LOGIC_TUTOR_TESTS.md). Every step
below was actually performed in Logic Pro 12.3; steps not performed are listed
explicitly in "Not executed".

The UI was driven through macOS screen automation by the engineer running this
session, using semantic navigation (menus, named controls) rather than
hardcoded coordinates against the product. **This automation is test
tooling only.** TrackSmith itself performed no Logic action at any point: the
product has no Accessibility, AppleScript, key-command, or MIDI path to Logic,
and the tutor's own step cards state "You perform every action — TrackSmith
never touches Logic."

## Environment and identities

- Source: `codex/logic-production-tutor-v1` at `e2a83de` (clean worktree at
  install time; a later commit adds the defect fix found by this run).
- macOS 26.3 (25D125), Apple Silicon; Logic Pro 12.3; Xcode 26.6; Swift 6.3.3.
- App: `com.marcboyer.logicaudioassistant`, CDHash
  `65644cab5a4318f5311cf83de41fa3d8b001511a`
- AU extension: `com.marcboyer.logicaudioassistant.AudioUnit`, CDHash
  `0232ff5888041219f9d36557cec6cfdb4981eff1`
- Both signed `Apple Development: mbonyx20@gmail.com (6F5LSRB8MW)`, Team
  `KDV9RC892F`; App Group `KDV9RC892F.com.marcboyer.logicaudioassistant`.
- AU component: `aufx / LgAA / ExAI`, version 65536.
- `auval -v aufx LgAA ExAI`: **AU VALIDATION SUCCEEDED**.

## Test material

`fixtures/generated/demo-vocal.wav`, copied to
`~/Desktop/TrackSmithTutorT7/tutor-test-source.wav`.
SHA-256 `ad289bb28f37fd2bef753b176e7a371bf08fbb7b4c5c76adb5e83db2a694e2c0`,
WAVE 48 kHz / 24-bit / mono / 8.000 s (Logic's import dialog reported the same
format).

**This is a deterministic generated test signal from `TestSignalGenerator`,
not a real vocal performance.** It validates workflow mechanics only. It
supports no perceptual claim, and it is not the owner self-evaluation required
by acceptance criterion 23.

## Results

| # | Step | Result |
|---|---|---|
| 1 | Record installed identities | **Pass** — recorded above |
| 2 | Insert TrackSmith on a track, play | **Pass** — inserted via Inspector → channel strip → Audio FX in a disposable empty project; plug-in reported "Audio arriving peak −12.1 dBFS" during playback |
| 3 | Analyze Recent Playback, Source = Vocal | **Pass** — "Recent playback captured", 14.9 s · 44100 Hz · 1 ch, waveform populated (Logic resampled the 48 kHz file to the 44.1 kHz project rate) |
| 4 | Select Guide Me | **Pass** — top-level Guide Me / Create For Me selector present and functional |
| 5 | Enter the nasal request, start lesson | **Pass** — evidence banner became "Grounded in your current capture — Local measurements from your recent capture inform the hypotheses. They are descriptive and cannot prove a cause." |
| 6 | Hypotheses and uncertainty visible | **Pass** — four competing causes shown under "Possible causes — deliberately more than one", including "may also be part of the natural character of this source rather than a defect; listening and your feedback remain decisive" |
| 7 | One exact first step | **Pass** — "STEP 1 OF 5 · EXPERIMENT 1 · Find the compressor on the vocal channel strip", with instruction, 3 substeps, listen-for, reason, expandable Producer lesson and "Where to find it", stop rule, could-go-wrong, and undo |
| 8 | AU graph unchanged during tutor use | **Pass** — after the full session the plug-in still read "Deterministic graph active", "Waiting for audio", Output gain +0.0 dB; no graph committed, no node cards |
| 9 | Report feedback, next step adapts | **Pass** — `Done` advanced to "STEP 2 OF 5 · Bypass only the compressor and listen again" with all six feedback controls |
| 10 | Undo visible and correct | **Pass** — `Undo` routed to "STEP 5 OF 5 · Restore the compressor exactly as it was", the catalog's declared rollback branch |
| 11 | Advance across experiments | **Pass** — continuing advanced to "EXPERIMENT 2 · Open Channel EQ on the vocal track", the next competing cause |
| 12 | Offline provider path | **Pass** — the entire lesson ran with Provider = "Offline deterministic", header "Local interpretation · no network". No credential, no network |
| 13 | Tutor persistence | **Pass** — `ProductionTutor/tutor-session-83a2db23-….json`, `-rw-------` in a `drwx------` directory, 32,249 bytes, checksummed envelope v1.0 |
| 14 | Persistence privacy | **Pass** — recorded the exact feedback sequence (`done, undo, done`), both attempted procedure IDs, and UUID-only authority (`captureSnapshotID`, `instanceID`, `runtimeEpoch`, `sourceType`). Scans for filesystem paths, `.wav`/`.logicx` names, project name, credential patterns, and base64 audio blobs all returned **absent**; `providerAuditSummary` null |
| 15 | Source audio unchanged | **Pass** — SHA-256 after the session identical to before |
| 16 | Companion restart restores the session | **Pass** — after quit/reinstall/relaunch the lesson, request text, and progress restored |
| 17 | Stale AU authority demotes to historical | **Pass** — the restored lesson's banner became "Capture evidence is historical — The Audio Unit or capture changed since this lesson started. Its measured statements describe the earlier capture, not the live session." |
| 18 | Create For Me regression | **Defect found, fixed, and re-verified in host — see below** |

### Navigation-card accuracy (new evidence)

The step-1 card's "Where to find it" panel displayed:

```
Logic Pro 12.3 · Inspector channel strip or Mixer
Inspector → Channel strip → Audio FX
The vocal track must be selected so the Inspector shows its channel strip.
Path from Apple documentation; not yet re-verified on this machine.
```

That documentary path is the exact path used successfully to insert the
plug-in in Logic 12.3 during this run. The card's honest
"not yet re-verified" label is retained in the catalog because a single
successful traversal by the engineer is not the systematic per-control
re-verification the `directlyVerified` status is reserved for.

## Defect found by this run

Selecting **Create For Me → Create 3 Previews** on the captured audio failed
with a visible, safe error:

```
Operation failed safely
invalidValue(-inf, Swift.EncodingError.Context(codingPath: [
  "originalAnalysis", "short_term_loudness_lufs_timeline", "values"],
  debugDescription: "Unable to encode Double.-inf directly in JSON."))
```

- **Root cause.** `MetricSeries.init` stored timeline values verbatim. A
  3-second short-term LUFS window over exact digital silence is `-infinity`,
  and `JSONEncoder` refuses to encode a nonfinite `Double`. The 14.9-second
  capture contained a silent tail because the region is only 8 seconds, so the
  whole preview manifest failed to encode.
- **Pre-existing, not introduced here.** The tutor commits
  (`7b1b972..e2a83de`) touch zero files under `packages/AudioAnalysis`; the
  affected code dates to the initial snapshot `553821a`. Scalar metrics
  already sanitized (`absoluteGated.isFinite ? … : nil`,
  `SourceMetricValue` clamping) and `LoudnessMeter.loudnessRange` filters
  nonfinite values — timelines were the gap.
- **Severity.** Any capture containing digital silence blocks Create For Me.
  This is common: the capture window routinely outlives the region.
- **Fix.** `MetricSeries.init` now sanitizes every series value, clamping into
  the declared `validRange` when present so digital silence lands on the
  documented floor (−240 LUFS) instead of a fabricated zero.
- **Regression test.** `silent-window analysis series stay JSON-encodable`
  builds a half-tone/half-silence buffer, asserts every series value is
  finite, asserts silence reaches the floor rather than zero, and encodes both
  `AnalysisReport` and `SourceAwareAnalysisReport`. `TestRunner` is now 83
  unconditional checks and passes 83/83.
- **Failure behavior was correct.** The app reported "Operation failed safely",
  changed no AU graph, and left the capture and session intact.
- **Re-verified in host.** The fixed build was reinstalled (app CDHash
  `a79cd32cabf0046299db578ac1a4b34a0e11e687`), the project rebuilt, and a fresh
  11.2 s capture taken. **Create For Me → Create 3 Previews now reports
  "3 previews ready"** with validated interpretation
  ("increase clear, increase warm, increase controlled"), grounded hypotheses
  with strategies and risks, measured evidence, and provider evidence
  `mock-offline-1 · configured deterministic-intent-v1 · 1 attempt · 2 ms`
  with the complete audit `decoding → schema → semantic → capability →
  stateReference → constraint`.

## Secondary observations (not blocking, recorded for follow-up)

1. **Silence-dominated captures still yield a misleading dynamics number.**
   The same 11.2 s capture (roughly a third digital silence) reported
   `level_variability_p90_p10_db: 224.1 decibels`. After the fix this value is
   finite and encodable, and it is displayed as `contextual` descriptive
   evidence rather than a verdict, but a ~224 dB "level variability" is not a
   meaningful production statement. The underlying issue is that percentile
   dynamics over digital silence are not well defined. Worth a follow-up that
   either excludes silent windows from percentile dynamics or attaches an
   explicit low-confidence/inapplicable flag.
2. **Replacing the AU bundle under a running Logic is hazardous.** Midway
   through this run the fixed build was installed while Logic still had the
   previous `.appex` loaded — contrary to the installer's own instruction to
   close Logic first. Logic then wedged on a document-close dialog that would
   not dismiss, and the (unsaved, disposable) test project had to be closed
   without saving. No user data was at risk: the project was scratch created
   for this test, and the external source WAV was verified unchanged
   afterwards. This is operator error rather than a product defect, but it is
   worth stating in the manual procedure that the AU must not be reinstalled
   while Logic is running.

## Not executed

- **Owner self-evaluation (acceptance criterion 23).** No real vocal and no
  human listening judgment. The tutor's feedback answers in this run were
  chosen to exercise state transitions, not to report perceived sound. No
  perceptual claim of any kind is made.
- **In-host revision and commit** (`Render Revision`, `Commit Working Plan`)
  and bypass/restore. Previews render; auditioning, revising, and committing
  the graph inside Logic were not exercised.
- **Logic project save/reload** into a fresh AU runtime.
- **Thread Sanitizer** for the current harness.

## Claim boundary

This record proves that the signed build loads in Logic Pro 12.3, receives
host audio, captures it, and drives the Guide Me tutor through recognition,
competing hypotheses, exact reversible steps, deterministic feedback
branching, rollback, bounded checksummed persistence, and a clean privacy
audit — offline, with no provider and no network, without ever mutating the AU
processing graph. It also proves the Create For Me preview path was broken for
silence-containing captures and is now fixed and regression-tested.

It does **not** establish perceptual quality, that the tutor's advice improves
any real vocal, or that the remaining checklist rows pass. Tutor gate T7 is
therefore **partially satisfied** and remains open until the unexecuted rows
and the owner self-evaluation are recorded.

# Logic Pro 12.3 Native Effect Empirical Measurement Protocol

Status: protocol and deterministic fixture generator implemented 2026-07-16;
revised 2026-08-05. The current 200-identity ledger contains 189 `not_run`, 11
`partial`, and 0 `complete` records. Partial direct-host evidence covers
Bitcrusher, Channel EQ, Compressor, DeEsser 2, Noise Gate, ChromaVerb, Space
Designer, Stereo Delay, Tape Delay, Adaptive Limiter, and Direction Mixer;
partial runs do not establish complete models, Logic equivalence, or
perceptual claims. The full campaign remains open.
This distinction is deliberate. Apple documents controls and intended behavior,
but documentation does not expose every coefficient, transfer curve,
oversampling choice, nonlinear state, tolerance, or signal-dependent interaction.

## Purpose and claim boundary

This lane turns TrackSmith's complete documentary review into reproducible
measurements without pretending one laboratory plot is complete production
knowledge. It applies to all 142 reviewed effects/tools, including all 35
Pedalboard effects plus Mixer and Splitter, and to explicitly scoped instrument
experiments.

The lane may establish, for the exact tested state:

- latency, polarity, gain, channel mapping, tail length, time variance, and
  deterministic-repeat behavior;
- approximate linear magnitude/phase response when the tested state behaves
  sufficiently linearly and time-invariantly;
- level-dependent transfer, compression/envelope behavior, harmonic and
  intermodulation products, alias products, and noise/self-output;
- stereo crossfeed, frequency-dependent width, and mono-sum consequences;
- differences among documented parameter states and graph topologies.

It cannot establish:

- Apple's private implementation source, circuit equivalence, or behavior at
  untested sample rates, channel formats, settings, levels, tempos, or signals;
- that a measured change is musically better, universally “warm,” “punchy,”
  “expensive,” or appropriate for every source;
- production suitability without level-matched listening on legally usable
  vocals, drums, bass, guitar, synth/keys, and complete mixes;
- permission for TrackSmith to insert, automate, or otherwise control a
  Logic-native effect. The ordinary AU remains advisory-only for native tools.

## Deterministic fixture suite

Build and generate two copies, then compare them byte-for-byte:

```bash
swift build --product TestSignalGenerator
.build/debug/TestSignalGenerator --logic-measurement-suite \
  tmp/logic-native-measurement-suite-v1-a
.build/debug/TestSignalGenerator --logic-measurement-suite \
  tmp/logic-native-measurement-suite-v1-b
diff -rq tmp/logic-native-measurement-suite-v1-a \
  tmp/logic-native-measurement-suite-v1-b
```

The suite is 48 kHz, signed PCM24 WAV and writes a manifest containing each
input hash, frame count, channel count, duration, encoding, and purpose. It
contains:

| Fixture family | Main use |
|---|---|
| Silence | Self-noise, tails, modulation output, denormals, and false output |
| Single impulse and level ladder | Latency, polarity, IR/tail, and level dependence |
| 20 Hz-20 kHz logarithmic sweep | Broadband response, resonances, distortion products, aliasing, and tails |
| 1 kHz amplitude ladder | Static curve, thresholds, knees, gates, clipping, and gain-stage dependence |
| Multitone | Simultaneous-band response and nonlinear/intermodulation behavior |
| 60 Hz/7 kHz and 19/20 kHz pairs | Low/high and high-frequency intermodulation/difference products |
| Dynamic noise bursts | Detector, attack, release, hold, recovery, diffusion, and transient behavior |
| Guitar-like and bass-like plucks | Reproducible musically structured stress probes; not real-instrument substitutes |
| Vocal-like harmonic/noise phrases | Reproducible vocal-chain regression; not a listening-quality reference |
| In-phase, left-only, right-only, anti-phase, one-sample-offset, and mid-low/side-high stereo signals | Channel matrix, crossfeed, phase, width, latency, and mono compatibility |

The generated synthetic fixtures may be regenerated at any time. Test outputs
are derivative evidence and must live in a dated run directory, never overwrite
an input fixture, and never replace user source material.

## Required run identity

Every render result must carry all of the following. Missing identity makes the
result exploratory, not evidence:

```json
{
  "schemaVersion": "1.0",
  "runID": "unique-and-immutable",
  "recordedAt": "RFC-3339",
  "identityIdentifier": "logic-pro-12.3:catalog-identity",
  "identityName": "",
  "identityType": "effect_or_native_audio_tool",
  "status": "partial|complete",
  "exactTransferCharacterized": false,
  "directHostEvidence": true,
  "environment": {
    "macOS": {"version": "", "build": ""},
    "hardware": {},
    "Logic": {"version": "12.3", "build": "6674"},
    "audioBufferFrames": null,
    "lowLatencyMode": null
  },
  "project": {
    "sampleRateHz": 48000,
    "tempoBPM": 120,
    "trackChannelFormat": "mono|stereo|mono-to-stereo|other"
  },
  "nativeState": {
    "presetName": "",
    "parameters": {}
  },
  "input": {
    "artifactPath": "relative",
    "fileSHA256": "",
    "pcmSHA256": "",
    "sourceUnchanged": true
  },
  "renderMethod": {},
  "dimensionCoverage": {
    "campaign-required-dimension": {"status": "not_run|partial|complete_*", "evidence": ""}
  },
  "measurements": {},
  "interpretation": {"stronglySupported": [], "inferences": [], "notEstablished": []},
  "artifactFiles": [{"path": "relative", "sha256": "", "role": ""}],
  "claimBoundary": {}
}
```

Unknown settings must be recorded as `null` with an evidence note; they must not
be filled with plausible defaults. `run.json` and every retained artifact are
validated by the coverage audit before a campaign identity can move from
`not_run`.

Do not place user names, project notes, raw credentials, unrelated file names,
or cloud-provider content in a measurement manifest.

## Safe project setup

1. Use a new disposable Logic project and copied/generated fixtures. Never use
   the only copy of user audio.
2. Record the installed Logic version/build before the run. A newer build gets a
   new evidence lane; it does not rewrite 11.2.2 or 12.3 build 6674 evidence.
3. Set the project to 48 kHz **before importing** a v1 fixture. If the project
   rate was changed after an import, remove that test region and re-import the
   fixture; do not infer correctness from the displayed region length. Set fader
   to 0 dB, pan/balance neutral, no sends, no other inserts, no automation, and
   normalization/dither off. Turn the metronome and count-in off. Record any
   deviation.
4. Confirm channel format before insertion. Mono, stereo, dual-mono,
   mono-to-stereo, surround, and Spatial Audio instances are different tests.
5. Prefer an exact cycle-range project/section bounce for fixed-length fixtures,
   with the cycle duration equal to the manifest duration. Reject a render whose
   frame count, sample rate, bit depth, channel interpretation, or decoded source
   alignment is wrong. Region export can silently carry an earlier import/range
   mistake and is not evidence merely because it completed.
6. Bounce/capture an unprocessed baseline through the **same path** and hash it.
   For the PCM24 v1 fixture at matching rate, require decoded-PCM identity before
   attributing a residual to the effect. A quiet-segment mismatch must trigger a
   routing, metronome, monitoring, or hidden-processing investigation.
7. When a mono source is bounced through Stereo Out in split mode, retain both
   files, verify decoded L/R identity, and label the result as duplicated mono
   output. It is not evidence of stereo-link or stereo-instance behavior. Compare
   decoded PCM hashes as the signal criterion while retaining WAVE container
   hashes; Logic may vary container metadata across otherwise identical renders.
8. Insert exactly one native effect or one explicitly recorded Pedalboard graph.
   Record every visible control, switch, model, style, quality setting, sync
   state, tempo dependency, preset identity, and hidden extended parameter.
9. Render with tails when the processor has delay, reverb, look-ahead, release,
   convolution, modulation, or other state. Render both offline and real time
   when external state, tempo sync, modulation, randomization, or adaptive
   behavior could make them differ.
10. Retain the first render after insertion, reload, bypass, or a material state
   transition as diagnostic evidence. Continue until at least three **settled**
   renders have been acquired. Hash equality is evidence of repeatability only
   for that state. A first-transition difference is not silently discarded;
   persistent differences trigger a time-variance/random-state analysis and are
   not automatically a bug.
11. Verify the input fixture hash is unchanged after every run.

## Parameter campaign

Campaign execution is usage- and product-role weighted. The first processing
queue is Channel EQ, Compressor, DeEsser 2, Noise Gate, ChromaVerb, Space
Designer, Stereo Delay, Tape Delay, ChromaGlow, Limiter, Direction Mixer, and
Pitch Correction, with Gain and metering as cross-cutting dependencies. The
machine-readable rationale and curated-case recurrence signals are in
`research/knowledge/logic-pro-12.3-core-effect-priority.json`. Bitcrusher's first
partial run is retained as evidence, but it and the Pedalboard subeffects no
longer displace core processors in the next-run queue.

This is TrackSmith research sequencing, not a claim about global plug-in usage
telemetry or artistic importance.

The generated campaign gives every first-queue identity a `core_*` measurement
profile and a `core_effect_priority_lane`. A partial record may report a nonempty
subset of declared dimensions; it may not introduce undeclared dimensions. A
complete record must include every declared generic and processor-specific
dimension with a complete status. This lets early direct-host evidence accumulate
without promoting one preset or one fixture into a complete characterization.

For each effect, begin with bypass/path baseline and documented default. Then
use a bounded design rather than blindly enumerating the Cartesian product:

- each continuous control at minimum, 25%, center/default, 75%, and maximum,
  with denser sampling around thresholds, knees, resonances, crossovers, or
  discontinuities;
- every discrete model, mode, slope, circuit, algorithm, routing, sync, stereo,
  quality, and oversampling choice;
- at least low, nominal, and high input levels for nonlinear, dynamics,
  envelope-following, saturation, clipping, modeled, and adaptive processors;
- relevant mono, stereo, mono-to-stereo, in-phase, anti-phase, and one-sided
  channel inputs;
- at least two tempos and a tempo change for synced delay/modulation tools;
- three identical renders for stochastic, analog-variation, randomization,
  modulation, machine-learning/adaptive, or time-varying tools;
- explicit reset/reload and project save/reopen checks for stateful tools.

Interactions get a second-stage factorial or response-surface design only where
the first stage shows coupling. Examples include Drive x Output, threshold x
ratio, attack x release, feedback x delay, cutoff x resonance, dry/wet x
latency, and Pedalboard split frequency x branch gain. This controls experiment
size without pretending controls are independent.

## Measurements and interpretation

### Linear or approximately linear states

- Align baseline and output by measured latency before nulling.
- Estimate gain, polarity, impulse/tail response, frequency magnitude, phase,
  and group delay from impulse/sweep data.
- Report the residual ratio after alignment as
  `20 log10(RMS(output - gain*baseline) / RMS(baseline))` and retain the audio
  residual. A deep null is evidence of similarity under the tested condition,
  not identity of implementation.
- Reject an LTI interpretation when repeated responses move, output contains
  strong nonlinear products, or response changes materially with input level.

### Nonlinear and modeled states

- Use the amplitude ladder for the input/output curve, symmetry, clipping/fold/
  wrap onset, hysteresis/state dependence, and level-dependent spectral change.
- Use steady sines, multitone, and two-tone fixtures for harmonics, THD+N,
  intermodulation, difference products, and alias components. Record FFT size,
  window, averaging, excluded bins, and noise-band definition with each number.
- Repeat at multiple sample rates before making an aliasing or oversampling
  claim. A spectral component observed only at 48 kHz is not a universal model.
- Loudness-match any musical comparison. Output gain cannot be used as evidence
  that more distortion, compression, or excitation is preferable.

### Dynamics, gates, envelope followers, and transient tools

- Measure static curve separately from time behavior.
- Use bursts at multiple levels/durations to estimate onset, attack, overshoot,
  hold, release, recovery, pumping, and detector frequency dependence.
- Record auto-gain/makeup behavior separately; it biases bypass comparisons.
- Do not infer proprietary ratio, time constant, or topology when controls do
  not expose it. Report an observed effective response under the fixture.

### Delay, modulation, pitch, reverb, and time-varying tools

- Record project tempo, transport phase, sync division, free/sync state, input
  channel format, tail handling, and repeat number.
- Inspect echo times, feedback decay, spectral decay, modulation rate/depth,
  pitch tracking, transient smear, pre-echo, stereo motion, and mono fold-down.
- A single impulse is insufficient for pitch trackers, granular tools,
  reverbs with modulation, and nonlinear feedback. Use the full fixture set and
  real musical material.

### Stereo and spatial behavior

- Left-only and right-only renders identify the 2x2 channel transfer/crossfeed
  under a specific state. In-phase, anti-phase, one-sample-offset, and
  mid-low/side-high fixtures expose phase and frequency-dependent width behavior.
- Record L/R balance, Mid/Side energy, correlation, interchannel latency, mono
  sum loss, low-band side energy, peak, and loudness. No one width number proves
  a stable or desirable stereo image.
- Spatial Audio, binaural, surround, downmix, and monitoring plug-ins require
  format-specific lanes and delivery checks; they cannot be collapsed into the
  stereo lane.

## Pedalboard campaign

The documentary effect/control/risk map for every pedal is in
`research/analysis/TRACKSMITH_LOGIC_PRO_12_3_TOOL_ATLAS.md`; the typed catalog
contains 35 effect pedals plus Mixer and Splitter. The empirical campaign must
test both each pedal alone and material graph topologies:

1. serial A-only baseline;
2. A/B equal parallel split with Mixer at A, center, and B;
3. frequency split at multiple crossover positions, with unity branches before
   adding effects;
4. the same pedal before versus inside versus after the split section;
5. branch polarity/latency/null and mono-fold checks;
6. mono, stereo, and mono-to-stereo states where available;
7. order swaps for nonlinear, EQ/filter, compressor, modulation, and ambience
   pairs;
8. automation/macro sweeps only in a separate, user-driven host lane.

Pedal-order claims must name the mechanism. For example, EQ before distortion
changes which frequencies drive the nonlinear stage; EQ after distortion shapes
the generated partials. Compression before an envelope filter changes its
control signal; compression after shapes the already-filtered envelope. A dry/
wet branch can preserve transients but can also comb when the wet path has
latency or phase rotation. These are hypotheses to measure and audition, not
fixed laws that one order is always better.

### Bitcrusher-specific grid

Apple documents Resolution 1-24 bits, Downsampling as an effective sample-rate
division that does not alter speed/pitch, pre-effect Drive, a Clip Level, Fold/
Clip/Wrap modes, and dry/effect Mix. The test grid must separate them:

- Resolution sweep with Downsampling 1x, neutral Drive, high Clip Level, 100%
  effect; inspect quantization error versus level and whether error is tonal or
  noise-like. Do not assume dither.
- Downsampling sweep at 24-bit resolution; use sweep, 19/20 kHz tones, and
  multiple project sample rates to locate aliases. Do not summarize it as only
  “darker.”
- Drive and Clip Level grid for each Fold/Clip/Wrap mode; derive observed
  threshold/symmetry/remapping from the amplitude ladder without inventing
  Apple's equations.
- Mix sweep after latency/alignment checks; parallel cancellation or combing is
  possible if the wet path differs in delay/phase.
- Musical checks on vocal consonants, drum attacks/cymbals, bass pitch/weight,
  guitar note separation, synth stereo state, and full-mix harshness/headroom.

The 2026-07-18 partial run closes only Default/bypass, settled repeatability,
save/reload, source preservation, and limited level/polarity/peak evidence for one
48 kHz mono amplitude fixture. It does not close any grid above.

## Listening and production judgment

After measurements reject unsafe or constraint-violating states, conduct
level-matched, randomized listening on real provenance-recorded material. Use
MUSHRA only when the test question, hidden reference, anchor design, listener
training, randomization, repeatability, and statistical analysis satisfy the
method's requirements. For ordinary production choices, an auditable A/B/C
preference/revision session is more honest than calling an informal audition a
formal perceptual test.

TrackSmith should store conclusions in three layers:

1. `APPLE_DOCUMENTED_BEHAVIOR` — what Apple actually states;
2. `TRACKSMITH_MEASURED_BEHAVIOR` — exact run identity, hashes, method, results,
   uncertainty, and repeatability;
3. `PRODUCTION_PRACTICE_HEURISTIC` — source/context-dependent use and risk,
   always with listening decisive.

Contradictions among those layers remain visible. Measurement does not silently
rewrite documentation, and a professional heuristic does not become a measured
fact.

## Current completion state

- Implemented: complete reviewed documentary catalogs; immutable sources;
  deterministic 48 kHz PCM24 fixture generator; per-fixture hash manifest;
  repeatability proof for two independently generated suites; this protocol;
  hash-audited partial Bitcrusher, Channel EQ, and Compressor runs with saved
  projects and direct Logic 12.3 artifacts; per-input-level amplitude-ladder
  analysis; exact same-path baseline/frame/channel gates.
- Not yet proven: full render matrix for all native effects/pedals; exact
  parameter-transfer characterization; cross-sample-rate campaign; formal
  listening campaign; native host automation of measurement runs.
- Intentionally unsupported: TrackSmith executing Logic-native effects,
  automation, project edits, Accessibility workflows, or arbitrary plug-ins.

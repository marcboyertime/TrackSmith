# Logic Pro 12.3 native Bitcrusher empirical evidence — 2026-07-18

## Verdict

This is a **partial direct-host characterization**, not a complete model of
Bitcrusher. In Logic Pro 12.3 build 6674, the observed `Default Preset` is an
active composite process:

- Mode: `Clip`
- Drive: `+3.0 dB`
- Resolution: `8 bit`
- Downsampling: `1x`
- Mix: `100%`
- Clip Level: `0.0 dB`

The state was observed in the plug-in UI before save and again after reopening
the project. Three settled pre-save renders and one post-reload render have the
same decoded-PCM SHA-256. Three settled bypass renders are sample-for-sample
identical to the source fixture. The saved project, renders, analyses, screenshots,
and exact hashes are retained under
`research/evaluation/logic-native-empirical-runs/logic-12.3-bitcrusher-default-2026-07-18/`.

This proves repeatability and save/reload behavior only for the stated host,
project, signal, channel format, sample rate, and parameter state. It does not
prove Apple's private equations or characterize Fold, Wrap, Downsampling above
1x, other bit depths, stereo, other rates, or musical preference.

## Exact environment

| Field | Evidence state |
|---|---|
| macOS | 26.3, build 25D125 |
| Hardware | MacBookPro18,2; Apple M1 Max; 64 GiB |
| Logic Pro | 12.3, build 6674; bundle `com.apple.logic10` |
| Logic signature | Apple Mac OS Application Signing; Team ID `F3LWYJ7GM7`; full CodeDirectory SHA-256 `be60f7ec31ed955307f7021641d763c26ce4988e976aa8332f21bb9dc4fe8e8a` |
| Project | 48,000 Hz; 120 BPM; mono audio track to Stereo Out; track and output at 0 dB; pan center |
| Audio buffer / Low Latency mode | Not captured; no claim made |

The run used a disposable Logic project. TrackSmith did not acquire authority to
insert, set, or execute native Logic effects. Computer interaction was confined
to this measurement project.

An earlier attempt is explicitly excluded. Its project remained at 44.1 kHz when
the 48 kHz fixture was imported, so Logic resampled the project-local source. That
attempt remains quarantined under
`tmp/logic-native-empirical/runs/2026-07-18-bitcrusher-default`; none of its audio
supports this run's claims and it was not overwritten or silently merged.

## Input and render method

The source was `amplitude_ladder_1khz_mono.wav` from
`logic-native-measurement-suite-v1`:

- file SHA-256: `469045245bc4f67389e1c38cf4201308efbd2fbb24ad61767718ab63476f1410`
- decoded-PCM SHA-256: `bcb8df1858ceedca288cd9a207de9adc21fd370ff03891a970a051ee38949370`
- WAVE PCM24, mono, 48,000 Hz, 384,000 frames, 8 seconds

Renders used **File > Export > Regions as Audio Files** with WAVE/24-bit,
Normalize Off, no tail, no volume/pan automation, and no tempo information. The
plug-in header On/Off control produced the bypass state; the export dialog's
separate `Bypass Effect Plug-ins` option remained off. That dialog does not expose
a realtime/offline selector or dither choice, so this record makes no scheduling
or dither claim.

## Objective results

### Settled bypass

All three settled bypass renders have decoded-PCM SHA-256
`bcb8df1858ceedca288cd9a207de9adc21fd370ff03891a970a051ee38949370`,
exactly matching the source across all 384,000 samples. Their zero-lag
correlation is 1.0, gain is 0 dB, polarity is noninverted, and no sample differs.
Whole-file WAVE hashes differ because non-audio container bytes vary; decoded
PCM is the signal-repeatability criterion.

### Settled observed Default Preset

Three settled pre-save renders and one post-reload render share decoded-PCM
SHA-256 `89b449e88b149ca9dc95e188506bfc0fa61412190a2ff2739f2bb28bb5fe48c5`.

| Measurement | Source / bypass | Observed Default Preset |
|---|---:|---:|
| Peak | -0.9999997 dBFS | -0.0000010 dBFS |
| RMS | -11.0332719 dBFS | -8.4563988 dBFS |
| First nonzero sample | 1 | 39,083 |
| Best-fit gain relative to bypass | — | +2.5463659 dB |
| Zero-lag correlation to bypass | — | 0.9964939 |
| Residual RMS after direct comparison | — | -19.9368585 dBFS |
| Polarity | — | noninverted |

The output reaching full scale is consistent with the observed +3 dB Drive and
0 dB Clip Level interacting with Clip mode. The quietest ladder material being
mapped to zero is consistent with coarse amplitude quantization. Those are
mechanism-level inferences; this fixture does not identify Apple's rounding law,
internal numeric representation, oversampling, or exact transfer equation.

### Initialization and settling discovery

The first render after each state transition was not a valid steady-state result:

- The first bypass export differed only in samples 1–1023; from sample 1024 onward
  it matched the source. It is retained but excluded from the bypass claim.
- The first active export differed from the settled active PCM only in samples
  2–478. It is retained but excluded from the active transfer claim.

This changes the empirical protocol: a first native-effect render is diagnostic,
not automatically authoritative. A run must continue until at least three settled
decoded-PCM repeats agree, and it must retain any transition artifact rather than
silently delete it.

## Source and project preservation

The original fixture retained its suite-manifest file hash. Logic's project-local
copy has a different WAVE-container hash, as expected for an imported/copied asset,
but its decoded PCM remains exactly identical to the fixture after the run. The
project was saved with Bitcrusher active, closed, reopened, visually rechecked,
rendered, then later closed without saving the temporary bypass measurement state.
The retained `.logicx` archive therefore represents the verified active state.

## Production-intelligence consequence

“Bitcrush this” is not one deterministic production instruction. Logic exposes at
least four separable creative dimensions:

1. lower amplitude precision through Resolution;
2. sample-rate division and deliberate aliasing through Downsampling;
3. thresholded nonlinear remapping through Fold, Clip, or Wrap plus Drive and
   Clip Level;
4. parallel texture through Mix.

TrackSmith must interpret which dimension the musician actually wants, inspect the
source role and preservation constraints, and offer audibly distinct hypotheses.
For example, vocal intelligibility, bass pitch definition, drum transient shape,
and full-mix peak headroom are different risks. A louder, harsher, noisier, darker,
or more “vintage” result is not guaranteed by the word *bitcrush* or by any single
control. Previews must be level matched and listening remains decisive.

## Still open

- Fold and Wrap transfer behavior
- bounded Resolution, Drive, Clip Level, and Mix grids and their interactions
- Downsampling above 1x, alias spectra, and sample-rate dependence
- impulse-derived latency/tail/reset evidence
- mono/stereo and phase behavior
- automation transitions and bypass while transport is active
- musical fixtures across vocal, drums, bass, guitar, synth/keys, and full mix
- controlled listening and revision-language evaluation

The machine-readable authority is `run.json`; this narrative is a readable
interpretation of that record, not an independent evidence source.

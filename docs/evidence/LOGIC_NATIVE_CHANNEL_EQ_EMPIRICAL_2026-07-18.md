# Logic Pro 12.3 native Channel EQ empirical evidence — 2026-07-18

Status: **partial direct-host evidence**, not full Channel EQ characterization.

This run advances the common-effects lane ahead of Pedalboard and other
creative-specialty processors. It directly measures an unmodified Channel EQ
insertion, the plug-in-header bypass path, and one controlled bell state. The
immutable run record and retained artifacts are in:

`research/evaluation/logic-native-empirical-runs/logic-12.3-channel-eq-default-bell-2026-07-18/`

## Documentary starting point

The primary documentary source was Apple, *Logic Pro Effects for Mac*, current
Logic 12.3 publisher PDF retrieved 2026-07-15, SHA-256
`b317e4bd9b69238c85040723fa11f14eed7ac58d12ac64cb055fd2e8e342f819`.
The complete PDF was read previously; Channel EQ and shared equalizer behavior
were reviewed at pages 112–138. Apple documents eight bands, spectrum analysis,
output gain, HQ oversampling, and Stereo/Left/Right/Mid/Side processing. Those
documented controls define the campaign; they do not reveal Apple's private
filter implementation.

## Exact host boundary

| Item | Recorded value |
|---|---|
| Logic Pro | 12.3, build 6674 |
| Logic bundle | `com.apple.logic10` |
| Logic code-directory SHA-256 | `be60f7ec31ed955307f7021641d763c26ce4988e976aa8332f21bb9dc4fe8e8a` |
| Logic signer/team | Apple Mac OS Application Signing / `F3LWYJ7GM7` |
| macOS | 26.3, build 25D125 |
| Hardware | MacBookPro18,2, Apple M1 Max, 64 GB |
| Project rate | 48,000 Hz |
| Track | Mono, unity volume, centered, no volume/pan automation |
| Export | Regions as Audio Files, PCM24 WAVE, Normalize Off, no tail or volume/pan automation |

The project was disposable. The pre-existing Bitcrusher insert was retained but
bypassed. The saved processing state was Channel EQ active with Peak 3 at
`1000 Hz`, `+6.0 dB`, `Q 1.00`. The project was closed and archived before a
later temporary Channel EQ bypass measurement; that temporary bypass state was
discarded rather than saved.

## Fixture and source preservation

The source was TrackSmith's deterministic
`amplitude_ladder_1khz_mono.wav`: ten 0.8-second 1 kHz segments at peak levels
`-60, -48, -36, -30, -24, -18, -12, -6, -3, -1 dBFS`.

| Property | Value |
|---|---|
| Source file SHA-256 | `469045245bc4f67389e1c38cf4201308efbd2fbb24ad61767718ab63476f1410` |
| Source decoded-PCM SHA-256 | `bcb8df1858ceedca288cd9a207de9adc21fd370ff03891a970a051ee38949370` |
| Frames / duration | 384,000 / 8.0 seconds |
| Logic project-local copy | Container hash differs; decoded PCM is identical |

`artifacts/project-copy-analysis.json` is the direct comparison. The original
fixture was not modified.

## States measured

1. Unmodified Channel EQ `Default Preset`: enabled gain bands at 0 dB, Low Cut
   and High Cut off.
2. Channel EQ plug-in-header bypass.
3. Peak 3 enabled at 1000 Hz, +6.0 dB, Q 1.00; Analyzer POST, Q-Couple on, HQ
   off, output gain 0 dB.
4. State 3 after closing and reopening the saved Logic project.

This is one bell-band point, not a frequency, gain, Q, slope, mode, or sample-rate
grid.

## Results

### Default and bypass

Three settled unmodified-default exports and three settled header-bypass exports
were sample-identical to the fixture. Each state also repeated with identical
decoded PCM across its three retained renders.

The first export after initial insertion and the first export after changing to
bypass each differed only in samples 1–1023. Later samples matched the fixture,
and all three subsequent exports were exact. These transition files are retained,
but excluded from the settled transfer claims.

### Controlled 1 kHz bell

The analyzer now reports each amplitude-ladder segment separately so clipping
cannot make one whole-file regression coefficient masquerade as the configured
band gain.

| Input peak | Measured least-squares gain | Rendered peak | Clipped samples |
|---:|---:|---:|---:|
| -60 dBFS | +5.999997 dB | -53.9992 dBFS | 0 |
| -48 dBFS | +6.000007 dB | -41.9999 dBFS | 0 |
| -36 dBFS | +5.999999 dB | -30.0000 dBFS | 0 |
| -30 dBFS | +5.999999 dB | -24.0000 dBFS | 0 |
| -24 dBFS | +6.000001 dB | -18.0000 dBFS | 0 |
| -18 dBFS | +5.999999 dB | -12.0000 dBFS | 0 |
| -12 dBFS | +6.000000 dB | -6.0000 dBFS | 0 |
| -6 dBFS | +6.000000 dB | 0.0 dBFS | 1,400 |
| -3 dBFS | +4.275488 dB | approximately 0 dBFS | 15,400 |
| -1 dBFS | +2.596774 dB | approximately 0 dBFS | 21,000 |

The whole-file least-squares gain is only `+3.938985 dB` because the loudest
segments hit the PCM24 export ceiling. It is not evidence that the configured
bell supplies only 3.94 dB. Below clipping, the measured 1 kHz gain is
approximately +6 dB in every analyzed input-level segment.

Three settled bell renders have decoded-PCM SHA-256
`e569edfc3d1e4053b537b8095eea8acf2c399836369ce73889446503f3e0a96f`.
After save/reload, the UI again showed 1000 Hz, +6.0 dB, Q 1.00 and the new
render had that same decoded-PCM hash.

## Tooling consequence

`research/scripts/analyze-logic-native-render.py --amplitude-ladder` now adds a
steady, per-input-level transfer view with explicit edge exclusion, RMS, peak,
least-squares gain, correlation, and clipped-sample counts. This prevents
level-dependent processors and export clipping from being collapsed into a
misleading whole-file gain value. It remains an objective signal comparator,
not a perceptual-quality scorer.

## What this proves

- The settled unmodified default and settled header-bypass paths are transparent
  for this one 48 kHz mono fixture.
- The measured 1000 Hz/+6 dB/Q1 state applies approximately +6 dB at 1 kHz while
  the exported signal remains below full scale.
- The state is deterministic across three repeats and survives project
  save/reload for this run.
- Direct export headroom matters: a technically correct boost can clip even when
  the EQ transfer below the ceiling is linear.
- Initial and just-bypassed exports must be treated as transition diagnostics,
  not settled baselines.

## What this does not prove

- Apple's private filter topology, coefficients, or internal precision.
- Any other band, frequency, gain, Q, shelf/pass-filter slope, channel mode,
  output-gain or HQ state.
- Broadband magnitude, phase, group delay, impulse latency, analyzer switching,
  automation, stereo behavior, or other sample rates.
- That +6 dB at 1 kHz is desirable for any source.
- Perceptual superiority, “warmth,” “clarity,” or a universal production recipe.

Channel EQ therefore remains `partial`, not `complete`, in the 200-identity
Logic-native empirical campaign.

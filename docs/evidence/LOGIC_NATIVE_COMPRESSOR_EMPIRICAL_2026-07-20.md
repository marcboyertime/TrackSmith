# Logic Pro 12.3 native Compressor empirical evidence — 2026-07-20

Status: **partial direct-host evidence**, not full Compressor characterization.

This run advances TrackSmith's high-priority common-effects lane. It directly
measures the observed Logic Compressor default, plug-in-header bypass, and one
controlled static-curve state. The immutable run record, project archive, decoded-
PCM comparisons, and retained renders are in:

`research/evaluation/logic-native-empirical-runs/logic-12.3-compressor-default-controlled-2026-07-20/`

## Source-grounded starting point

Two full primary sources bound the interpretation:

- Apple, *Logic Pro Effects for Mac*, current Logic 12.3 publisher PDF retrieved
  2026-07-15, SHA-256
  `b317e4bd9b69238c85040723fa11f14eed7ac58d12ac64cb055fd2e8e342f819`;
  complete manual read, with Compressor and related side-chain behavior reviewed
  at pages 87-111. Apple establishes the exposed controls and seven model names;
  it does not publish their private coefficients or hardware equivalence.
- Giannoulis, Massberg, and Reiss, *Digital Dynamic Range Compressor Design—A
  Tutorial and Analysis*, JAES 60(6), 2012, pp. 399-408, lawful local payload
  SHA-256 `dd65e1f91e8fafd855cc994246bfe957d671254a271b83ba8fab2239f7b23b44`;
  full 10-page read. Equations (2) and (3) define ratio and the hard-knee static
  input/output relation. Sections 2.3-4 make clear that detector placement,
  Peak/RMS behavior, time smoothing, topology, and evaluation cannot be inferred
  from the static curve alone.

For input level `xG`, threshold `T`, and ratio `R`, the paper's hard-knee relation
above threshold is `yG = T + (xG - T) / R`. The corresponding static gain change
is `-(xG - T)(1 - 1/R)`. This equation is used only as a public-reference check
for the explicit controlled state below—not as a claim about Logic's internals.

## Exact host boundary

| Item | Recorded value |
|---|---|
| Logic Pro | 12.3, build 6674 |
| Logic bundle | `com.apple.logic10` |
| Logic code-directory CDHash | `be60f7ec31ed955307f7021641d763c26ce4988e` |
| Logic main executable SHA-256 | `ad6420a27e2d71878de8ed85326deafa3456ec11679decbe32b14703ec523bde` |
| Logic signer/team | Apple Mac OS Application Signing / `F3LWYJ7GM7` |
| macOS | 26.3, build 25D125 |
| Hardware | MacBookPro18,2, Apple M1 Max, 64 GB |
| Project rate | 48,000 Hz |
| Active track | Mono Audio 2, unity, centered, no sends/automation |
| Range | Cycle bars 1-5, exactly 8.000 seconds / 384,000 frames |
| Bounce | WAVE, PCM24, 48 kHz, split, Offline, Normalize Off, no tail |

The project was disposable and closed before archival. A bad earlier import was
left muted on Audio 1 and was not in the admitted signal path.

## Admission gate and rejected setup failures

The retained no-plug-in baseline is decoded-PCM identical to TrackSmith's source
fixture, and its split left and right files decode identically. The source fixture
remained unchanged:

| Property | Value |
|---|---|
| Source file SHA-256 | `469045245bc4f67389e1c38cf4201308efbd2fbb24ad61767718ab63476f1410` |
| Source decoded-PCM SHA-256 | `bcb8df1858ceedca288cd9a207de9adc21fd370ff03891a970a051ee38949370` |
| Frames / duration | 384,000 / 8.0 seconds |
| Baseline decoded PCM | Exact source match |
| Split L/R decoded PCM | Exact match |

Two earlier setup paths were rejected rather than massaged into evidence:

1. region exports made after a project-rate/import-range mistake had the wrong
   frame count;
2. cycle bounces made with Logic's metronome enabled contaminated the quiet
   ladder steps.

The valid lane set 48 kHz before re-import, disabled the metronome, used the exact
8-second cycle, and required source-exact baseline PCM. This changed the general
measurement protocol: render completion alone is no longer an admission test.

## States measured

### Observed Default Preset

`Threshold -20.0 dB`, `Ratio 2.1:1`, `Attack 15.0 ms`, `Release 51.0 ms`,
`Make Up 0.0 dB`, `Knee 0.7`, RMS, `Auto Gain -12 dB`, Distortion Off,
Platinum Digital, side-chain detection Max, limiter threshold 0 dB with limiter
off, Auto Release on, side-chain filter off, Mix 100%, input/output gain 0 dB.

### Controlled state

`Threshold -20.0 dB`, `Ratio 4.1:1`, `Attack 0.0 ms`, `Release 51.0 ms`,
`Make Up 0.0 dB`, `Knee 0.0`, Peak, Auto Gain Off, Distortion Off, Platinum
Digital, side-chain detection Max, limiter threshold 0 dB with limiter off, Auto
Release off, side-chain filter off, Mix 100%, input/output gain 0 dB.

The controlled state was visually reobserved after closing and reopening the
saved Logic project.

## Results

### Default is repeatable here, but it is not neutral

All three default renders have decoded-PCM SHA-256
`c03b9fbb80c24b3214529263c1262e5d661c06e0db84375fd4cbe1c36c31f25b`.
Peak was `-6.010533 dBFS`; whole-file RMS was `-15.949322 dBFS`.

| Input peak | Measured steady gain |
|---:|---:|
| -60 dBFS | +3.405461 dB |
| -48 dBFS | +3.405494 dB |
| -36 dBFS | +3.405460 dB |
| -30 dBFS | +3.405458 dB |
| -24 dBFS | +2.992610 dB |
| -18 dBFS | +1.182267 dB |
| -12 dBFS | -1.208592 dB |
| -6 dBFS | -3.885228 dB |
| -3 dBFS | -5.323219 dB |
| -1 dBFS | -6.294201 dB |

This is the observed default **including Auto Gain -12 dB**. The positive gain
below the compression region is not evidence of transparency and cannot support
a louder-is-better comparison.

### Header bypass is source-exact for this lane

Three header-bypass renders decode exactly to the source PCM hash
`bcb8df1858ceedca288cd9a207de9adc21fd370ff03891a970a051ee38949370`.
Each is 384,000 frames with peak `-0.9999997 dBFS`; selected split L/R pairs are
also decoded-PCM exact.

### Controlled static curve agrees with the exposed ratio relation

| Input peak | Measured steady gain | Eq. (3) expected gain | Absolute error |
|---:|---:|---:|---:|
| -60 dBFS | 0.000000 dB | 0.000000 dB | 0.000000 dB |
| -48 dBFS | 0.000000 dB | 0.000000 dB | 0.000000 dB |
| -36 dBFS | 0.000000 dB | 0.000000 dB | 0.000000 dB |
| -30 dBFS | 0.000000 dB | 0.000000 dB | 0.000000 dB |
| -24 dBFS | 0.000000 dB | 0.000000 dB | 0.000000 dB |
| -18 dBFS | -1.512067 dB | -1.512195 dB | 0.000128 dB |
| -12 dBFS | -6.048710 dB | -6.048780 dB | 0.000071 dB |
| -6 dBFS | -10.585293 dB | -10.585366 dB | 0.000073 dB |
| -3 dBFS | -12.853588 dB | -12.853659 dB | 0.000070 dB |
| -1 dBFS | -14.365784 dB | -14.365854 dB | 0.000069 dB |

No segment clipped. The maximum error against the public hard-knee relation was
`0.0001277 dB`. That is strong evidence for the tested steady static curve; it is
not evidence about timing, topology, internal precision, or the six untested
circuit models.

### Transition, repeatability, and save/reload

Controlled render 1 differed from render 2 in 979 samples, all at indices
1-1022—about 21.3 ms at 48 kHz. The remaining 382,977 samples matched. The cause
is not established; state initialization or prior processing history are plausible
inferences only.

Controlled renders 2 and 3 are decoded-PCM identical. After save/reload, the UI
showed the same controlled state and two new renders were each PCM-identical to
controlled render 2. Their stable decoded-PCM SHA-256 is
`cfa8b707bede1f82057b2fa0d199d1571a19ea7705c86b9f5f26db562380c269`.

WAVE file hashes differ across some identical-signal renders because container
metadata differs; decoded PCM is the signal identity criterion, while every file
hash remains in the artifact ledger.

## Direct product consequences

- TrackSmith must never use Logic Compressor's default as a transparent or fair
  bypass reference: Auto Gain is active in the observed default.
- Static curve, timing, detector, color, stereo-linking, and makeup decisions stay
  separate in production hypotheses. This run closes only part of the static lane.
- A material state change must produce a diagnostic first render plus settled
  repeats before deterministic claims are admitted.
- Common Compressor intent remains source-aware: vocal consistency, drum attack/
  sustain, bass note control, guitar pick preservation, synth-envelope integrity,
  and full-mix macro dynamics require different evidence and constraints.
- The native-effect knowledge may inform advice and future experiments, but the
  ordinary TrackSmith AU still has no authority to insert or control Logic's
  native Compressor.

## What this proves

- The exact baseline and header-bypass paths are sample-transparent for this one
  48 kHz mono fixture and split cycle-bounce path.
- The exact observed default and controlled states are repeatable after settling.
- The controlled steady hard-knee curve agrees closely with the exposed 4.1:1
  ratio law at every tested level.
- The saved controlled state and stabilized output survive project close/reopen.
- The source fixture remains unchanged.

## What this does not prove

- Attack/release/Auto Release, overshoot, pumping, recovery, look-ahead, detector
  windows, side-chain filters, or external side chain behavior.
- An isolated Peak-versus-RMS comparison or Max-versus-Sum stereo linking.
- The other six circuit models, distortion, limiter, dry/wet parallel behavior,
  harmonic color, aliasing, noise, latency, other sample rates, or stereo formats.
- That any state is musically preferable, “punchy,” “polished,” “warm,”
  “controlled,” or appropriate for a source.
- Apple's private implementation or hardware equivalence.

Compressor therefore moves from `not_run` to `partial`, not `complete`, in the
200-identity Logic-native empirical campaign.

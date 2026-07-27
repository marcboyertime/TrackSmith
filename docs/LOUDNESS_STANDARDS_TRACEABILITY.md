# Loudness standards traceability

Verified against the untouched official publisher payloads through 2026-07-27. This
document describes the implemented mono/stereo offline analysis only. It is not a
certificate from ITU, EBU, or an accredited laboratory.

Current verification snapshot: Debug, Release, and Thread Sanitizer `TestRunner`
all pass 68/68 when the 14 selected publisher-hosted BS.2217-2 WAVs are supplied;
the sanitizer emits no race report. No result below extends beyond its tested
files, channel layouts, rates, window definitions, or tolerances.

## Evidence status

| Behavior | Source/version | Exact source location | Implementation | Test evidence | Claim |
|---|---|---|---|---|---|
| K-weighting | ITU-R BS.1770-5 (11/2023) | Annex 1 sections 1-2, Figures 1-2, Tables 1-2 | `KWeighting`, `MeasurementBiquad` | 12 official BS.2217-2 frequency vectors at 25 Hz-10 kHz | Closest-available conformant for tested 48 kHz mono/stereo vectors |
| Integrated block formation | BS.1770-5 | Annex 1 section 3; equations (1)-(2) | 400 ms nearest-sample blocks, 100 ms hop, incomplete tail discarded | synthetic calibration and official vectors | Closest-available conformant for tested mono/stereo material |
| Integrated gates | BS.1770-5 | Annex 1 section 4; equations (3)-(7) | strict `> -70` absolute gate and strict `> absolute-gated - 10` relative gate | official absolute- and relative-gate files | Closest-available conformant for tested files |
| EBU Momentary maximum | EBU Tech 3341 v4 (11/2023) | section 2.2 item 1 | ungated rectangular 400 ms blocks | 997 Hz synthetic calibration | Approximately conformant; EBU audio set not acquired |
| Short-term Loudness | EBU Tech 3341 v4 | section 2.2 item 2 | ungated rectangular 3 s windows, 100 ms hop | constant-tone calibration and exact window-count assertion | Approximately conformant; EBU audio set not acquired |
| LRA | EBU Tech 3342 v4 (11/2023) | section 3.1; section 5 reference implementation | 3 s/10 Hz vector; inclusive -70 LUFS gate; power mean; -20 LU relative gate; inclusive comparison; reference percentile indices; 1.5 s virtual trailing silence | synthetic minimum cases 1-4 pass within ±1 LU | Approximately conformant; official EBU WAV payload was unavailable |
| 48 kHz true peak | BS.1770-5 | Annex 2 sections 2-3, Tables 2-3 | four-phase, 48-tap FIR plus sample peak | synthetic inter-sample cases | Experimental/partial; full official true-peak suite not run |
| non-48 kHz true peak | BS.1770-5 | Annex 2 section 3 guidance | bounded windowed-sinc phase grid reaching at least 192 kHz and at least 2x | synthetic 44.1/88.2/96/192 kHz cases | Experimental approximation, not claimed conformant |

## Exact implementation interpretations

### Integrated Loudness

For each 400 ms block `j`, TrackSmith computes the mean-square output of the two
K-weighting stages for each supported channel and applies unit channel weights for
mono, left, and right. Loudness is:

```text
l_j = -0.691 + 10 log10(sum_i G_i z_ij)
```

The first pass keeps blocks with `l_j > -70`. The power mean of those blocks
defines the absolute-gated loudness. The second pass keeps blocks strictly above
both -70 and that value minus 10 LU. The final power mean is Integrated Loudness.

Deviation boundary: advanced-layout weights, LFE exclusion by channel label, and
rendering metadata are not implemented because TrackSmith currently accepts only
mono/stereo `AudioBuffer` analysis. It must not be used as an immersive-layout
conformance meter.

### EBU Short-term Loudness

TrackSmith uses a rectangular 3.000 s window and 0.100 s hop over the same
K-weighted channel-summed energy. It is ungated. The published timeline timestamps
are window starts. A maximum is available only when at least one complete 3 s
window exists.

This definition is EBU Mode. ITU-R BS.1771-1's Momentary IIR ballistics differ
from EBU's rectangular 400 ms Momentary definition; TrackSmith does not claim that
the two are interchangeable.

### Loudness Range

The input is the 10 Hz Short-term series. File-based measurement includes 1.5 s
of virtual trailing silence as required by the Tech 3342 reference-code note.
TrackSmith translates the reference percentile exactly:

```text
zero_based_index = round((n - 1) * percent / 100 + 1) - 1
LRA = percentile_95 - percentile_10
```

LRA has unit LU, not LUFS. Values for 3-60 s material are returned with
`unstableBelowSixtySeconds`; less than 3 s is unavailable. Even at 60 s or longer,
LRA is a descriptor rather than a quality or compression verdict.

## Test-vector provenance

Official report: ITU-R BS.2217-2 (11/2016), SHA-256
`0ae77dc00c1528198ab6acf61620b70f82c5f3c521f8a6918bb3a24281f98376`.
Official attachment index: <https://www.itu.int/oth/R1102000001/en>.

The conformance test uses the publisher-hosted WAV payloads only from a temporary
external directory selected with `TRACKSMITH_BS2217_VECTORS`; the WAVs are not
redistributed in this repository. Covered files:

- 23 LKFS and 24 LKFS stereo tones at 25, 100, 500, 1,000, 2,000, and 10,000 Hz;
- `1770-2_Comp_AbsGateTest.wav` at -69.5 LKFS;
- `1770-2_Comp_RelGateTest.wav` at -10.0 LKFS.

All fourteen passed at ±0.1 LKFS on 2026-07-14. The synthetic Tech 3342 cases use
the exact published segment descriptions: 10, 5, 20, and 15 LU, each checked at
the document's ±1 LU tolerance.

The first attempted full-suite invocation on 2026-07-14 pointed the environment
variable at the parent archive directory and failed solely because the expected
WAV was under `extracted/`. The corrected invocation used that payload directory,
ran all fourteen files, and exited with 55 passes and zero failures. The failed
path lookup is not represented as an algorithm or conformance failure.

The canonical EBU Loudness Test Set v5 page is
<https://tech.ebu.ch/publications/ebu_loudness_test_set>. Its ZIP returned HTTP
403 to direct retrieval in this environment. No claim is made that TrackSmith ran
that copyrighted payload.

## Reproduction

After lawfully acquiring and extracting the selected BS.2217 attachments:

```sh
TRACKSMITH_BS2217_VECTORS=/absolute/path/to/extracted-vectors \
  swift run -c release TestRunner
```

The ordinary test suite still runs the synthetic standards checks when the
environment variable is absent.

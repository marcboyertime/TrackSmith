# MVP vertical-slice evidence — 2026-07-13

## Verdict and boundary

The offline public-package vertical slice passed **18/18 assertions** on a real,
user-owned vocal recording. It produced three valid, level-matched and measurably
different previews; reproduced selected and revised auditions from their serialized
graphs; preserved a locked EQ and every unmentioned production node during “use less
compression”; exercised typed undo/redo; returned decoded source samples exactly
through the dry graph; and left the external source file unchanged.

This is not a perceptual claim that every option sounds better. It is also not a
Logic-host proof. The evidence file explicitly records:

```json
{
  "executionMode": "offline public package APIs",
  "liveAudioUnitCommitProven": false
}
```

`AudioUnitHostProbe` separately exercises the production AU class and companion
protocol. Direct current-build Logic validation is recorded only after a fresh
signed install and disposable-project test; no such result is inferred here.

## Reproduce with another legally owned WAV

From the repository root, choose an output directory that does not exist:

```sh
swift run -c release VerticalSliceCLI \
  "/absolute/path/to/vocal.wav" \
  --source vocal \
  --prompt "make this clearer, warmer, and more controlled" \
  --revision "use less compression" \
  --output "/absolute/path/to/new-proof-directory"
```

The tool opens the external source read-only, hashes it before and after, stages new
artifacts, and refuses an existing output directory. Inspect:

```sh
jq '{overallPassed, checks, integration}' \
  "/absolute/path/to/new-proof-directory/evidence.json"
shasum -a 256 "/absolute/path/to/new-proof-directory/evidence.json"
```

Results depend on the source content and current deterministic recipe version. A
different recording can legitimately reject a candidate whose peak or pairwise-
difference guardrail fails; three labels alone are not evidence of three useful
options.

## Recorded source identity

No source path, filename, audio payload, transcript, project name, or rendered WAV
is committed. The local ignored proof directory was
`tmp/mvp-proof/vertical-slice-20260713-006/`; its `evidence.json` SHA-256 is
`03213a439673d39aca98d6bc21953633b86a0154d55f44ec5bfcb7eafd189339`.

| Property | Recorded value |
|---|---:|
| Source format | WAV, mono, signed 16-bit PCM |
| Sample rate | 44,100 Hz |
| Frames | 482,550 |
| Duration | 10.942176871 s |
| Source SHA-256 before | `34a9ed753c2a403c0ccb2ff87c6d6f6f08ace0e8fc778084cb8135200615fd7d` |
| Source SHA-256 after | `34a9ed753c2a403c0ccb2ff87c6d6f6f08ace0e8fc778084cb8135200615fd7d` |
| Source integrated loudness | -25.390337954 LUFS |
| Source sample peak | -8.719585114 dBFS |
| Source approximate true peak | -8.719585114 dBTP |
| Source clipping count | 0 samples |

Matching before/after hashes prove that this run did not modify the file. They do
not prove ownership, recording quality, or absence of unrelated filesystem changes.

## Preview results

The `loudnessMatchGainDB` below is materialized as a node in the saved plan, so a
fresh graph render is the audition rather than a louder hidden post-process. The
true-peak column is the project's sample-rate-aware estimate, not the real-time
limiter: the limiter is zero-lookahead sample peak only.

| Variant | Match gain | Integrated loudness | Approx. true peak | Clipped samples | Difference RMS from source | Difference RMS from previous audition |
|---|---:|---:|---:|---:|---:|---:|
| Conservative | +0.177522 dB | -25.390338077 LUFS | -9.024564 dBTP | 0 | -28.710764 dBFS | -28.710764 dBFS |
| Balanced | +1.222999 dB | -25.390337977 LUFS | -8.996660 dBTP | 0 | -27.552583 dBFS | -40.577714 dBFS |
| Strong | +5.147161 dB | -25.390479854 LUFS | -8.528785 dBTP | 0 | -25.739489 dBFS | -36.380359 dBFS |

All three statuses were `valid`. The loudness spread is approximately 0.000142 LU,
while every pair of accepted auditions remained above the configured collapse
threshold. Objective difference proves nonidentity, not subjective usefulness.

Artifact identity also proved exact selection:

- Balanced audition and balanced applied WAV:
  `c9142a8ae35a6b96099399687aef26dd08d21b56e22fc4130c6c9abdad8722c6`.
- Balanced saved plan:
  `9792f2d9d9d058f8121a1f8c8fb2a0272ccfb107b538719f2fd84bc5e064b804`.
- Two fresh balanced renders were sample-identical.

## Targeted revision and state proof

The balanced 320 Hz EQ was explicitly locked. For the request `use less
compression`, the engine changed the compressor ratio from **2.7660:1 to 2.0596:1**
and raised its threshold from **-22.0843 dBFS to -19.0843 dBFS**. The locked EQ was
byte-equivalent, and all non-compressor production nodes remained equivalent. The
unlocked, dependent loudness-match node was correctly recalculated from +1.222999 dB
to +0.230660 dB.

The revised audition and applied WAV share SHA-256
`cef6b21041284173946f4ee54473503f6883ad4c5e72e3aed3618be1af480014`;
two fresh revised renders were sample-identical. Revised measurements were
-25.390338447 LUFS, -8.977839 dBTP approximate true peak, and zero clipped samples.

The in-process snapshot tree then proved:

1. Undo revision reproduced Balanced exactly.
2. Undo again reproduced decoded source samples exactly.
3. Redo reproduced Balanced exactly.
4. Redo again reproduced the revised audio exactly.

The dry output is a new Float32 WAV container, so its file hash is not expected to
equal the original Int16 source hash. Decoded samples were exactly equal. The proof
bundle contains 25 manifested plan/analysis/audio artifacts, each with a size and
SHA-256; `evidence.json` is the 26th file and its hash is recorded above.

## Automated core and AU-class evidence

The corresponding clean-build commands are:

```sh
swift build --scratch-path /tmp/laa-clean-debug
swift run --scratch-path /tmp/laa-clean-debug TestRunner
swift run --scratch-path /tmp/laa-clean-debug AudioUnitHostProbe

swift build -c release --scratch-path /tmp/laa-clean-release
swift run -c release --scratch-path /tmp/laa-clean-release TestRunner
swift run -c release --scratch-path /tmp/laa-clean-release AudioUnitHostProbe
```

Recorded current-revision results:

- Debug and Release `TestRunner` runs passed **42/42**.
- Debug and Release `AudioUnitHostProbe` runs exited successfully.
- The Release host probe measured 9.1 us mean, 9.7 us p99, and 49.4 us maximum
  for the representative 128-frame/48 kHz callback against a 2,666.7 us deadline.
- Thread Sanitizer runs of both `TestRunner` and `AudioUnitHostProbe` exited
  successfully with no report emitted.

The host probe covers the production `AssistantAudioUnit`, capture-bound canonical
commit, locks/revision/undo/redo, AU/offline parity, `fullState` graph and global-
bypass persistence, companion reconnect, two-instance isolation, corrupt-state dry
recovery, publication reset/exhaustion, nonfinite-input sanitation, concurrent reset
stress, snapshot/graph/runtime-format compare-and-swap rejection, and lost-
acknowledgement reconciliation. Thread Sanitizer and timing results cover only
exercised custom-host paths.

## Honest limitations

- The prompt/revision parser is deterministic and keyword-based. It is not general
  conversational understanding, and no production local/cloud LLM adapter is wired.
- The offline snapshot proof is in-process only. Companion undo/redo history is not
  persisted across app restart. The custom AU host separately proves `fullState`
  restoration of the committed graph and global-bypass flag; this is not direct
  Logic project save/reload evidence.
- The approximate true-peak meter uses the BS.1770 Annex 2 FIR at 48 kHz and a
  bounded windowed-sinc estimate at other rates; it is not formally conformance-
  certified. The real-time limiter is zero-lookahead sample peak, not true peak.
- Callback source review finds no explicit allocation, blocking lock, file/network/
  database/log/UI work, or unbounded loop. Swift ARC and platform math routines have
  not been measured with an allocation interposer inside Logic.
- Objective peak, loudness, spectral and dynamic metrics catch errors and describe
  changes. They cannot establish that a result is artistically better.
- The real fixture is intentionally not redistributable. A generated fixture remains
  available for repository tests, but it is not evidence of production quality on a
  human performance.
- Research archive integrity and indexing are complete, but review depth is 20
  Core/full-text, 33 Supporting, and 8 Peripheral among 61 unique PDFs. The remaining
  41 are not claimed as Core-depth full-text reviews.

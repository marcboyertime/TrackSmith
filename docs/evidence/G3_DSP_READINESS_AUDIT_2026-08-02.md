# G3 deterministic DSP readiness audit — 2026-08-02

## Verdict

**G3 remains pending.** This record is a readiness audit, not a promotion, and does
not modify the authoritative milestone ledger. The selected TrackSmith-owned modules
remain the version-1 expander/gate, fixed-time feedback delay, and bounded
algorithmic-room reverb. They are not Logic processor clones, and no result here
claims installed Logic behavior or perceptual success.

The audit was run from source revision
`53376bca425eadb7d99a60982aeb68d4199ee6a3` in a pre-existing dirty worktree. The
unrelated Logic-native measurement changes were preserved. Provenance class:
`tracksmith_measurement`.

## Selection boundary

`research/evaluation/production-mastery-v1/failure-map.json` selects exactly
`tracksmith_dsp:reverb`, `tracksmith_dsp:delay`, and
`tracksmith_dsp:expander_gate` for implementation. Its ranking records 17 meaningful
delay cases, 16 reverb cases, and 6 expander/gate cases; it explicitly defers dynamic
EQ and transient shaping until the selected modules satisfy their deterministic,
state, host, heap, and perceptual fixture gates.

## G3 requirement map

| Required gate | Evidence observed in this audit | Status |
| --- | --- | --- |
| Typed, bounded, versioned parameters and strict validation | `PlanValidator.ranges`, `allowedParameters`, `requiredParameters`, and per-node resource caps in `packages/PlanSchema/Sources/PlanSchema/PlanValidator.swift`; fresh `TestRunner` check `production-mastery nodes require explicit bounded algorithm versions` | Covered in source and fresh Release test |
| Deterministic offline rendering and borrowed-buffer AU path | `CompiledGraph.process` and `processRealtime`; fresh G3 node checks plus `realtime pointer DSP matches offline graph across host blocks` | Covered in source and fresh Release test |
| Offline/realtime parity across irregular blocks | The fresh 73-check Release harness passed the pointer-parity check using 32, 64, 127, 256, 511, and 1,024-frame blocks with the expander, delay, and reverb in the same graph | Passed for the exercised custom-host graph |
| State round-trip/migration, reset, bypass, nonfinite, rate, and layout tests | Fresh Release harness passed Codable round-trip and direct legacy parameter-array fixtures for the promoted reverb, delay, and expander/gate nodes, along with disabled-node bypass, G3 reset, nonfinite recovery, supported-rate, and layout-fail-closed checks. Current Release `AudioUnitHostProbe` also passed the state path. | Passed for the exercised current-source custom-host paths; installed-Logic recovery remains a separate G6 gate |
| Explicit transition/smoothing behavior | Documented in `docs/DSP_DESIGN.md`; AU transition/reset/bypass checks are in the host probe source. Current Release `AudioUnitHostProbe` passed, and the current-source TSan AudioUnitHostProbe executable also exited 0 with no sanitizer diagnostic. | Passed for the exercised current-source custom-host/TSan paths |
| Bounded CPU/memory and allocation-free callback | Current `make native-verify` passed the heap lane with `RT_HEAP callback iterations=4000 operations=0`; the exercised callback reported p99 about 14.6 us. | Passed for the exercised current-source custom-host/heap lane |
| Source-preserving preview/commit, exact rollback, fail-closed unsupported plans | Fresh harness passed `targeted revision preserves locks and unrelated nodes`, `adversarial planner prompts fail closed`, and `audible preview export preserves input and reloads outputs`. This is portable workflow evidence, not installed Logic proof. | Passed for exercised portable workflow |
| Unit, integration, adversarial, state, host, heap, and listening fixtures | Fresh Release tests cover unit/adversarial/state/portable-workflow paths (`TestRunner` 72/72 and vector run 73/73). Current-source Release and TSan `AudioUnitHostProbe` executions passed, and the heap probe recorded `RT_HEAP callback iterations=4000 operations=0`. `research/evaluation/production-mastery-v1/dsp-listening-fixtures/manifest.json` lists six G3 fixtures (two per module); no human listening outcome is recorded. | Partial: fresh level-matched formative listening remains for G3 |

## Fresh command evidence

| Command | Result |
| --- | --- |
| `swift build -c release` | Exit 0; `Build complete! (31.53s)`. |
| `swift run -c release TestRunner` | Exit 0; `SUMMARY passed=72 failed=0`. |
| `TRACKSMITH_BS2217_VECTORS="$PWD/tmp/standards-vectors/itu-bs2217/extracted" swift run -c release TestRunner` | Exit 0; local vector directory contained 14 WAVs; `SUMMARY passed=73 failed=0`. This includes the three G3-node checks and irregular-block parity. |
| `swift build -c release --sanitize=thread --product TestRunner` followed by the direct sanitized binary with `TRACKSMITH_BS2217_VECTORS="$PWD/tmp/standards-vectors/itu-bs2217/extracted"` | Build exited 0; direct binary exited 0 with `SUMMARY passed=73 failed=0` and no sanitizer report. |
| `make native-verify` | Exit 0; Xcode Debug build succeeded, AudioUnitHostProbe passed, and `RT_HEAP callback iterations=4000 operations=0` with exercised callback p99 about 14.6 us. |
| `swift run -c release AudioUnitHostProbe` | Exit 0; current Release AudioUnitHostProbe passed with callback p99 about 17.7 us. |
| `swift build -c release --sanitize=thread --product AudioUnitHostProbe` followed by `./.build/arm64-apple-macosx/release/AudioUnitHostProbe` | Build exited 0 (`Build of product 'AudioUnitHostProbe' complete! (30.17s)`). The direct current-source executable exited 0 and printed `PERF callback frames=128 rate=48000 mean=474.1 us p99=569.7 us max=613.6 us deadline=2666.7 us` followed by `PASS Audio Unit rendered, captured, previewed, committed, and reverted`. No sanitizer diagnostic was emitted. |
| `./scripts/run-realtime-heap-probe.sh` | Exit 0; current Release probe reported `RT_HEAP callback iterations=4000 operations=0`, p99 about 15.4 us, and the host probe pass. |
| `git diff --check -- docs/evidence research/evaluation/production-mastery-v1 packages/DSPCore packages/PlanSchema plugins/AudioUnit tools/AudioUnitHostProbe tools/RealtimeHeapProbe tests/TestRunner Package.swift Makefile` | Exit 0 before this record was added; no pre-existing delta in the owned implementation/test surface. |

## Open gates preventing promotion

1. **G3-specific remaining gate — fresh level-matched human listening.** Run the six
   G3 fixtures (two per selected module) under the blinded formative protocol. Any
   resulting record is `SINGLE_LISTENER_FORMATIVE_EVIDENCE` only; these stimuli are
   not human results, and no participant, preference, or perceptual-success claim is
   recorded here.
2. **Separate G6 cross-milestone dependency — installed host and recovery.** Obtain
   the required direct Logic installed-host/recovery evidence separately. The
   current-source `AudioUnitHostProbe`, heap, and TSan results above are custom-host
   proof; `auval` and installed-Logic workflow results belong to G6 and must not be
   presented as G3 custom-host or perceptual evidence.

## Scope check

Only this readiness record was added by the audit. A concurrent modification to
`research/evaluation/production-mastery-v1/ledger.json` is outside this worker's
ownership and was not touched. No DSP, AU, package, bundle, G2-profile, or
historical-evidence artifact was modified by this audit.

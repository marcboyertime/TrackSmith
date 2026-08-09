# TrackSmith Vocal v1 — automated verification

**Date:** 2026-08-08
**Evidence class:** development-only automated verification
**Milestone status:** in progress

This record adds post-baseline automated observations without changing the frozen
pre-Vocal baseline at
[`TRACKSMITH_VOCAL_V1_BASELINE_2026-08-08.md`](TRACKSMITH_VOCAL_V1_BASELINE_2026-08-08.md).
It establishes bounded test, build, custom-host, installed-AU, and contract
behavior only. It does not establish a clean source-bound final regression,
direct Logic validation, a real-vocal owner session, owner listening, or release
completion. Exact signed-install evidence is recorded separately in
[`TRACKSMITH_VOCAL_V1_SIGNED_INSTALL_2026-08-08.md`](TRACKSMITH_VOCAL_V1_SIGNED_INSTALL_2026-08-08.md).

## Observed automated results

| Lane | Observed result | Precise evidence path(s) |
|---|---|---|
| Portable Debug `TestRunner` | **PASS 104/104** after the Guide-to-Create handoff regression was added. | `tests/TestRunner/main.swift`; isolated `.build/final-vocal-debug` run; this record |
| Portable Release `TestRunner` | **PASS 104/104** after the Guide-to-Create handoff regression was added. The repository-wide `make verify` reproduced the same 104/104 result. | `tests/TestRunner/main.swift`; `Makefile` (`test`); this record |
| Portable Release / Thread Sanitizer `TestRunner` | **PASS 105/105** after the handoff regression, with the optional BS.2217-2 vector lane enabled and no Thread Sanitizer race report. | `tests/TestRunner/main.swift`; `Makefile` (`test`); this record |
| Release custom host probe | **PASS** — mean **14.7 us**, p99 **16.9 us**, maximum **46.0 us**, deadline **2666.7 us**. | `tools/AudioUnitHostProbe/Sources/AudioUnitHostProbe/main.swift`; `Makefile` (`au-host-probe`) |
| Render-thread heap interposer | **PASS** — 4,000 callbacks, **0 observed heap operations**, mean **14.8 us**, p99 **16.8 us**, maximum **57.8 us**. | `tools/RealtimeHeapProbe/RealtimeHeapInterposer.c`; `Makefile` (`realtime-heap-probe`) |
| Thread Sanitizer custom host probe | **PASS** — mean **550.1 us**, p99 **611.0 us**, maximum **680.4 us**, deadline **2666.7 us**, with no Thread Sanitizer race report. | `tools/AudioUnitHostProbe/Sources/AudioUnitHostProbe/main.swift`; `Makefile` (`au-host-probe`) |
| Vocal semantic evaluator | **PASS 89/89** on TrackSmith-owned synthetic vocal-like fixtures, including negated-goal and live desired/prohibited-collision coverage. Its first combined-tree report records baseline revision `406b446994fae53880d46e3d57ad4c3843d57340` with source-tree state `dirty`; this row is updated again by the clean source-bound run. | `research/evaluation/tracksmith-vocal-v1/offline-evaluation-report-2026-08-08.json`; `research/evaluation/TRACKSMITH_VOCAL_SEMANTIC_CORPUS_V1.json`; `research/evaluation/tracksmith-vocal-v1/failure-map.json`; `tools/VocalProductionEvaluation/Sources/VocalProductionEvaluation/main.swift` |
| Vocal listening CLI contract self-check | **PASS**. The self-check validates local blinded-study JSON handling and tamper/overwrite refusal; it creates no audio and no listening judgment. | `tools/VocalListeningStudyCLI/Sources/VocalListeningStudyCLI/main.swift`; `packages/VocalEvaluation/Sources/VocalEvaluation/VocalBlindedEvaluation.swift`; `Makefile` (`vocal-listening-selfcheck`) |
| Tutor regression corpus | `ProductionTutorEvaluation` **PASS 77/77**. | `research/evaluation/TRACKSMITH_TUTOR_INTENT_CORPUS_V1.json`; `tools/ProductionTutorEvaluation/Sources/ProductionTutorEvaluation/main.swift`; `Makefile` (`tutor-evaluation`) |
| General Tutor regression corpus | `GeneralTutorEvaluation` **PASS 518/518**. | `research/evaluation/TRACKSMITH_GENERAL_TUTOR_CORPUS_V1.json`; `tools/GeneralTutorEvaluation/Sources/GeneralTutorEvaluation/main.swift`; `Makefile` (`general-tutor-evaluation`) |
| Native development build | **PASS** — XcodeGen generation plus a clean unsigned Debug arm64 `CompanionMacApp` build. | `project.yml`; `LogicAudioAssistant.xcodeproj/project.pbxproj`; `Makefile` (`native-build`) |
| Signed installed Release app and AU | **PASS** — arm64 app and AU, Apple Development Team ID `KDV9RC892F`, matching App Group entitlements, strict deep signature verification, byte-identical signed-build/installed executables, exactly one registered installed extension, and full out-of-process `auval` success. | `docs/evidence/TRACKSMITH_VOCAL_V1_SIGNED_INSTALL_2026-08-08.md`; `scripts/install-development-build.sh` |
| Installed App Group publication | **PASS, bounded** — the installed out-of-process AU published valid schema `1.0`/plug-in `1.0.0` heartbeat records as mode `0600` files in the exact signed App Group. Full mutation/capture IPC remains exercised by `AudioUnitHostProbe`; this is not a fresh installed-companion launch or direct Logic claim. | `docs/evidence/TRACKSMITH_VOCAL_V1_SIGNED_INSTALL_2026-08-08.md`; `packages/SharedIPC/Sources/SharedIPC/AppGroupContainer.swift`; `tools/AudioUnitHostProbe/Sources/AudioUnitHostProbe/main.swift` |

The host-probe and heap measurements are development-Mac, custom-host guardrails,
not a claim about every host configuration. The synthetic semantic evaluator
proves bounded local contracts and execution risks only; its own report excludes
claims of vocal quality, naturalness, intelligibility, transformation relevance,
or preference.

## Gate interpretation

| Gate state | Interpretation |
|---|---|
| V0 — passed | The frozen baseline and current-truth boundary are recorded without rewriting the baseline. |
| V1-V5 — in progress | The source, contract, and automated evidence paths above support ongoing implementation; none is promoted to a completed Vocal capability or listening claim. |
| V6 — in progress | The current portable/native/realtime checks are encouraging development evidence. A final regression reproduced from a clean, source-bound revision is still required before V6 can pass. |
| V7 — passed | The signed installed app/AU identity, entitlements, registration, out-of-process `auval`, and bounded installed App Group publication are recorded in the signed-install evidence. |
| V8-V9 — pending | No direct Logic proof, real-vocal owner listening evidence, or release reconciliation is claimed here. |

## Explicit non-claims

- No owner has performed a real-vocal listening study, so no
  `SINGLE_LISTENER_FORMATIVE_EVIDENCE` result exists.
- No direct Logic workflow has been exercised for this Vocal v1 change set.
- The signed installed artifact is a local Apple Development build, not a
  notarized distribution or release artifact.
- Passing a custom host probe, heap probe, sanitizer run, synthetic fixture, or
  JSON self-check does not establish artistic usefulness, perceptual quality,
  intelligibility, naturalness, or user preference.

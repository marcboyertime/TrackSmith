# TrackSmith Vocal v1 — frozen baseline

**Date:** 2026-08-08
**Frozen commit:** `406b446` (`Merge completed open-source repository audit`)
**Branch used for the change:** `codex/tracksmith-vocal-v1`
**Evidence class:** objective build, test, binary-identity, and host-probe evidence only

This record freezes the repository and installed-product state before TrackSmith
Vocal v1 source changes. It does not claim a Vocal workflow, a successful Logic
session, or a listening preference.

## Portable and native baseline

| Lane | Command or artifact | Result |
|---|---|---|
| Complete portable verification | `make verify` | Passed. Knowledge generation/audits were current, Release built, `TestRunner` passed 91/91, and `AudioUnitHostProbe` passed. |
| Portable Debug | isolated Debug scratch build, then `TestRunner` | Passed 91/91. |
| Native unsigned Debug | `make native-verify` | Passed. XcodeGen and the native app/AU build succeeded; host probe and heap probe succeeded. |
| Render-thread heap interposer | `make realtime-heap-probe` through `native-verify` | Zero observed heap operations across 4,000 callbacks. |
| Thread Sanitizer, complete test runner | isolated Release/TSan scratch build with the 14 local BS.2217-2 vectors | Passed 92/92 with no Thread Sanitizer report. The extra check is the optional official-vector lane. |
| Thread Sanitizer, host probe | isolated Release/TSan `AudioUnitHostProbe` | Passed with no Thread Sanitizer report. |
| Tutor v1 corpus | frozen Release `ProductionTutorEvaluation` binary | 77/77 passed. |
| General Tutor v2 corpus | frozen Release `GeneralTutorEvaluation` binary | 518/518 passed; retrieval 10/10, 10 conversations, 58 ordered multi-turn turns, 99 domains, and all 9 question kinds. |

The ordinary Release host probe measured approximately 13.2 microseconds mean,
16.3 microseconds p99, and 37 microseconds maximum against a 2,666.7 microsecond
callback deadline. The native-verification host probe measured approximately
13.4 microseconds mean, 15.8 microseconds p99, and 57.8 microseconds maximum.
The instrumented TSan probe measured approximately 469.8 microseconds mean,
532.8 microseconds p99, and 1,002.7 microseconds maximum. These are machine- and
build-specific guardrails, not promises for every host configuration.

## Installed artifact snapshot

The already-installed development product at
`/Users/marcboyer/Applications/Logic Audio Assistant.app` passed strict
`codesign` verification and was signed by Team ID `KDV9RC892F`.

| Installed component | CDHash |
|---|---|
| Companion application | `10e46a116751056e25c65f707142e86433e58fcc` |
| Embedded Audio Unit extension | `cb7756f8907de21391b847710e362c20fb0eda44` |

Two Audio Unit registrations were visible: the installed Release extension and
a stale DerivedData Debug copy. Final Vocal validation must remove or supersede
that stale registration and prove that `auval` and Logic load the newly installed
signed identity, rather than relying on the registration order.

Environment identities observed for the freeze were macOS 26.3, Swift 6.3.3,
Xcode 26.6, XcodeGen 2.45.4, and `auval` 1.10.

## Explicit proof boundary

Logic Pro was not running for this baseline freeze. No owner listening was
performed. Therefore this record proves only that the pre-Vocal architecture was
green and that an older signed build was present. It does not satisfy the Vocal
v1 direct-Logic, save/reload, provider-offline playback, imaginative-transform,
or `SINGLE_LISTENER_FORMATIVE_EVIDENCE` gates.

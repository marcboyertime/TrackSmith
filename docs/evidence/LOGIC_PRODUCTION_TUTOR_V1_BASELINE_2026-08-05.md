# Logic Production Tutor v1 — frozen baseline (2026-08-05)

This record freezes the verified state of the repository immediately before
Tutor v1 feature work began. Every command below was actually executed on this
machine on 2026-08-05; nothing here is inferred from older evidence documents.

## Source identity

- Starting HEAD: `c87cea59fc15b4876d7c00176de15ee32d1a2fc6`
  (`chore: push all latest TrackSmith updates and evidence`, tip of `main`)
- Worktree before feature work: clean (`git status --short` empty)
- Feature branch created from that HEAD: `codex/logic-production-tutor-v1`
- Pre-existing repository anomaly retained untouched: `.git/refs/.DS_Store`
  (`git fsck` invalid ref name; recorded previously in the Production Mastery
  ledger's `knownAnomalies`).

## Environment

- macOS 26.3 (build 25D125), Apple Silicon (arm64)
- Apple Swift 6.3.3 (swiftlang-6.3.3.1.3), target arm64-apple-macosx26.0
- Xcode 26.6 (build 17F113)
- Logic Pro is installed on this machine but was NOT operated during this
  baseline; no Logic-hosted claim is made here.

## Commands executed and results

| Command | Result |
|---|---|
| `swift build` | Build complete, no errors |
| `swift build -c release` | Build complete, no errors |
| `swift run TestRunner` (Debug) | `SUMMARY passed=72 failed=0` |
| `swift run -c release TestRunner` | `SUMMARY passed=72 failed=0` |
| `make project` (`xcodegen generate`) | Project regenerated; no tracked-file diff |
| `make production-language-knowledge-check` | `PRODUCTION_LANGUAGE_GENERATED_CHECK_OK entries=14` |
| `swift run -c release AudioUnitHostProbe` | PASS; `PERF callback frames=128 rate=48000 mean=13.9 us p99=38.8 us max=291.6 us deadline=2666.7 us` |
| `make native-build` (Xcode Debug, `CODE_SIGNING_ALLOWED=NO`) | `** BUILD SUCCEEDED **` |
| `make realtime-heap-probe` | PASS; `PERF … mean=13.1 us p99=14.2 us max=41.2 us deadline=2666.7 us`; `RT_HEAP callback iterations=4000 operations=0` |

`TRACKSMITH_BS2217_VECTORS` was not set for these runs, so the optional
official-vector lane did not execute; the 72 unconditional checks all passed in
both configurations.

## Not run in this baseline

- Thread Sanitizer lanes (not re-run for this baseline; the most recent
  recorded TSan status is in the Production Mastery documentation and is not
  re-attributed to this HEAD).
- `make native-install` and any signed-install/`auval`/Logic-hosted lane. No
  Logic host interaction occurred.
- The optional BS.2217-2 official-vector lane (environment variable not set).

## Pre-existing warnings

- No compiler errors. Build output showed no new warnings in the summarized
  tails; a warning-by-warning audit of full build logs was not performed and is
  not claimed.

## Milestone bookkeeping at baseline

- Production Mastery ledger (`research/evaluation/production-mastery-v1/ledger.json`):
  G0 passed, G1 passed, G1.5 passed, G2 passed, G3 pending, G4 passed,
  G5 pending, G6 in_progress, G7 pending. This baseline changes none of them.
- Production Intelligence v1 remains frozen with its closure record intact.

## Claim boundary

This document proves the portable and unsigned-native build/test state of the
recorded HEAD on the development Mac on 2026-08-05. It does not prove Logic
host behavior, perceptual results, or any Tutor v1 functionality (none existed
at this HEAD).

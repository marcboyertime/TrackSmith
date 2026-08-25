# TrackSmith Extreme Free Acceleration — Phase 2

This evidence records the Phase 2 implementation architecture, not a claim that a hosted runner proves signing, installation, Audio Unit registration, Logic behavior, provider quality, private-audio behavior, Accessibility, or owner listening.

The dominant measured local path was the ordinary 36-case Tutor suite (573.70 seconds warm), followed by the focused Package 016, 018, and 019 diagnostics (24.15, 23.68, and 8.17 seconds). The same-job acceleration builds the release test product once, runs a conservatively CPU-bounded deterministic partition directly from that binary, exhaustively aggregates compact local JSON reports, and then runs those unique diagnostics without rebuilding.

The remote required checks remain always-run. The change planner is advisory because safe conditional required jobs would be more brittle than their setup-time savings for the current 20–146 second Linux lanes. No `actions/cache` and no distributed Swift artifact are enabled: the checked-in contract permits neither until a current measurement establishes at least 20 percent benefit.

Local burst mode is explicit: `bash scripts/ci/run-burst-local.sh [all|linux|tutor]`. Codespaces burst mode requires an owner-started Codespaces session and runs only Linux-compatible deterministic lanes; it prints its Apple/Logic/private-boundary exclusions and shutdown reminder.

Local controlled verification passed: the unsharded reference and the three-shard aggregate each contained all 36 case IDs exactly once, and all semantic result hashes matched. The post-measurement LPT partition reported 197, 169, and 189 case-seconds respectively. These are per-case observational timings with integer-second resolution, rather than a hosted-run or owner-listening claim.

After strengthening semantic inputs and toolchain identity, a fresh same-source unsharded 36-case reference again matched the three-shard aggregate's 36 semantic result hashes. Aggregate semantic case results exclude durations; all 36 durations are isolated under observational metadata.

The primary-session accelerated full lane was measured with `TRACKSMITH_TUTOR_SHARDS=3 TRACKSMITH_P19_DIAGNOSTIC_NO_WRITE=1 bash scripts/ci/run-macos-tutor.sh`: real 258.81s, user 615.22s, and sys 4.76s. Its 36/36 aggregate used `lpt-cost-v1` and partition `8697845180c403acd3e38a8151508b803f9950e3064454edc3b3fe8d4c649695`; focused Package 016, 018, and 019 diagnostics passed. Against the comparable warm local full-plus-diagnostics baseline of 629.70s, this is a 370.89s reduction (58.8995%) and approximately 2.4331× speedup. This is an observational local timing, not a hosted-run, signing, Logic, or listening claim.

Hosted run 32794158127 is recorded as a repair signal, not a final hosted success: all 36 sharded cases and focused diagnostics passed, then the fail-closed Package 019 drift proof detected that its whole-index receipt had been generated before Phase 2 non-report files were committed. The generator now rejects non-report index or worktree changes before receipt/report generation. The required order is non-report code commit first, then report-only regeneration in a receipt-only follow-up commit; this retains whole-index binding without self-invalidating the tracked receipt.

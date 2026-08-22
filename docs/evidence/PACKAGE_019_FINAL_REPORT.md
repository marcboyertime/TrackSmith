# Package 019 Tutor quality report

## Deterministic result

The frozen evaluation-only suite contains 240 cases ({'calibration': 72, 'development': 96, 'held_out': 72}). This report omits live Git, worktree, and host-toolchain fields. Package 017/018 historical evidence remains preserved, with 6,212 runtime Package 001-016 cards and zero P17 runtime records. Receipt status: **valid**. Held-out top-1/top-4/no-match precision/no-match recall miss the 0.80/0.95/0.90/0.90 gates; ambiguity is model-withheld.

## Receipt and boundaries

`PACKAGE_019_VALIDATION_RECEIPT.json` is the deterministic staged/index candidate receipt: it is bound to Git index mode/blob/path entries, excluding generated reports/receipt (avoiding self-reference), plus the exact stage-0 blobs for suite, manifest, candidate index/manifest, policy, and tool diagnostic. It marks only commands it invokes successfully. CI emits and uploads a separate fresh receipt with the exact full built app inventory hash; that host-specific artifact is deliberately not drift-compared to this tracked report. No signing, installation, AU registration/`auval`, Logic, audio, cloud, model-assisted, or owner evidence is inferred. Cloud harnesses remain consent-gated with `store:false` and 0 calls here.

## Commands and next step

Command results are machine-readable in the JSON report; unreceipted outcomes are `not_run_unverified`, not passes. Remote CI remains pending. Required checks: Tutor integrity / fast-integrity; Tutor macOS Swift / swift; fresh Package 019 validation receipt, evidence upload, and drift check. Run `python3 research/scripts/package19_quality_suite.py --generate-validation-receipt` after deterministic revalidation, then `python3 research/scripts/package19_quality_suite.py --check --write-reports`.

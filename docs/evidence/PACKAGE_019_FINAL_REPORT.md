# Package 019 Tutor quality report

## Deterministic result

The frozen evaluation-only suite contains 240 cases ({'calibration': 72, 'development': 96, 'held_out': 72}). This report omits live Git, worktree, and host-toolchain fields. Package 017/018 historical evidence remains preserved, with 6,212 runtime Package 001-016 cards and zero P17 runtime records. Receipt status: **valid**. Current held-out top-1/top-4/no-match precision/no-match recall are **0.4265/0.7059/0.5000/0.7500**; they miss the 0.80/0.95/0.90/0.90 gates. Ambiguity is model-withheld.

## Authoritative Swift retrieval comparison

The pre-ordered6 Swift baseline is preserved from commit `bc49c8e2e2e16bc88e58c9edbe7f437d6b7874d8`. Current-final values are read from `PACKAGE_019_TOOL_DIAGNOSTIC.json`, not embedded in this report generator.

| Partition | Before top-1/top-4/P/R | Current top-1/top-4/P/R |
| --- | --- | --- |
| development | 0.3846/0.5714/0.0000/0.0000 | 0.4505/0.7363/0.5000/0.2000 |
| calibration | 0.3333/0.4638/0.1667/0.3333 | 0.3913/0.6377/0.2500/0.6667 |
| held_out | 0.3971/0.5588/0.3333/0.5000 | 0.4265/0.7059/0.5000/0.7500 |

The final policy is `package019-bm25-ordered6-domain-diverse/1`: first six unique normalized terms in their original order drive pool generation, scoring, and coverage; the existing score/confidence-26/two-overlap abstention gate remains separate from ranking; selection keeps one card per domain with bounded dedupe/package/source behavior. Ambiguity remains withheld.

## Provider-free long context

The local harness measured 10/25/50/80-message engine/store/tool runs, topic return, a decisive prior experiment, temporary level propagation, cancellation/retry, capture replacement, request bytes, estimated tokens, fixture output tokens, and bounded tool rounds. It uses an in-process recording transport and proves local mechanics only—not semantic model quality, cloud latency/cost, or musician usefulness.

## Receipt and boundaries

`PACKAGE_019_VALIDATION_RECEIPT.json` is the deterministic staged/index candidate receipt: it is bound to Git index mode/blob/path entries, excluding generated reports/receipt (avoiding self-reference), plus the exact stage-0 blobs for suite, manifest, candidate index/manifest, policy, and tool diagnostic. It marks only commands it invokes successfully. CI emits and uploads a separate fresh receipt with the exact full built app inventory hash; that host-specific artifact is deliberately not drift-compared to this tracked report. No signing, installation, AU registration/`auval`, Logic, audio, cloud, model-assisted, or owner evidence is inferred. Cloud harnesses remain consent-gated with `store:false` and 0 calls here.

## Commands and next step

Command results are machine-readable in the JSON report; unreceipted outcomes are `not_run_unverified`, not passes. Remote CI remains pending. Signing/install, AU registration/`auval`, Logic, audio, cloud/model-assisted evaluation, and owner listening are not run. Required checks: Tutor integrity / fast-integrity; Tutor macOS Swift / swift; fresh Package 019 validation receipt, evidence upload, and drift check.

The highest-value next step is, with separate explicit cloud-text consent, the full live seven-tool cloud triplet evaluation, including a no-tool comparison and repeated stability runs. The local evidence does not substitute for that model-quality measurement.

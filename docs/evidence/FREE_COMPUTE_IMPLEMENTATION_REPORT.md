# Free compute implementation report

Status: complete with live CI evidence and explicit product-evidence boundaries.

The no-secret deterministic GitHub Actions architecture was validated at implementation commit `7af84ee79c0811060f816ffdffdc7a9422f1e825`. Both preserved required checks passed on the pull request: [Tutor integrity / fast-integrity](https://github.com/marcboyertime/TrackSmith/actions/runs/32643033233) and [Tutor macOS Swift / swift](https://github.com/marcboyertime/TrackSmith/actions/runs/32643033138). Exact-SHA manual Linux and macOS proofs also passed: runs 32643063215 and 32643064294.

## Timing and parallelism

The baseline at `d962f3585222bf8b95c16b1cb1fac8cd706efa10` was 1,399 seconds critical path (Linux run 32637263229: 224 seconds workflow/222 seconds job; macOS run 32637263226: 1,399 seconds workflow/1,395 seconds job). The final PR was created at 13:39:57Z and completed at 13:56:14Z: 977 seconds, an exact 30.1644% critical-path reduction. The final macOS Tutor job was 970 seconds, 30.4659% below the baseline macOS job.

Summed job time rose from 1,617 seconds to 1,915 seconds (+298 seconds, +18.4298%). That is expected parallel-runner consumption, not a claimed compute-time saving: four Linux lanes plus aggregation execute independently, and the macOS lanes overlap. Four Linux jobs and five macOS jobs were observed concurrently. The manual macOS proof measured a 144-second Tutor queue (13:40:27Z creation to 13:42:51Z start) while five macOS jobs were active; it still completed successfully.

## Live artifact and repair evidence

The final PR Xcode artifact is `package-019-xcode-evidence` (ID 9494201152), 1,600 bytes, retained three days through 2026-08-26. Its digest is `sha256:0df9d27067418cb0e4b92918a547631a0151b551bbe7d9760e522cfba1e439c3`; the compact report and receipt hashes are `2e04b37f1b81f2f10fd68a9aa0e0795fb77fdf173ab5dfaa8ad61521f2364904` and `a2d46b1cac300dadf913b535600ce167a7cc65541c65c04050c7c78d3c959a7a`. It records unsigned app/AU/component/resource identifiers and hashes. It is not signing, installation, AU-registration, Logic, provider/model-listening, or owner-listening evidence.

PR stale-run cancellation was observed (for example, runs 32640929039/32640929030 and 32640756468/32640756467). Earlier Xcode archive-layout, temporary-project package-resolution, prefixed-resource-report, and Package 019 receipt-fingerprint-drift (run 32641960235) failures were deterministic source defects repaired by new commits—not retried as same-SHA transient failures.

## Cost and safety boundary

The completed lane uses only `ubuntu-24.04` and `macos-15`, has no cache action (0 observed cache bytes; 2 GB soft future budget), and uploads only compact evidence with three-day retention and a 25 MB cap. Branch protection was observable as absent (404) in the baseline inspection; branch protection, billing, budgets, visibility, and account-plan settings were not changed. The owner may consider a zero-dollar metered-product budget with stop usage where supported.

GitHub runner/limit/billing guidance is documented in the [hosted runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners), [limits](https://docs.github.com/en/actions/reference/limits), [runner pricing](https://docs.github.com/en/billing/reference/actions-runner-pricing), [Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions), and [budget guidance](https://docs.github.com/en/billing/how-tos/set-up-budgets).

Paid Package 019 provider/cloud work remains paused. The CI result establishes recorded source/build/test/resource outcomes only; it does not establish signing, installation, Logic behavior, provider/model quality, accessibility observation, private-audio results, or owner listening.

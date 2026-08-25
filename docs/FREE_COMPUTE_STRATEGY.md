# TrackSmith free GitHub Actions compute strategy

The default distributed compute layer is standard GitHub-hosted Actions runners for deterministic, no-secret, non-Logic engineering work. The versioned lane contract is [tracksmith_compute_lanes.json](../ci/tracksmith_compute_lanes.json); every Actions lane calls the same stable script a developer can run locally.

Linux owns Python, corpus, SQLite, deterministic report, and source-policy work. macOS owns Swift packages and Xcode products. The owner’s Mac owns signing, installation, `auval` where signing or installation identity matters, Logic, Accessibility observation, private audio, provider secrets, and perceptual judgment.

## Runner and cost boundary

This plan was checked on 2026-08-23 against GitHub’s [hosted runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners), [limits reference](https://docs.github.com/en/actions/reference/limits), [runner pricing reference](https://docs.github.com/en/billing/reference/actions-runner-pricing), and [Actions billing overview](https://docs.github.com/en/billing/concepts/product-billing/github-actions). It uses only `ubuntu-24.04` (standard x64: 4 CPU, 16 GB) and `macos-15` (standard arm64: 3 M1 cores, 7 GB) in the public repository. Standard public runners are planned as free/unlimited; larger, GPU, self-hosted, and other premium runners are prohibited.

The Free planning limit is 20 total concurrent standard jobs and five macOS jobs. The required macOS workflow uses three macOS jobs and an Ubuntu aggregator, leaving two macOS slots. The compact PR matrix is deliberately always run: changed-path skipping is brittle and would weaken required-check correctness.

No cache is enabled initially: there are no external SwiftPM dependencies, observed cache usage was zero, and no measured 20-percent-or-greater benefit exists. The documented soft future cache budget is 2 GB. GitHub Free planning storage limits are 500 MB artifacts and 10 GB cache; artifacts here are limited to compact receipt/resource reports, 3-day retention, and less than 25 MB per run. Never upload an app/AU, DerivedData, `.build`, database, private audio, credential, or provider response.

The owner should consider a zero-dollar metered-product Actions budget with stop-usage enabled where supported; see GitHub’s [budget setup guidance](https://docs.github.com/en/billing/how-tos/set-up-budgets). This repository change does not configure billing or budgets.

## Required workflows

`Tutor integrity / fast-integrity` remains the required Linux check. Four independent Linux jobs run integrity, retrieval, evaluation, and docs/policy/security; the aggregator uses `if: always()` and fails for a failed, cancelled, or skipped lane. `Tutor macOS Swift / swift` remains the required macOS check. It aggregates Swift core, Tutor, and Xcode products, but runs itself on Ubuntu so it does not consume a fourth macOS slot.

Companion and AU release builds remain combined in `macos_xcode_products`. The measured baseline combined phase was only 240 seconds and Companion already depends on AU; splitting would duplicate cold compilation without improving the dominant Tutor critical path. Both builds share temporary DerivedData. XcodeGen 2.46.0 is downloaded from its release asset, SHA-256 verified, and placed under runner temporary storage; no unpinned Homebrew state is used.

Both required workflows support `workflow_dispatch` without inputs for a clean branch/main-equivalent proof. PR pushes cancel stale runs for the same PR. Push and manual runs include their run ID in the concurrency group and never cancel another commit.

## Local parity and future Codex/package protocol

Run a lane exactly as CI does:

```sh
bash scripts/ci/run-linux-integrity.sh
bash scripts/ci/run-linux-retrieval.sh
bash scripts/ci/run-linux-evaluation.sh
bash scripts/ci/run-linux-docs-policy-security.sh
bash scripts/ci/run-macos-swift-core.sh
bash scripts/ci/run-macos-tutor.sh
bash scripts/ci/run-macos-xcode-products.sh
bash scripts/ci/run-manual-heavy.sh retrieval_stress
python3 scripts/ci/audit-free-compute.py --self-test
```

For a future Codex/package change, first assign deterministic Python/corpus/index/report work to one existing Linux lane; assign Swift tests to `macos_swift_core` or `macos_tutor`; and assign unsigned Xcode resource checks to the combined Xcode lane. Add a manifest row before adding a job. Keep provider, cloud, private audio, signing/install, Logic, and listening work owner-controlled and absent from Actions. The fail-closed audit parses every workflow and recursively scans each manifest-referenced `scripts/ci/` shell closure (bounded, repository-local, and symlink-free) for hidden secret, provider/cloud/model, signing/install, Logic, and private-audio surfaces; unresolved dynamic shell dependencies fail closed. Xcode builds must explicitly disable signing. Update the audit only with a precise reviewed exception (exact workflow, job, rule, reason, owner, review date, and expiry; wildcards fail). Do not add caches until a measured benefit justifies their documented budget.

### Durable future-Codex protocol

1. Classify the change before running anything: deterministic Linux, deterministic Swift, unsigned Xcode product, manual observation, or owner-only evidence. Do not reclassify provider, private-audio, signing/install, Logic, Accessibility, or listening work into Actions.
2. Before pushing, run the quick local pre-push checks: edited-script syntax, a targeted unit test where practical, the relevant generated-file check, `git diff --check`, and workflow YAML/audit parsing (`python3 scripts/ci/audit-free-compute.py`). Use the manifest to avoid duplicate expensive local and remote work. A local-only escape hatch remains available when a lane needs owner hardware or evidence outside the CI boundary.
3. Push the feature branch and open or update one draft PR, then monitor runs for the exact current SHA until every required job reaches a terminal conclusion. Record workflow run ID, commit, each job conclusion and timing, artifact names/hashes, and the local-only evidence that Actions cannot establish.
4. Treat only `success` as a required-lane pass. Queued, skipped, cancelled, neutral, timed-out, or missing jobs never satisfy a check. Inspect failed logs, identify the root cause, repair it, and run the new current commit.
5. Rerun only failed jobs only when the same-SHA failure is proven transient. Otherwise repair first; do not use a rerun to launder deterministic failures.
6. Preserve evidence claims: an Actions result establishes only its recorded source/build/test/resource outcome. It does not establish signing, installation, AU registration, Logic behavior, provider/model quality, accessibility observation, or owner listening.

The macOS Tutor lane intentionally regenerates the deterministic Package 019 diagnostic receipt/reports in its clean checkout and rejects tracked drift after the Swift diagnostic. The Xcode lane remains separate: it scans the actual unsigned bundle and uploads its temporary built-bundle receipt/resource report. This retains the former same-checkout diagnostic/report proof without treating the built receipt as tracked evidence.

## Phase 2 deterministic acceleration

The Tutor lane builds `TutorConversationTests` once and invokes the release binary in a bounded number of local shards. `cpu_budget.py` reserves one logical CPU and caps the default at three workers; `TRACKSMITH_TUTOR_SHARDS` can request fewer workers, but never exceeds the safe budget. Each ordinary case has a stable identifier, a resource class, a cost-balanced LPT assignment recorded in `ci/tutor_test_costs.json`, and a compact report. `aggregate_shards.py` fails closed unless all expected cases execute exactly once with matching suite, source, toolchain, policy, index, algorithm, and result hashes. A no-argument run remains the complete 36-test historical suite.

`plan_work.py` and `ci/semantic_dependencies.json` provide rename/deletion-aware advisory planning for local use and GitHub summaries. Main/manual validation and unknown/shared changes are full; required remote workflows deliberately remain always-run. `deterministic_case_cache.py` is a local-only, semantic-keyed successful-result cache primitive with schema/hash/toolchain staleness rejection and strict count/byte pruning. It excludes generated prose, provider/model responses, audio, credentials, databases, build products, and failures. No GitHub cache is enabled.

`TrackSmith heavy validation` is manually dispatched only. Its choices are `all_deterministic`, `retrieval_stress`, `swift_full`, `xcode_products`, `package019_end_to_end_no_key`, and `performance_observation`. It uses standard runners only, has no secrets or model/provider calls, and performs no signing, install, private-audio, Logic, or listening work. Hardware-sensitive performance output is explicitly observational.

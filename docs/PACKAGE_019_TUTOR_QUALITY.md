# Package 019 Tutor quality calibration

Package 019 freezes a 240-case, evaluation-only Tutor suite before further quality tuning: 96 development, 72 calibration, and 72 held-out cases. Labels include diagnosis/experiment families, evidence boundaries, clarification and reviewed-navigation needs, authority prohibitions, stop/undo expectations, alternatives, and ambiguity/abstention expectations. They are not bundled, indexed, sent to a provider, or exposed to runtime tools.

The deterministic harness is `research/scripts/package19_quality_suite.py`. It verifies the suite hash, scans runtime resources (or an explicit built/installed bundle) for evaluation leakage, and emits bounded reproducible reports under `docs/evidence/`. Cloud text, cloud audio, installed app, Logic, model-assisted judgment, and owner-listening evidence are explicitly **not run** without separate consent. The executable text harnesses are `make p19-cloud-no-tool`, `make p19-cloud-full-tool`, and `make p19-cloud-repeated-triplets`; each requires `CLOUD_TEXT_CONSENT=YES` plus `--cloud-text-consent`, uses the production provider path with `store:false`, and records hashes/configuration/tokens/latency only after an actual attempt. They are not invoked by Package 019 deterministic gates.

Runtime retrieval keeps the Package 018 reader and now distinguishes a valid `noMatch` from `queryFailed`, `malformedSelectedPayload`, `schemaDrift`, `corrupt`, `disabled`, `unavailable`, and `versionMismatch`. Those sanitized outcomes do not expose local paths or SQLite errors. Ranking and abstention are separate calibration measurements; ambiguity diagnostics remain evaluation-only/model-withheld until held-out balanced accuracy is at least 0.75.

The LLM remains the primary reasoner and author. The existing compact policy and presentation-only `present_experiment` contract require one user-performed, reversible experiment with a baseline/start, one variable, listen cue, risk, stop/undo, and honest evidence boundary when an actionable turn warrants it. Pure explanation or necessary clarification is not force-templated.

Packages 005 and 006 historical import reports remain byte-for-byte unchanged. Additive Package 019 attestations supply their missing portable `force_semantics:false` projections for clean-checkout verification only.

Run `make p19-ci` for deterministic gates, or `make p19-built-resource-scan BUNDLE=/path/to/TrackSmith.app` for an explicit built/installed bundle. See [the machine report](evidence/PACKAGE_019_FINAL_REPORT.json) for the exact evidence boundary.

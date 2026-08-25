#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
cd "$(tracksmith_repo_root)"
tool_versions
require_command swift
toolchain_identity="$( { swift --version | head -n 2; uname -srm; } | tr '\n' ' ' )"
export TRACKSMITH_TUTOR_TOOLCHAIN_ID="$toolchain_identity"
section "build TutorConversationTests once"
swift build -c release --product TutorConversationTests
binary="$(pwd -P)/.build/release/TutorConversationTests"
[[ -x "$binary" ]] || { echo "error: TutorConversationTests release binary is missing" >&2; exit 1; }
requested_shards="${TRACKSMITH_TUTOR_SHARDS:-0}"
safe_workers="$(python3 scripts/ci/cpu_budget.py --cap "${TRACKSMITH_MAX_TUTOR_SHARDS:-3}" --reserve "${TRACKSMITH_TUTOR_RESERVED_CPUS:-0}")"
if [[ "$requested_shards" =~ ^[1-9][0-9]*$ ]]; then
  shard_count="$requested_shards"
  if (( shard_count > safe_workers )); then shard_count="$safe_workers"; fi
else
  shard_count="$safe_workers"
fi
section "full Tutor conversation suite: $shard_count deterministic direct-binary shard(s)"
if [[ -n "${TRACKSMITH_TUTOR_SHARD_REPORT_DIR:-}" ]]; then
  temporary_directory="$TRACKSMITH_TUTOR_SHARD_REPORT_DIR"
  [[ ! -e "$temporary_directory" ]] || { echo "error: TRACKSMITH_TUTOR_SHARD_REPORT_DIR must not already exist" >&2; exit 64; }
  mkdir -p "$temporary_directory"
else
  temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/tracksmith-tutor-shards.XXXXXX")"
  trap 'rm -rf "$temporary_directory"' EXIT
fi
workers=()
for ((index = 0; index < shard_count; index++)); do
  "$binary" --shard-index "$index" --shard-count "$shard_count" --output-json "$temporary_directory/shard-$index.json" >"$temporary_directory/shard-$index.log" 2>&1 &
  workers+=("$!")
done
shard_failure=0
for worker in "${workers[@]}"; do
  if ! wait "$worker"; then shard_failure=1; fi
done
for ((index = 0; index < shard_count; index++)); do cat "$temporary_directory/shard-$index.log"; done
aggregate_failure=0
if ! python3 scripts/ci/aggregate_shards.py "$temporary_directory"/shard-*.json --output "$temporary_directory/aggregate.json"; then aggregate_failure=1; fi
if (( shard_failure || aggregate_failure )); then
  echo "error: one or more Tutor shards or the exhaustive aggregate failed" >&2
  exit 1
fi
section "focused package diagnostics not represented by the full-suite dispatch contract"
"$binary" package16-diagnostics
"$binary" package18-diagnostics
if [[ "${TRACKSMITH_P19_DIAGNOSTIC_NO_WRITE:-}" == "1" ]]; then
  "$binary" package19-diagnostics
  section "Package 019 report regeneration intentionally skipped for focused no-write diagnosis"
else
  section "Package 019 deterministic diagnostic, receipt, and report drift"
  # This intentionally retains the former same-clean-checkout proof: the
  # Swift diagnostic feeds the authoritative tracked P19 receipt/reports, then
  # Git rejects any drift. The Xcode lane separately receipts the built app.
  python3 research/scripts/package19_quality_suite.py --generate-validation-receipt
  python3 research/scripts/package19_quality_suite.py --check --write-reports
  git diff --exit-code -- \
    docs/evidence/PACKAGE_019_RETRIEVAL_CALIBRATION.json \
    docs/evidence/PACKAGE_019_LONG_CONTEXT_COST.json \
    docs/evidence/PACKAGE_019_EXPERIMENT_COMPLETENESS.json \
    docs/evidence/PACKAGE_019_DETERMINISTIC_END_TO_END.json \
    docs/evidence/PACKAGE_019_VALIDATION_RECEIPT.json \
    docs/evidence/PACKAGE_019_FINAL_REPORT.json \
    docs/evidence/PACKAGE_019_FINAL_REPORT.md
fi
ci_summary "✅ macos_tutor: full Tutor suite, focused diagnostics, and Package 019 same-checkout report drift proof passed."

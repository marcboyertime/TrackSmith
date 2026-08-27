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
python3 scripts/ci/test-sharding.py --binary "$binary"
python3 scripts/ci/test-tutor-cache-runner.py --binary "$binary"
requested_shards="${TRACKSMITH_TUTOR_SHARDS:-0}"
configured_cap="${TRACKSMITH_MAX_TUTOR_SHARDS:-3}"
[[ "$configured_cap" =~ ^[1-9][0-9]*$ ]] && (( configured_cap <= 3 )) || { echo "error: TRACKSMITH_MAX_TUTOR_SHARDS must be an integer from 1 through 3" >&2; exit 64; }
safe_workers="$(python3 scripts/ci/cpu_budget.py --cap "$configured_cap" --reserve "${TRACKSMITH_TUTOR_RESERVED_CPUS:-0}")"
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
"$binary" --list-tests >"$temporary_directory/ordinary-tests.tsv"
if [[ -n "${GITHUB_SHA:-}" ]]; then
  shard_commit="$GITHUB_SHA"
  shard_tree_classification="github-clean-checkout"
else
  shard_commit="local"
  shard_tree_classification="local-observational"
fi
python3 scripts/ci/shard_protocol.py \
  --contract-output "$temporary_directory/contract.json" \
  --cost-manifest ci/tutor_test_costs.json \
  --list "$temporary_directory/ordinary-tests.tsv" \
  --repo-root "$(pwd -P)" \
  --commit "$shard_commit" \
  --tree-classification "$shard_tree_classification" \
  --toolchain-identity "$TRACKSMITH_TUTOR_TOOLCHAIN_ID"
shard_failure=0
if [[ -n "${TRACKSMITH_TUTOR_CASE_CACHE_DIR:-}" ]]; then
  section "local deterministic Tutor case cache (no provider cache or artifact transport)"
  if ! python3 scripts/ci/run_tutor_cached.py \
    --binary "$binary" \
    --contract "$temporary_directory/contract.json" \
    --list "$temporary_directory/ordinary-tests.tsv" \
    --cache-root "$TRACKSMITH_TUTOR_CASE_CACHE_DIR" \
    --output-dir "$temporary_directory" \
    --shard-count "$shard_count" \
    --cost-manifest ci/tutor_test_costs.json \
    --repo-root "$(pwd -P)"; then
    shard_failure=1
  fi
  for ((index = 0; index < shard_count; index++)); do [[ -f "$temporary_directory/shard-$index.log" ]] && cat "$temporary_directory/shard-$index.log"; done
else
  workers=()
  for ((index = 0; index < shard_count; index++)); do
    "$binary" --shard-index "$index" --shard-count "$shard_count" --output-json "$temporary_directory/shard-$index.json" >"$temporary_directory/shard-$index.log" 2>&1 &
    workers+=("$!")
  done
  for worker in "${workers[@]}"; do
    if ! wait "$worker"; then shard_failure=1; fi
  done
  for ((index = 0; index < shard_count; index++)); do cat "$temporary_directory/shard-$index.log"; done
fi
aggregate_failure=0
if ! python3 scripts/ci/aggregate_shards.py "$temporary_directory"/shard-*.json --contract "$temporary_directory/contract.json" --output "$temporary_directory/aggregate.json"; then aggregate_failure=1; fi
if (( shard_failure || aggregate_failure )); then
  echo "error: one or more Tutor shards or the exhaustive aggregate failed" >&2
  exit 1
fi
section "focused package diagnostics not represented by the full-suite dispatch contract"
"$binary" package19-cloud-budget-self-test
"$binary" package16-diagnostics
"$binary" package18-diagnostics
TRACKSMITH_P19_DIAGNOSTIC_NO_WRITE=1 "$binary" package19-diagnostics
section "Package 019 diagnostic runs no-write; historical evidence remains frozen"
section "retrieval quality recovery deterministic checks"
python3 research/scripts/retrieval_quality_recovery.py --check
python3 research/scripts/retrieval_architecture_baselines.py --check
ci_summary "✅ macos_tutor: full Tutor suite, focused diagnostics, frozen Package 019 evidence, and recovery checks passed."

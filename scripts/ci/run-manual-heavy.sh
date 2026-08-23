#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
cd "$(tracksmith_repo_root)"

lane="${1:-}"
case "$lane" in
  all_deterministic)
    bash scripts/ci/run-linux-integrity.sh
    bash scripts/ci/run-linux-retrieval.sh
    bash scripts/ci/run-linux-evaluation.sh
    bash scripts/ci/run-linux-docs-policy-security.sh
    bash scripts/ci/run-macos-swift-core.sh
    bash scripts/ci/run-macos-tutor.sh
    bash scripts/ci/run-macos-xcode-products.sh
    ;;
  retrieval_stress)
    bash scripts/ci/run-linux-retrieval.sh
    ;;
  swift_full)
    bash scripts/ci/run-macos-swift-core.sh
    bash scripts/ci/run-macos-tutor.sh
    ;;
  xcode_products)
    bash scripts/ci/run-macos-xcode-products.sh
    ;;
  package019_end_to_end_no_key)
    bash scripts/ci/run-linux-evaluation.sh
    bash scripts/ci/run-macos-tutor.sh
    ;;
  performance_observation)
    bash scripts/ci/run-linux-retrieval.sh
    printf 'Performance output is hardware-sensitive observation, not a merge gate.\n'
    ;;
  *)
    printf 'usage: %s {all_deterministic|retrieval_stress|swift_full|xcode_products|package019_end_to_end_no_key|performance_observation}\n' "$0" >&2
    exit 2
    ;;
esac

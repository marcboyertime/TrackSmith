#!/usr/bin/env bash
# Owner-invoked local deterministic burst; no remote service is created or selected.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
cd "$(tracksmith_repo_root)"
tool_versions
run_lane() {
  case "$1" in
    "bash scripts/ci/run-linux-integrity.sh") bash scripts/ci/run-linux-integrity.sh ;;
    "bash scripts/ci/run-linux-retrieval.sh") bash scripts/ci/run-linux-retrieval.sh ;;
    "bash scripts/ci/run-linux-evaluation.sh") bash scripts/ci/run-linux-evaluation.sh ;;
    "bash scripts/ci/run-linux-docs-policy-security.sh") bash scripts/ci/run-linux-docs-policy-security.sh ;;
    "bash scripts/ci/run-macos-swift-core.sh") bash scripts/ci/run-macos-swift-core.sh ;;
    "bash scripts/ci/run-macos-tutor.sh") bash scripts/ci/run-macos-tutor.sh ;;
    "bash scripts/ci/run-macos-xcode-products.sh") bash scripts/ci/run-macos-xcode-products.sh ;;
    *) echo "error: planner emitted an unrecognized local lane" >&2; return 64 ;;
  esac
}
if [[ "${1:-}" == "--base" ]]; then
  [[ -n "${2:-}" && $# -eq 2 ]] || { echo "usage: $0 --base BASE_SHA" >&2; exit 64; }
  while IFS= read -r command; do run_lane "$command"; done < <(python3 scripts/ci/plan_work.py --base "$2" --emit-local-commands)
  exit 0
fi
case "${1:-all}" in
  tutor) bash scripts/ci/run-macos-tutor.sh ;;
  linux) bash scripts/ci/run-linux-integrity.sh && bash scripts/ci/run-linux-retrieval.sh && bash scripts/ci/run-linux-evaluation.sh && bash scripts/ci/run-linux-docs-policy-security.sh ;;
  all) bash scripts/ci/run-linux-integrity.sh && bash scripts/ci/run-linux-retrieval.sh && bash scripts/ci/run-linux-evaluation.sh && bash scripts/ci/run-linux-docs-policy-security.sh && bash scripts/ci/run-macos-tutor.sh ;;
  *) echo "usage: $0 [all|linux|tutor] | --base BASE_SHA" >&2; exit 64 ;;
esac

#!/usr/bin/env bash
# Owner-invoked local deterministic burst; no remote service is created or selected.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
cd "$(tracksmith_repo_root)"
tool_versions
case "${1:-all}" in
  tutor) bash scripts/ci/run-macos-tutor.sh ;;
  linux) bash scripts/ci/run-linux-integrity.sh && bash scripts/ci/run-linux-retrieval.sh && bash scripts/ci/run-linux-evaluation.sh && bash scripts/ci/run-linux-docs-policy-security.sh ;;
  all) bash scripts/ci/run-linux-integrity.sh && bash scripts/ci/run-linux-retrieval.sh && bash scripts/ci/run-linux-evaluation.sh && bash scripts/ci/run-linux-docs-policy-security.sh && bash scripts/ci/run-macos-tutor.sh ;;
  *) echo "usage: $0 [all|linux|tutor]" >&2; exit 64 ;;
esac

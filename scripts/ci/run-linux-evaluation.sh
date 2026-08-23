#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
cd "$(tracksmith_repo_root)"
tool_versions
section "package 017 evaluation-only boundary"
python3 research/scripts/package17-evaluation.py --check
section "package 019 frozen deterministic checks"
python3 research/scripts/package19_quality_suite.py --check
python3 research/scripts/package19_quality_suite.py --scanner-self-test --receipt-self-test
ci_summary "✅ linux_evaluation: Package 017 boundary and Package 019 frozen deterministic checks passed."

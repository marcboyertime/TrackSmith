#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
cd "$(tracksmith_repo_root)"
tool_versions
section "package 018 deterministic index"
python3 research/scripts/build_candidate_retrieval_index.py --check
section "package 018 retrieval audit"
python3 research/scripts/package18_audit.py
section "package 019 runtime-resource boundary"
python3 research/scripts/package19_quality_suite.py --check --forbidden-resource
ci_summary "✅ linux_retrieval: index, SQLite parity, retrieval audit, and runtime-resource boundary passed."

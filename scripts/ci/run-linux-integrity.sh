#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
cd "$(tracksmith_repo_root)"
tool_versions
section "python syntax"
pycache_dir="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/tracksmith-ci-pycache"
mkdir -p "$pycache_dir"
PYTHONPYCACHEPREFIX="$pycache_dir" python3 -m py_compile \
  research/scripts/community_corpus_import.py \
  research/scripts/build_candidate_retrieval_index.py \
  research/scripts/package18_audit.py \
  research/scripts/package19_quality_suite.py
section "corpus preservation and imports"
python3 research/scripts/community_corpus_import.py --preservation-self-check
python3 research/scripts/package16-integration.py --preservation-self-check
python3 research/scripts/community_corpus_import.py --check
section "package 016 evidence contract"
python3 research/scripts/package16-evidence-release.py --audit
ci_summary "✅ linux_integrity: corpus preservation, imports, and Package 016 evidence contract passed."

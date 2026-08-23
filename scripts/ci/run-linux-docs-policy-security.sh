#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
cd "$(tracksmith_repo_root)"
tool_versions
section "product resource boundary"
test ! -e packages/ProductionTutor/Sources/ProductionTutor/Resources/tracksmith-corpus-017-golden-tutor-conversations-level-adaptation.json
test "$(find packages/ProductionTutor/Sources/ProductionTutor/Resources -name '*.json' | wc -l | tr -d ' ')" = 1
! rg -a -i 'tracksmith-corpus-017|expected_answer|fixture_alias|evaluation_case' packages/ProductionTutor/Sources/ProductionTutor/Resources/CandidateRetrieval.sqlite packages/ProductionTutor/Sources/ProductionTutor/Resources/CandidateRetrieval.manifest.json
! rg -i 'p19-|acceptable_diagnosis_families|expected_answer|fixture_alias|evaluation_case' packages/TutorConversation/Sources packages/ProductionTutor/Sources
section "workflow safety audit"
python3 scripts/ci/audit-free-compute.py
section "format and document parse checks"
python3 -m json.tool ci/tracksmith_compute_lanes.json >/dev/null
python3 -m json.tool docs/evidence/FREE_COMPUTE_BASELINE.json >/dev/null
python3 -m json.tool docs/evidence/FREE_COMPUTE_IMPLEMENTATION_REPORT.json >/dev/null
git diff --check
ci_summary "✅ linux_docs_policy_security: resource policy, workflow safety, JSON, and whitespace checks passed."

#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
cd "$(tracksmith_repo_root)"
tool_versions
section "product resource boundary"
python3 scripts/ci/check-product-resource-policy.py --self-test
python3 scripts/ci/check-product-resource-policy.py
section "workflow safety audit"
python3 scripts/ci/audit-free-compute.py
section "format and document parse checks"
python3 -m json.tool ci/tracksmith_compute_lanes.json >/dev/null
python3 -m json.tool docs/evidence/FREE_COMPUTE_BASELINE.json >/dev/null
python3 -m json.tool docs/evidence/FREE_COMPUTE_IMPLEMENTATION_REPORT.json >/dev/null
python3 -m json.tool ci/tutor_test_costs.json >/dev/null
python3 -m json.tool ci/semantic_dependencies.json >/dev/null
python3 -m json.tool docs/evidence/EXTREME_ACCELERATION_BASELINE.json >/dev/null
python3 -m json.tool docs/evidence/EXTREME_ACCELERATION_REPORT.json >/dev/null
python3 scripts/ci/test-sharding.py
python3 scripts/ci/test-case-cache.py
python3 scripts/ci/test-change-planner.py
git diff --check
ci_summary "✅ linux_docs_policy_security: resource policy, workflow safety, JSON, and whitespace checks passed."

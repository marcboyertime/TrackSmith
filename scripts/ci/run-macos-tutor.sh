#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
cd "$(tracksmith_repo_root)"
tool_versions
require_command swift
section "full Tutor conversation suite"
swift run -c release TutorConversationTests
section "focused package diagnostics not represented by the full-suite dispatch contract"
swift run -c release TutorConversationTests package16-diagnostics
swift run -c release TutorConversationTests package18-diagnostics
swift run -c release TutorConversationTests package19-diagnostics
if [[ "${TRACKSMITH_P19_DIAGNOSTIC_NO_WRITE:-}" == "1" ]]; then
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

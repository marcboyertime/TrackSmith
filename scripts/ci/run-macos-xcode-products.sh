#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
cd "$(tracksmith_repo_root)"
tool_versions
require_command curl
require_command shasum
require_command xcodebuild

work_dir="${RUNNER_TEMP:-$(mktemp -d)}/tracksmith-xcode-products"
tool_root="$work_dir/xcodegen"
derived_data="$work_dir/DerivedData"
mkdir -p "$work_dir" "$derived_data"
section "install pinned XcodeGen 2.46.0"
archive="$work_dir/xcodegen.zip"
curl --fail --location --retry 3 --retry-delay 2 --silent --show-error \
  --output "$archive" \
  https://github.com/yonaskolb/XcodeGen/releases/download/2.46.0/xcodegen.zip
expected_sha256='4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806'
actual_sha256="$(shasum -a 256 "$archive" | awk '{print $1}')"
[[ "$actual_sha256" == "$expected_sha256" ]] || { printf 'error: XcodeGen checksum mismatch\nexpected: %s\nactual:   %s\n' "$expected_sha256" "$actual_sha256" >&2; exit 1; }
# The verified release archive contains xcodegen/bin/xcodegen and share/
# resources. Keep that layout intact: the binary resolves its presets there.
# -o makes a same-RUNNER_TEMP rerun noninteractive while staying scoped to this
# lane's temporary tool root; no repository or broad temporary deletion occurs.
unzip -o -q "$archive" -d "$work_dir"
xcodegen_binary="$tool_root/bin/xcodegen"
test -x "$xcodegen_binary"
"$xcodegen_binary" version | grep -F 'Version: 2.46.0'
section "generate and build unsigned products with shared DerivedData"
project_output_dir="$work_dir/project-output"
project="$project_output_dir/LogicAudioAssistant.xcodeproj"
mkdir -p "$project_output_dir"
PATH="$tool_root/bin:$PATH" "$xcodegen_binary" generate --spec "$PWD/project.yml" --project "$project_output_dir" --project-root "$PWD"
test -d "$project"
xcodebuild -project "$project" -scheme CompanionMacApp -configuration Release -destination 'platform=macOS' -derivedDataPath "$derived_data" CODE_SIGNING_ALLOWED=NO build
xcodebuild -project "$project" -scheme AssistantAudioUnitExtension -configuration Release -destination 'platform=macOS' -derivedDataPath "$derived_data" CODE_SIGNING_ALLOWED=NO build
app_bundle="$derived_data/Build/Products/Release/Logic Audio Assistant.app"
section "Package 019 unsigned bundle and resource checks"
test -d "$app_bundle"
test -d "$app_bundle/Contents/PlugIns/Logic Audio Assistant AU.appex"
python3 research/scripts/package19_quality_suite.py --check --forbidden-resource --installed-bundle "$app_bundle"
test "$(find "$derived_data" -path '*ProductionTutor.bundle/Contents/Resources/*.json' -type f ! -name 'CandidateRetrieval.manifest.json' | wc -l | tr -d ' ')" = 0
! rg -a -i 'tracksmith-corpus-017|p19-|expected_answer|fixture_alias|evaluation_case' "$app_bundle/Contents/Resources"
receipt="$work_dir/package019-ci-receipt.json"
python3 research/scripts/package19_quality_suite.py --generate-validation-receipt --installed-bundle "$app_bundle" --receipt-output "$receipt"
section "tracked Package 019 evidence remains unchanged"
git diff --exit-code -- \
  docs/evidence/PACKAGE_019_RETRIEVAL_CALIBRATION.json \
  docs/evidence/PACKAGE_019_LONG_CONTEXT_COST.json \
  docs/evidence/PACKAGE_019_EXPERIMENT_COMPLETENESS.json \
  docs/evidence/PACKAGE_019_DETERMINISTIC_END_TO_END.json \
  docs/evidence/PACKAGE_019_VALIDATION_RECEIPT.json \
  docs/evidence/PACKAGE_019_FINAL_REPORT.json \
  docs/evidence/PACKAGE_019_FINAL_REPORT.md
report="$work_dir/xcode-products-report.json"
xcode_version="$(xcodebuild -version | tr '\n' ';' | sed 's/;$//')"
runner_image="${ImageOS:-local-unknown}"
runner_architecture="${RUNNER_ARCH:-$(uname -m)}"
python3 scripts/ci/write-xcode-products-report.py \
  --app "$app_bundle" --receipt "$receipt" --output "$report" \
  --xcode-version "$xcode_version" --runner-image "$runner_image" --runner-architecture "$runner_architecture"
printf 'TRACKSMITH_XCODE_EVIDENCE_DIR=%s\n' "$work_dir" >> "${GITHUB_ENV:-/dev/null}"
ci_summary "✅ macos_xcode_products: pinned XcodeGen, unsigned Companion+AU builds, resource scan, and compact receipt passed."

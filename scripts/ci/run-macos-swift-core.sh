#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
cd "$(tracksmith_repo_root)"
tool_versions
require_command swift
section "release Swift build"
swift build -c release
section "portable deterministic TestRunner"
swift run -c release TestRunner
ci_summary "✅ macos_swift_core: release build and TestRunner passed."

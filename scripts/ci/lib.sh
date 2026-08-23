#!/usr/bin/env bash
# Shared, intentionally small helpers for locally runnable CI lanes.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

tracksmith_repo_root() {
  local source_dir
  source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
  cd -- "$source_dir/../.."
  pwd -P
}

section() {
  printf '\n===== %s =====\n' "$*"
}

tool_versions() {
  section "tool versions"
  python3 --version
  git --version
  if command -v swift >/dev/null 2>&1; then swift --version | head -n 1; fi
  if command -v xcodebuild >/dev/null 2>&1; then xcodebuild -version | head -n 2; fi
}

ci_summary() {
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    printf '%s\n' "$*" >> "$GITHUB_STEP_SUMMARY"
  fi
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'error: required command not found: %s\n' "$1" >&2
    exit 127
  }
}

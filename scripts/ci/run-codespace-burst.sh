#!/usr/bin/env bash
# This script is intentionally inert outside an owner-started Codespaces session.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
cd "$(tracksmith_repo_root)"
[[ -n "${CODESPACES:-}" ]] || { echo "Refusing: start a Codespace yourself; this command never creates or selects one." >&2; exit 64; }
logical_cpus="$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || printf unknown)"
if [[ -r /proc/meminfo ]]; then physical_memory="$(awk '/MemTotal/ { print $2 " kB"; exit }' /proc/meminfo)"; else physical_memory="$(sysctl -n hw.memsize 2>/dev/null || printf unknown)"; fi
echo "Detected logical CPUs: $logical_cpus; physical memory: $physical_memory."
echo "Linux-compatible deterministic burst only. Apple builds, Logic, signing/install, private audio, credentials, and listening are unsupported here. Stop the Codespace when finished."
bash scripts/ci/run-linux-integrity.sh
bash scripts/ci/run-linux-retrieval.sh
bash scripts/ci/run-linux-evaluation.sh
bash scripts/ci/run-linux-docs-policy-security.sh

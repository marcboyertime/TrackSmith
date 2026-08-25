#!/usr/bin/env python3
"""Local-only validated result cache; it intentionally never stores build products."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import time
from pathlib import Path
from typing import Any

SCHEMA = "tracksmith-deterministic-case-cache/1"
MAX_ENTRY_BYTES = 256 * 1024
COMPONENT_KEYS = {"suite_id", "suite_version", "source_hash", "policy_hash", "index_hash", "toolchain_hash", "case_id", "semantic_input_hash"}
RESULT_KEYS = {"case_id", "semantic_input_hash", "outcome", "result_hash"}
HASH = re.compile(r"^[0-9a-f]{64}$")
CASE_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._/-]{0,191}$")


def key(components: dict[str, str]) -> str:
    if set(components) != COMPONENT_KEYS or not all(isinstance(value, str) for value in components.values()) or not CASE_ID.fullmatch(components["suite_id"]) or not CASE_ID.fullmatch(components["suite_version"]) or not CASE_ID.fullmatch(components["case_id"]) or any(not HASH.fullmatch(components[name]) for name in COMPONENT_KEYS - {"suite_id", "suite_version", "case_id"}):
        raise ValueError("components must use the exact compact deterministic schema")
    return hashlib.sha256(json.dumps(components, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def path_for(root: Path, cache_key: str) -> Path: return root / f"{cache_key}.json"


def load(root: Path, components: dict[str, str]) -> dict[str, Any] | None:
    if root.is_symlink(): return None
    target = path_for(root, key(components))
    try:
        value = json.loads(target.read_text())
    except (OSError, json.JSONDecodeError): return None
    if target.is_symlink() or not isinstance(value, dict) or set(value) != {"schema_version", "components", "result", "result_hash", "created_epoch"} or value.get("schema_version") != SCHEMA or value.get("components") != components:
        return None
    result = value.get("result")
    if not isinstance(result, dict) or set(result) != RESULT_KEYS or result.get("outcome") != "passed" or result.get("case_id") != components["case_id"] or result.get("semantic_input_hash") != components["semantic_input_hash"] or not isinstance(result.get("result_hash"), str) or result["result_hash"] != hashlib.sha256(f"{result['case_id']}|passed|{result['semantic_input_hash']}".encode()).hexdigest():
        return None
    if value.get("result_hash") != hashlib.sha256(json.dumps(result, sort_keys=True, separators=(",", ":")).encode()).hexdigest(): return None
    return result


def store(root: Path, components: dict[str, str], result: dict[str, Any]) -> None:
    key(components)
    if root.exists() and root.is_symlink(): raise ValueError("cache root cannot be a symlink")
    if set(result) != RESULT_KEYS or result.get("outcome") != "passed" or result.get("case_id") != components["case_id"] or result.get("semantic_input_hash") != components["semantic_input_hash"] or result.get("result_hash") != hashlib.sha256(f"{components['case_id']}|passed|{components['semantic_input_hash']}".encode()).hexdigest(): raise ValueError("result must use the exact compact passed-case schema")
    payload = {"schema_version": SCHEMA, "components": components, "result": result, "result_hash": hashlib.sha256(json.dumps(result, sort_keys=True, separators=(",", ":")).encode()).hexdigest(), "created_epoch": int(time.time())}
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
    if len(encoded) > MAX_ENTRY_BYTES: raise ValueError("cache entry exceeds serialized-byte cap")
    root.mkdir(parents=True, exist_ok=True)
    path_for(root, key(components)).write_bytes(encoded)


def prune(root: Path, maximum_entries: int, maximum_bytes: int) -> None:
    if maximum_entries < 0 or maximum_bytes < 0: raise ValueError("cache budgets must be nonnegative")
    files = sorted((item for item in root.glob("*.json") if item.is_file()), key=lambda item: item.stat().st_mtime, reverse=True) if root.exists() else []
    total = 0
    for index, item in enumerate(files):
        size = item.stat().st_size
        if index >= maximum_entries or total + size > maximum_bytes: item.unlink()
        else: total += size


def main() -> int:
    parser = argparse.ArgumentParser(); parser.add_argument("root", type=Path); parser.add_argument("--prune", action="store_true"); parser.add_argument("--entries", type=int, default=256); parser.add_argument("--bytes", type=int, default=16 * 1024 * 1024)
    args = parser.parse_args()
    if args.prune: prune(args.root, args.entries, args.bytes)
    return 0


if __name__ == "__main__": raise SystemExit(main())

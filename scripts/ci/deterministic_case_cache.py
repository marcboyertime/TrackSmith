#!/usr/bin/env python3
"""Local-only validated result cache; it intentionally never stores build products."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import time
from pathlib import Path
from typing import Any

SCHEMA = "tracksmith-deterministic-case-cache/1"
FORBIDDEN = ("audio", "credential", "secret", "provider", "prose", "database", "build", "failure")
MAX_ENTRY_BYTES = 256 * 1024


def key(components: dict[str, str]) -> str:
    if not components or any(not isinstance(value, str) or not value for value in components.values()):
        raise ValueError("semantic components must be nonempty strings")
    return hashlib.sha256(json.dumps(components, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def path_for(root: Path, cache_key: str) -> Path: return root / f"{cache_key}.json"


def load(root: Path, components: dict[str, str]) -> dict[str, Any] | None:
    target = path_for(root, key(components))
    try:
        value = json.loads(target.read_text())
    except (OSError, json.JSONDecodeError): return None
    if not isinstance(value, dict) or value.get("schema_version") != SCHEMA or value.get("components") != components:
        return None
    result = value.get("result")
    if not isinstance(result, dict) or result.get("outcome") != "passed" or any(term in json.dumps(result).lower() for term in FORBIDDEN):
        return None
    if value.get("result_hash") != hashlib.sha256(json.dumps(result, sort_keys=True, separators=(",", ":")).encode()).hexdigest(): return None
    return result


def store(root: Path, components: dict[str, str], result: dict[str, Any]) -> None:
    if result.get("outcome") != "passed" or any(term in json.dumps(result).lower() for term in FORBIDDEN):
        raise ValueError("only compact successful deterministic results are cacheable")
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

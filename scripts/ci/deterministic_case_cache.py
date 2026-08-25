#!/usr/bin/env python3
"""Local-only validated result cache; it intentionally never stores build products."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import secrets
import stat
import time
from pathlib import Path
from typing import Any, Callable

SCHEMA = "tracksmith-deterministic-case-cache/1"
MAX_ENTRY_BYTES = 256 * 1024
COMPONENT_KEYS = {"suite_id", "suite_version", "source_hash", "policy_hash", "index_hash", "toolchain_hash", "case_id", "semantic_input_hash"}
RESULT_KEYS = {"case_id", "semantic_input_hash", "outcome", "result_hash"}
HASH = re.compile(r"^[0-9a-f]{64}$")
CASE_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._/-]{0,191}$")
# Test-only deterministic interleaving point. Production leaves this unset.
RACE_HOOK: Callable[[str, Path], None] | None = None


def key(components: dict[str, str]) -> str:
    if set(components) != COMPONENT_KEYS or not all(isinstance(value, str) for value in components.values()) or not CASE_ID.fullmatch(components["suite_id"]) or not CASE_ID.fullmatch(components["suite_version"]) or not CASE_ID.fullmatch(components["case_id"]) or any(not HASH.fullmatch(components[name]) for name in COMPONENT_KEYS - {"suite_id", "suite_version", "case_id"}):
        raise ValueError("components must use the exact compact deterministic schema")
    return hashlib.sha256(json.dumps(components, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def path_for(root: Path, cache_key: str) -> Path: return root / f"{cache_key}.json"


def _entry_name(cache_key: str) -> str: return f"{cache_key}.json"


def _race(point: str, root: Path) -> None:
    if RACE_HOOK is not None: RACE_HOOK(point, root)


def _open_root(root: Path, create: bool) -> int:
    if not hasattr(os, "O_NOFOLLOW"): raise ValueError("cache root requires O_NOFOLLOW support")
    if root.is_symlink(): raise ValueError("cache root cannot be a symlink")
    if create: root.mkdir(parents=True, exist_ok=True)
    flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | os.O_NOFOLLOW
    try: descriptor = os.open(root, flags)
    except OSError as error: raise ValueError("cache root cannot be opened without following links") from error
    if not stat.S_ISDIR(os.fstat(descriptor).st_mode):
        os.close(descriptor); raise ValueError("cache root must be a directory")
    return descriptor


def _verify_root(root: Path, descriptor: int) -> None:
    try: current = os.lstat(root)
    except OSError as error: raise ValueError("cache root was replaced") from error
    opened = os.fstat(descriptor)
    if stat.S_ISLNK(current.st_mode) or (current.st_dev, current.st_ino) != (opened.st_dev, opened.st_ino):
        raise ValueError("cache root was replaced")


def _open_regular(name: str, root: Path, descriptor: int) -> int | None:
    _race("before-entry-open", root)
    _verify_root(root, descriptor)
    try: entry = os.open(name, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW, dir_fd=descriptor)
    except FileNotFoundError: return None
    except OSError: return None
    if not stat.S_ISREG(os.fstat(entry).st_mode):
        os.close(entry); return None
    return entry


def load(root: Path, components: dict[str, str]) -> dict[str, Any] | None:
    cache_key = key(components)
    try:
        descriptor = _open_root(root, create=False)
    except ValueError: return None
    try:
        entry = _open_regular(_entry_name(cache_key), root, descriptor)
        if entry is None: return None
        with os.fdopen(entry, "rb") as handle:
            value = json.loads(handle.read())
    except (OSError, ValueError, json.JSONDecodeError): return None
    finally:
        os.close(descriptor)
    if not isinstance(value, dict) or set(value) != {"schema_version", "components", "result", "result_hash", "created_epoch"} or value.get("schema_version") != SCHEMA or value.get("components") != components or type(value.get("created_epoch")) is not int or value["created_epoch"] < 0:
        return None
    result = value.get("result")
    if not isinstance(result, dict) or set(result) != RESULT_KEYS or result.get("outcome") != "passed" or result.get("case_id") != components["case_id"] or result.get("semantic_input_hash") != components["semantic_input_hash"] or not isinstance(result.get("result_hash"), str) or result["result_hash"] != hashlib.sha256(f"{result['case_id']}|passed|{result['semantic_input_hash']}".encode()).hexdigest():
        return None
    if value.get("result_hash") != hashlib.sha256(json.dumps(result, sort_keys=True, separators=(",", ":")).encode()).hexdigest(): return None
    return result


def store(root: Path, components: dict[str, str], result: dict[str, Any]) -> None:
    cache_key = key(components)
    if set(result) != RESULT_KEYS or result.get("outcome") != "passed" or result.get("case_id") != components["case_id"] or result.get("semantic_input_hash") != components["semantic_input_hash"] or result.get("result_hash") != hashlib.sha256(f"{components['case_id']}|passed|{components['semantic_input_hash']}".encode()).hexdigest(): raise ValueError("result must use the exact compact passed-case schema")
    payload = {"schema_version": SCHEMA, "components": components, "result": result, "result_hash": hashlib.sha256(json.dumps(result, sort_keys=True, separators=(",", ":")).encode()).hexdigest(), "created_epoch": int(time.time())}
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
    if len(encoded) > MAX_ENTRY_BYTES: raise ValueError("cache entry exceeds serialized-byte cap")
    descriptor = _open_root(root, create=True)
    temporary: str | None = None
    try:
        name = _entry_name(cache_key)
        try: existing = os.stat(name, dir_fd=descriptor, follow_symlinks=False)
        except FileNotFoundError: existing = None
        if existing is not None and not stat.S_ISREG(existing.st_mode): raise ValueError("cache entry cannot be a symlink or non-regular file")
        _race("before-store-write", root)
        _verify_root(root, descriptor)
        temporary = f".{name}.{secrets.token_hex(16)}.tmp"
        handle = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=descriptor)
        try:
            remaining = memoryview(encoded)
            while remaining:
                written = os.write(handle, remaining)
                if written <= 0: raise OSError("cache temporary write did not advance")
                remaining = remaining[written:]
            os.fsync(handle)
        finally:
            os.close(handle)
        _race("before-store-replace", root)
        _verify_root(root, descriptor)
        # os.replace is descriptor-relative and replaces a raced-in symlink itself; it never follows its target.
        os.replace(temporary, name, src_dir_fd=descriptor, dst_dir_fd=descriptor)
        temporary = None
    finally:
        if temporary is not None:
            try: os.unlink(temporary, dir_fd=descriptor)
            except FileNotFoundError: pass
        os.close(descriptor)


def prune(root: Path, maximum_entries: int, maximum_bytes: int) -> None:
    if type(maximum_entries) is not int or type(maximum_bytes) is not int or maximum_entries < 0 or maximum_bytes < 0: raise ValueError("cache budgets must be nonnegative integers")
    if root.is_symlink(): raise ValueError("cache root cannot be a symlink")
    if not root.exists(): return
    descriptor = _open_root(root, create=False)
    try:
        _race("before-prune-list", root)
        _verify_root(root, descriptor)
        files: list[tuple[str, os.stat_result]] = []
        for name in os.listdir(descriptor):
            if not name.endswith(".json"): continue
            entry = os.stat(name, dir_fd=descriptor, follow_symlinks=False)
            if not stat.S_ISREG(entry.st_mode): raise ValueError("cache entry cannot be a symlink or non-regular file")
            files.append((name, entry))
        files.sort(key=lambda item: item[1].st_mtime, reverse=True)
        total = 0
        for index, (name, entry) in enumerate(files):
            if index >= maximum_entries or total + entry.st_size > maximum_bytes:
                _race("before-prune-unlink", root)
                _verify_root(root, descriptor)
                current = os.stat(name, dir_fd=descriptor, follow_symlinks=False)
                if not stat.S_ISREG(current.st_mode): raise ValueError("cache entry cannot be a symlink or non-regular file")
                os.unlink(name, dir_fd=descriptor)
            else: total += entry.st_size
    finally:
        os.close(descriptor)


def main() -> int:
    parser = argparse.ArgumentParser(); parser.add_argument("root", type=Path); parser.add_argument("--prune", action="store_true"); parser.add_argument("--entries", type=int, default=256); parser.add_argument("--bytes", type=int, default=16 * 1024 * 1024)
    args = parser.parse_args()
    if args.prune: prune(args.root, args.entries, args.bytes)
    return 0


if __name__ == "__main__": raise SystemExit(main())

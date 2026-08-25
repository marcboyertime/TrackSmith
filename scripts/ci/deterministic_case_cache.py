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
ENTRY = re.compile(r"^[0-9a-f]{64}\.json$")
TEMPORARY = re.compile(r"^\.([0-9a-f]{64})\.json\.[0-9a-f]{32}\.tmp$")
INDEX = ".tracksmith-deterministic-case-cache-index-v1.json"
INDEX_TEMPORARY = re.compile(r"^\.tracksmith-deterministic-case-cache-index-v1\.[0-9a-f]{32}\.tmp$")
INDEX_FIELDS = {"schema_version", "entry_keys"}
# Test-only deterministic interleaving point. Production leaves this unset.
RACE_HOOK: Callable[[str, Path], None] | None = None


def key(components: dict[str, str]) -> str:
    if set(components) != COMPONENT_KEYS or not all(isinstance(value, str) for value in components.values()) or not CASE_ID.fullmatch(components["suite_id"]) or not CASE_ID.fullmatch(components["suite_version"]) or not CASE_ID.fullmatch(components["case_id"]) or any(not HASH.fullmatch(components[name]) for name in COMPONENT_KEYS - {"suite_id", "suite_version", "case_id"}):
        raise ValueError("components must use the exact compact deterministic schema")
    return hashlib.sha256(json.dumps(components, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def path_for(root: Path, cache_key: str) -> Path: return root / f"{cache_key}.json"


def _entry_name(cache_key: str) -> str: return f"{cache_key}.json"


def _index_payload(keys: set[str]) -> bytes:
    return json.dumps({"schema_version": SCHEMA, "entry_keys": sorted(keys)}, sort_keys=True, separators=(",", ":")).encode()


def _race(point: str, root: Path) -> None:
    if RACE_HOOK is not None: RACE_HOOK(point, root)


def _canonical_root(root: Path) -> Path:
    """Reject caller-controlled links before resolving stable macOS system aliases."""
    if ".." in root.parts:
        raise ValueError("cache root cannot contain traversal components")
    raw = root.absolute()
    if raw.is_symlink(): raise ValueError("cache root cannot be a symlink")
    # /tmp, /var, and /etc are macOS-provided aliases into /private. Permit
    # only those top-level compatibility aliases; all other parent components
    # supplied by a cache caller must name directories directly.
    allowed_aliases = {Path("/tmp"), Path("/var"), Path("/etc")}
    current = Path(raw.anchor)
    for component in raw.parts[1:-1]:
        current /= component
        if current.is_symlink() and current not in allowed_aliases:
            raise ValueError("cache root parent components cannot be symlinks")
    try: return raw.resolve(strict=False)
    except OSError as error: raise ValueError("cache root parent components are unsafe") from error


def _open_root(root: Path, create: bool) -> int:
    if not hasattr(os, "O_NOFOLLOW"): raise ValueError("cache root requires O_NOFOLLOW support")
    flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | os.O_NOFOLLOW
    descriptor = os.open(root.anchor, flags)
    try:
        for component in root.parts[1:]:
            try: child = os.open(component, flags, dir_fd=descriptor)
            except FileNotFoundError:
                if not create: raise
                os.mkdir(component, mode=0o700, dir_fd=descriptor)
                child = os.open(component, flags, dir_fd=descriptor)
            os.close(descriptor)
            descriptor = child
    except OSError as error:
        os.close(descriptor)
        raise ValueError("cache root cannot be opened without following links") from error
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
    if not stat.S_ISREG(os.fstat(entry).st_mode) or os.fstat(entry).st_size > MAX_ENTRY_BYTES:
        os.close(entry); return None
    _race("after-entry-open", root)
    return entry


def _read_index(root: Path, descriptor: int) -> set[str] | None:
    entry = _open_regular(INDEX, root, descriptor)
    if entry is None: return None
    try:
        with os.fdopen(entry, "rb") as handle:
            encoded = handle.read(MAX_ENTRY_BYTES + 1)
        value = json.loads(encoded)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        raise ValueError("cache ownership index is corrupt") from error
    keys = value.get("entry_keys") if isinstance(value, dict) else None
    if set(value) != INDEX_FIELDS or value.get("schema_version") != SCHEMA or not isinstance(keys, list) or keys != sorted(set(keys)) or any(not isinstance(item, str) or not HASH.fullmatch(item) for item in keys):
        raise ValueError("cache ownership index is invalid")
    return set(keys)


def _replace_bytes(descriptor: int, name: str, encoded: bytes, prefix: str) -> None:
    temporary = f".{prefix}.{secrets.token_hex(16)}.tmp"
    handle = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=descriptor)
    try:
        remaining = memoryview(encoded)
        while remaining:
            written = os.write(handle, remaining)
            if written <= 0: raise OSError("atomic cache write did not advance")
            remaining = remaining[written:]
        os.fsync(handle)
    finally:
        os.close(handle)
    try: os.replace(temporary, name, src_dir_fd=descriptor, dst_dir_fd=descriptor)
    except BaseException:
        try: os.unlink(temporary, dir_fd=descriptor)
        except FileNotFoundError: pass
        raise


def _write_index(descriptor: int, keys: set[str]) -> None:
    _replace_bytes(descriptor, INDEX, _index_payload(keys), "tracksmith-deterministic-case-cache-index-v1")


def _valid_payload(value: Any, expected_key: str | None = None) -> dict[str, Any] | None:
    if not isinstance(value, dict) or set(value) != {"schema_version", "components", "result", "result_hash", "created_epoch"} or value.get("schema_version") != SCHEMA or type(value.get("created_epoch")) is not int or value["created_epoch"] < 0:
        return None
    components, result = value.get("components"), value.get("result")
    try: derived_key = key(components)
    except ValueError: return None
    if expected_key is not None and derived_key != expected_key: return None
    if not isinstance(result, dict) or set(result) != RESULT_KEYS or result.get("outcome") != "passed" or result.get("case_id") != components["case_id"] or result.get("semantic_input_hash") != components["semantic_input_hash"] or result.get("result_hash") != hashlib.sha256(f"{result['case_id']}|passed|{result['semantic_input_hash']}".encode()).hexdigest(): return None
    if value.get("result_hash") != hashlib.sha256(json.dumps(result, sort_keys=True, separators=(",", ":")).encode()).hexdigest(): return None
    return result


def load(root: Path, components: dict[str, str]) -> dict[str, Any] | None:
    cache_key = key(components)
    try:
        root = _canonical_root(root)
        descriptor = _open_root(root, create=False)
    except ValueError: return None
    try:
        entry = _open_regular(_entry_name(cache_key), root, descriptor)
        if entry is None: return None
        with os.fdopen(entry, "rb") as handle:
            encoded = handle.read(MAX_ENTRY_BYTES + 1)
            if len(encoded) > MAX_ENTRY_BYTES: return None
            value = json.loads(encoded)
    except (OSError, ValueError, json.JSONDecodeError): return None
    finally:
        os.close(descriptor)
    if value.get("components") != components: return None
    return _valid_payload(value, cache_key)


def store(root: Path, components: dict[str, str], result: dict[str, Any]) -> None:
    cache_key = key(components)
    if set(result) != RESULT_KEYS or result.get("outcome") != "passed" or result.get("case_id") != components["case_id"] or result.get("semantic_input_hash") != components["semantic_input_hash"] or result.get("result_hash") != hashlib.sha256(f"{components['case_id']}|passed|{components['semantic_input_hash']}".encode()).hexdigest(): raise ValueError("result must use the exact compact passed-case schema")
    payload = {"schema_version": SCHEMA, "components": components, "result": result, "result_hash": hashlib.sha256(json.dumps(result, sort_keys=True, separators=(",", ":")).encode()).hexdigest(), "created_epoch": int(time.time())}
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
    if len(encoded) > MAX_ENTRY_BYTES: raise ValueError("cache entry exceeds serialized-byte cap")
    root = _canonical_root(root)
    descriptor = _open_root(root, create=True)
    temporary: str | None = None
    try:
        name = _entry_name(cache_key)
        owned = _read_index(root, descriptor)
        if owned is None: owned = set()
        if cache_key not in owned:
            owned.add(cache_key)
            _verify_root(root, descriptor)
            _write_index(descriptor, owned)
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
    root = _canonical_root(root)
    if not root.exists(): return
    descriptor = _open_root(root, create=False)
    try:
        _race("before-prune-list", root)
        _verify_root(root, descriptor)
        owned = _read_index(root, descriptor)
        # Pruning never establishes ownership: an unmarked directory may hold
        # user data that merely resembles a cache filename.
        if owned is None: return
        files: list[tuple[str, os.stat_result]] = []
        for name in os.listdir(descriptor):
            temporary = TEMPORARY.fullmatch(name)
            if temporary and temporary.group(1) in owned:
                entry = os.stat(name, dir_fd=descriptor, follow_symlinks=False)
                if stat.S_ISREG(entry.st_mode):
                    _verify_root(root, descriptor)
                    os.unlink(name, dir_fd=descriptor)
                continue
            if not ENTRY.fullmatch(name) or name[:-5] not in owned: continue
            entry = os.stat(name, dir_fd=descriptor, follow_symlinks=False)
            if not stat.S_ISREG(entry.st_mode): continue
            opened = _open_regular(name, root, descriptor)
            if opened is None: continue
            try:
                with os.fdopen(opened, "rb") as handle: payload = json.loads(handle.read(MAX_ENTRY_BYTES + 1))
            except (OSError, ValueError, json.JSONDecodeError): continue
            if _valid_payload(payload, name[:-5]) is not None:
                files.append((name, entry))
        files.sort(key=lambda item: item[1].st_mtime, reverse=True)
        total = 0
        removed: set[str] = set()
        for index, (name, entry) in enumerate(files):
            current = os.stat(name, dir_fd=descriptor, follow_symlinks=False)
            if not stat.S_ISREG(current.st_mode): raise ValueError("cache entry cannot be a symlink or non-regular file")
            if index >= maximum_entries or total + current.st_size > maximum_bytes:
                _race("before-prune-unlink", root)
                _verify_root(root, descriptor)
                current = os.stat(name, dir_fd=descriptor, follow_symlinks=False)
                if not stat.S_ISREG(current.st_mode): raise ValueError("cache entry cannot be a symlink or non-regular file")
                os.unlink(name, dir_fd=descriptor)
                removed.add(name[:-5])
            else: total += current.st_size
        if removed:
            _verify_root(root, descriptor)
            _write_index(descriptor, owned - removed)
    finally:
        os.close(descriptor)


def main() -> int:
    parser = argparse.ArgumentParser(); parser.add_argument("root", type=Path); parser.add_argument("--prune", action="store_true"); parser.add_argument("--entries", type=int, default=256); parser.add_argument("--bytes", type=int, default=16 * 1024 * 1024)
    args = parser.parse_args()
    if args.prune: prune(args.root, args.entries, args.bytes)
    return 0


if __name__ == "__main__": raise SystemExit(main())

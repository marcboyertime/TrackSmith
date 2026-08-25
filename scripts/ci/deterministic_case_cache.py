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
INDEX_FIELDS = {"schema_version", "entry_keys", "temporary_entries"}
# Test-only deterministic interleaving point. Production leaves this unset.
RACE_HOOK: Callable[[str, Path], None] | None = None


def key(components: dict[str, str]) -> str:
    if set(components) != COMPONENT_KEYS or not all(isinstance(value, str) for value in components.values()) or not CASE_ID.fullmatch(components["suite_id"]) or not CASE_ID.fullmatch(components["suite_version"]) or not CASE_ID.fullmatch(components["case_id"]) or any(not HASH.fullmatch(components[name]) for name in COMPONENT_KEYS - {"suite_id", "suite_version", "case_id"}):
        raise ValueError("components must use the exact compact deterministic schema")
    return hashlib.sha256(json.dumps(components, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def path_for(root: Path, cache_key: str) -> Path: return root / f"{cache_key}.json"


def _entry_name(cache_key: str) -> str: return f"{cache_key}.json"


def _index_payload(keys: set[str], temporary_entries: dict[str, tuple[int, int, int, int]]) -> bytes:
    return json.dumps({"schema_version": SCHEMA, "entry_keys": sorted(keys), "temporary_entries": {name: list(identity) for name, identity in sorted(temporary_entries.items())}}, sort_keys=True, separators=(",", ":")).encode()


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


def _read_index(root: Path, descriptor: int) -> tuple[set[str], dict[str, tuple[int, int, int, int]]] | None:
    entry = _open_regular(INDEX, root, descriptor)
    if entry is None: return None
    try:
        with os.fdopen(entry, "rb") as handle:
            encoded = handle.read(MAX_ENTRY_BYTES + 1)
        value = json.loads(encoded)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        raise ValueError("cache ownership index is corrupt") from error
    keys = value.get("entry_keys") if isinstance(value, dict) else None
    temporary_entries = value.get("temporary_entries") if isinstance(value, dict) else None
    if set(value) != INDEX_FIELDS or value.get("schema_version") != SCHEMA or not isinstance(keys, list) or keys != sorted(set(keys)) or any(not isinstance(item, str) or not HASH.fullmatch(item) for item in keys) or not isinstance(temporary_entries, dict) or any(not isinstance(name, str) or not TEMPORARY.fullmatch(name) or TEMPORARY.fullmatch(name).group(1) not in keys or not isinstance(identity, list) or len(identity) != 4 or any(type(item) is not int or item < 0 for item in identity) for name, identity in temporary_entries.items()):
        raise ValueError("cache ownership index is invalid")
    return set(keys), {name: tuple(identity) for name, identity in temporary_entries.items()}


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


def _write_index(descriptor: int, keys: set[str], temporary_entries: dict[str, tuple[int, int, int, int]]) -> None:
    _replace_bytes(descriptor, INDEX, _index_payload(keys, temporary_entries), "tracksmith-deterministic-case-cache-index-v1")


def _identity(entry: os.stat_result) -> tuple[int, int, int, int]:
    return entry.st_dev, entry.st_ino, entry.st_size, entry.st_mtime_ns


def _unlink_owned_regular(name: str, root: Path, descriptor: int, expected: tuple[int, int, int, int]) -> None:
    """Delete only the inode we inspected, never a raced replacement.

    POSIX has no unlink-if-inode primitive.  Retire cache bytes through a held
    no-follow descriptor instead of unlinking a pathname: a later rename or
    replacement cannot redirect ftruncate to a user file.  The zero-byte,
    now-unowned name is harmless and is deliberately never name-deleted.
    """
    _race("before-prune-unlink", root)
    _verify_root(root, descriptor)
    handle = os.open(name, os.O_RDWR | os.O_NOFOLLOW, dir_fd=descriptor)
    try:
        current = os.fstat(handle)
        if not stat.S_ISREG(current.st_mode) or _identity(current) != expected: raise ValueError("cache entry changed while pruning")
        _race("after-prune-verify", root)
        _race("before-prune-quarantine-unlink", root)
        os.ftruncate(handle, 0); os.fsync(handle)
    finally: os.close(handle)


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
    handle: int | None = None
    try:
        name = _entry_name(cache_key)
        try: existing = os.stat(name, dir_fd=descriptor, follow_symlinks=False)
        except FileNotFoundError: existing = None
        if existing is not None and not stat.S_ISREG(existing.st_mode): raise ValueError("cache entry cannot be a symlink or non-regular file")
        index = _read_index(root, descriptor)
        owned, temporary_entries = index if index is not None else (set(), {})
        if existing is not None and cache_key not in owned:
            raise ValueError("cache entry is not owned by this cache index")
        _race("before-store-write", root)
        _verify_root(root, descriptor)
        temporary = f".{name}.{secrets.token_hex(16)}.tmp"
        # Create first, then record the descriptor-created inode.  A failed
        # O_EXCL open must never turn a raced-in user filename into an indexed
        # temporary that cleanup would unlink.
        handle = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=descriptor)
        created_identity = _identity(os.fstat(handle))
        _race("after-store-temp-open", root)
        current = os.stat(temporary, dir_fd=descriptor, follow_symlinks=False)
        if not stat.S_ISREG(current.st_mode) or _identity(current) != created_identity: raise ValueError("cache temporary changed before ownership recording")
        owned.add(cache_key); temporary_entries[temporary] = created_identity
        _write_index(descriptor, owned, temporary_entries)
        try:
            remaining = memoryview(encoded)
            while remaining:
                written = os.write(handle, remaining)
                if written <= 0: raise OSError("cache temporary write did not advance")
                remaining = remaining[written:]
            os.fsync(handle)
        finally:
            os.close(handle); handle = None
        completed_identity = _identity(os.stat(temporary, dir_fd=descriptor, follow_symlinks=False))
        if completed_identity[:2] != created_identity[:2]: raise ValueError("cache temporary changed while writing")
        temporary_entries[temporary] = completed_identity
        _write_index(descriptor, owned, temporary_entries)
        _race("before-store-replace", root)
        _verify_root(root, descriptor)
        current = os.stat(temporary, dir_fd=descriptor, follow_symlinks=False)
        if not stat.S_ISREG(current.st_mode) or _identity(current) != completed_identity: raise ValueError("cache temporary changed before replacement")
        retired_handle: int | None = None
        if existing is not None:
            expected_existing = _identity(existing)
            retired = f".{name}.{secrets.token_hex(16)}.retired"
            os.rename(name, retired, src_dir_fd=descriptor, dst_dir_fd=descriptor)
            try: retired_handle = os.open(retired, os.O_RDWR | os.O_NOFOLLOW, dir_fd=descriptor)
            except OSError as error:
                try: os.link(retired, name, src_dir_fd=descriptor, dst_dir_fd=descriptor, follow_symlinks=False)
                except FileExistsError: pass
                raise ValueError("cache target changed before replacement") from error
            moved = os.fstat(retired_handle)
            if not stat.S_ISREG(moved.st_mode) or _identity(moved) != expected_existing:
                try: os.link(retired, name, src_dir_fd=descriptor, dst_dir_fd=descriptor, follow_symlinks=False)
                except FileExistsError: pass
                os.close(retired_handle); retired_handle = None
                raise ValueError("cache target changed before replacement")
        try:
            # Link is atomic no-replace.  A new user target makes store fail
            # rather than being overwritten; leave the verified temp indexed
            # for a later descriptor-safe retirement.
            _race("before-store-target-install", root)
            try: os.link(temporary, name, src_dir_fd=descriptor, dst_dir_fd=descriptor, follow_symlinks=False)
            except FileExistsError as error: raise ValueError("cache target appeared before replacement") from error
        finally:
            if retired_handle is not None:
                os.ftruncate(retired_handle, 0); os.fsync(retired_handle); os.close(retired_handle)
        # The installed entry and its original temporary name are hard links to
        # the same verified inode. Keep that temporary indexed: it is cache
        # owned, and prune recognises the shared inode before retiring the live
        # entry. Forgetting it would leave an untracked hardlink behind.
        temporary = None
        _verify_root(root, descriptor)
        _write_index(descriptor, owned, temporary_entries)
    finally:
        if handle is not None: os.close(handle)
        # Never unlink a failure-path temporary by name.  It may have been
        # replaced after an O_EXCL open; orphaned cache bytes are safer than a
        # user-file deletion and are not trusted on subsequent pruning.
        os.close(descriptor)


def prune(root: Path, maximum_entries: int, maximum_bytes: int) -> None:
    if type(maximum_entries) is not int or type(maximum_bytes) is not int or maximum_entries < 0 or maximum_bytes < 0: raise ValueError("cache budgets must be nonnegative integers")
    root = _canonical_root(root)
    if not root.exists(): return
    descriptor = _open_root(root, create=False)
    try:
        _race("before-prune-list", root)
        _verify_root(root, descriptor)
        index = _read_index(root, descriptor)
        # Pruning never establishes ownership: an unmarked directory may hold
        # user data that merely resembles a cache filename.
        if index is None: return
        owned, temporary_entries = index
        files: list[tuple[str, tuple[int, int, int, int]]] = []
        index_changed = False
        for name in os.listdir(descriptor):
            temporary = TEMPORARY.fullmatch(name)
            if temporary and name in temporary_entries:
                entry = os.stat(name, dir_fd=descriptor, follow_symlinks=False)
                expected = temporary_entries[name]
                target_name = _entry_name(temporary.group(1))
                try: target = os.stat(target_name, dir_fd=descriptor, follow_symlinks=False)
                except FileNotFoundError: target = None
                # A just-installed target shares this inode with its indexed
                # temporary. Retire through the target path below exactly once;
                # truncating the temporary first would invalidate its identity.
                if target is not None and stat.S_ISREG(target.st_mode) and _identity(target)[:2] == _identity(entry)[:2]:
                    continue
                temporary_entries.pop(name); index_changed = True
                if stat.S_ISREG(entry.st_mode) and _identity(entry) == expected:
                    _unlink_owned_regular(name, root, descriptor, expected)
                continue
            if not ENTRY.fullmatch(name) or name[:-5] not in owned: continue
            entry = os.stat(name, dir_fd=descriptor, follow_symlinks=False)
            if not stat.S_ISREG(entry.st_mode): continue
            opened = _open_regular(name, root, descriptor)
            if opened is None: continue
            try:
                with os.fdopen(opened, "rb") as handle:
                    payload = json.loads(handle.read(MAX_ENTRY_BYTES + 1))
                    identity = _identity(os.fstat(handle.fileno()))
            except (OSError, ValueError, json.JSONDecodeError): continue
            if _valid_payload(payload, name[:-5]) is not None:
                files.append((name, identity))
        files.sort(key=lambda item: item[1][3], reverse=True)
        total = 0
        for index, (name, identity) in enumerate(files):
            current = os.stat(name, dir_fd=descriptor, follow_symlinks=False)
            if not stat.S_ISREG(current.st_mode) or _identity(current) != identity: raise ValueError("cache entry changed while pruning")
            if index >= maximum_entries or total + current.st_size > maximum_bytes:
                _unlink_owned_regular(name, root, descriptor, identity)
            else: total += current.st_size
        if index_changed:
            _verify_root(root, descriptor)
            _write_index(descriptor, owned, temporary_entries)
    finally:
        os.close(descriptor)


def main() -> int:
    parser = argparse.ArgumentParser(); parser.add_argument("root", type=Path); parser.add_argument("--prune", action="store_true"); parser.add_argument("--entries", type=int, default=256); parser.add_argument("--bytes", type=int, default=16 * 1024 * 1024)
    args = parser.parse_args()
    if args.prune: prune(args.root, args.entries, args.bytes)
    return 0


if __name__ == "__main__": raise SystemExit(main())

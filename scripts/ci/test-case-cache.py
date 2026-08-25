#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import os
import tempfile
from pathlib import Path

import deterministic_case_cache as cache


def rejected(action, label: str) -> None:
    try: action()
    except ValueError: return
    raise AssertionError(label)


def with_race(point: str, callback, action):
    def hook(actual: str, root: Path) -> None:
        if actual == point: callback(root)
    cache.RACE_HOOK = hook
    try: return action()
    finally: cache.RACE_HOOK = None


def replace_root(root: Path, outside: Path) -> Path:
    original = root.with_name(root.name + "-opened")
    root.rename(original)
    root.symlink_to(outside, target_is_directory=True)
    return original


def restore_root(root: Path, original: Path) -> None:
    root.unlink()
    original.rename(root)


def main() -> None:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        h = lambda value: hashlib.sha256(value.encode()).hexdigest()
        components = {"suite_id": "suite", "suite_version": "1", "source_hash": h("source"), "policy_hash": h("policy"), "index_hash": h("index"), "toolchain_hash": h("toolchain"), "case_id": "case/1", "semantic_input_hash": h("semantic")}
        result = {"case_id": components["case_id"], "semantic_input_hash": components["semantic_input_hash"], "outcome": "passed", "result_hash": h(f"{components['case_id']}|passed|{components['semantic_input_hash']}")}
        cache_key = cache.key(components); entry = cache.path_for(root, cache_key)
        outside = root.parent / (root.name + "-outside"); outside.mkdir()
        sentinel = outside / "sentinel"; sentinel.write_text("outside unchanged")
        unowned = root / "unowned"; unowned.mkdir()
        unowned_hex = unowned / ("d" * 64 + ".json"); unowned_hex.write_text("user sentinel")
        cache.prune(unowned, 0, 0)
        assert unowned_hex.read_text() == "user sentinel" and not (unowned / cache.INDEX).exists()
        unowned_hex.unlink(); unowned.rmdir()
        assert cache.load(root, components) is None
        entry.write_text("unindexed user entry")
        rejected(lambda: cache.store(root, components, result), "unindexed regular cache entry was overwritten")
        assert entry.read_text() == "unindexed user entry"; entry.unlink()
        cache.store(root, components, result); assert cache.load(root, components) == result
        assert cache.load(root, {**components, "toolchain_hash": h("changed")}) is None
        entry.write_text("{"); assert cache.load(root, components) is None
        entry.write_bytes(b"x" * (cache.MAX_ENTRY_BYTES + 1)); assert cache.load(root, components) is None
        cache.store(root, components, result); payload = json.loads(entry.read_text()); payload["components"]["source_hash"] = h("stale"); entry.write_text(json.dumps(payload)); assert cache.load(root, components) is None
        for timestamp in (True, False):
            cache.store(root, components, result); payload = json.loads(entry.read_text()); payload["created_epoch"] = timestamp; entry.write_text(json.dumps(payload)); assert cache.load(root, components) is None
        rejected(lambda: cache.store(root, components, {"outcome": "failed"}), "failure was cached")
        rejected(lambda: cache.store(root, components, {"outcome": "passed", "value": "x" * 300_000}), "oversized result was cached")
        rejected(lambda: cache.store(root, {**components, "provider_response": h("no")}, result), "unknown/provider-shaped component accepted")
        for forbidden_key in ("credential", "audio_blob", "prose", "provider_response"):
            rejected(lambda key=forbidden_key: cache.store(root, components, {**result, key: {"text": "arbitrary private content"}}), f"{forbidden_key} result accepted")
        for entries, bytes_ in ((True, 1), (False, 1), (1, True), (1, False)):
            rejected(lambda entries=entries, bytes_=bytes_: cache.prune(root, entries, bytes_), "Boolean prune budget accepted")
        symlink_root = root / "cache-link"; symlink_root.symlink_to(outside, target_is_directory=True)
        rejected(lambda: cache.store(symlink_root, components, result), "symlink cache root accepted")
        rejected(lambda: cache.prune(symlink_root, 0, 0), "symlink prune root accepted")
        symlink_root.unlink()
        parent_link = root / "cache-parent-link"; parent_link.symlink_to(outside, target_is_directory=True)
        rejected(lambda: cache.store(parent_link / "nested", components, result), "symlink cache parent accepted")
        assert not (outside / "nested").exists() and sentinel.read_text() == "outside unchanged"
        parent_link.unlink()
        for traversal in (root / ".." / outside.name, root / "nested" / ".." / outside.name):
            assert cache.load(traversal, components) is None
            rejected(lambda traversal=traversal: cache.store(traversal, components, result), "traversal cache root accepted")
            rejected(lambda traversal=traversal: cache.prune(traversal, 0, 0), "traversal prune root accepted")
        assert sentinel.read_text() == "outside unchanged"
        cache.store(root, components, result); entry.unlink(); entry.symlink_to(sentinel)
        rejected(lambda: cache.store(root, components, result), "pre-existing cache entry symlink accepted")
        assert sentinel.read_text() == "outside unchanged" and cache.load(root, components) is None
        entry.unlink()
        cache.store(root, components, result)
        def leaf_for_load(_: Path) -> None: entry.unlink(); entry.symlink_to(sentinel)
        assert with_race("before-entry-open", leaf_for_load, lambda: cache.load(root, components)) is None
        assert sentinel.read_text() == "outside unchanged"; entry.unlink()
        cache.store(root, components, result)
        def grow_during_read(_: Path) -> None:
            with entry.open("ab") as handle: handle.write(b"x" * cache.MAX_ENTRY_BYTES)
        assert with_race("after-entry-open", grow_during_read, lambda: cache.load(root, components)) is None
        cache.store(root, components, result)
        def temporary_for_store(current: Path) -> None:
            assert cache.RACE_TARGET_NAME is not None and cache.TEMPORARY.fullmatch(cache.RACE_TARGET_NAME)
            temporary_path = current / cache.RACE_TARGET_NAME
            temporary_path.unlink(); temporary_path.write_text("user temporary sentinel")
        rejected(lambda: with_race("after-store-temp-open", temporary_for_store, lambda: cache.store(root, components, result)), "raced temporary sentinel was accepted")
        temporary_sentinel = next(item for item in root.iterdir() if cache.TEMPORARY.fullmatch(item.name) and item.read_text() == "user temporary sentinel")
        assert temporary_sentinel.read_text() == "user temporary sentinel"; temporary_sentinel.unlink()
        def leaf_for_store(_: Path) -> None: entry.unlink(); entry.symlink_to(sentinel)
        rejected(lambda: with_race("before-store-replace", leaf_for_store, lambda: cache.store(root, components, result)), "raced store target symlink accepted")
        assert sentinel.read_text() == "outside unchanged"; entry.unlink(); cache.store(root, components, result)
        def target_for_store(_: Path) -> None: entry.write_text("user target sentinel")
        rejected(lambda: with_race("before-store-target-install", target_for_store, lambda: cache.store(root, components, result)), "raced store target was overwritten")
        assert entry.read_text() == "user target sentinel"; entry.unlink(); cache.store(root, components, result)
        entry.unlink(); cache.store(root, components, result)
        descriptor = cache._open_root(cache._canonical_root(root), create=False)
        try:
            expected = cache._identity(entry.stat())
            def late_prune_replacement(_: Path) -> None: entry.unlink(); entry.write_text("late user replacement")
            with_race("before-prune-quarantine-unlink", late_prune_replacement, lambda: cache._unlink_owned_regular(entry.name, root, descriptor, expected))
        finally: os.close(descriptor)
        assert entry.read_text() == "late user replacement"; entry.unlink(); cache.store(root, components, result)
        cache.store(root, components, result); original: Path | None = None
        def root_for_load(current: Path) -> None:
            nonlocal original
            original = replace_root(current, outside)
        try: assert with_race("before-entry-open", root_for_load, lambda: cache.load(root, components)) is None
        finally:
            if original is not None: restore_root(root, original)
        assert sentinel.read_text() == "outside unchanged"
        original = None
        def root_for_store(current: Path) -> None:
            nonlocal original
            original = replace_root(current, outside)
        rejected(lambda: with_race("before-store-write", root_for_store, lambda: cache.store(root, components, result)), "raced store root accepted")
        assert original is not None; restore_root(root, original); assert sentinel.read_text() == "outside unchanged"
        cache.store(root, components, result); original = None
        def root_for_prune(current: Path) -> None:
            nonlocal original
            original = replace_root(current, outside)
        rejected(lambda: with_race("before-prune-list", root_for_prune, lambda: cache.prune(root, 0, 0)), "raced prune root accepted")
        assert original is not None; restore_root(root, original); assert sentinel.read_text() == "outside unchanged"
        prune_root = root / "prune-owned"
        cache.store(prune_root, components, result)
        prune_entry = cache.path_for(prune_root, cache.key(components))
        cache.prune(prune_root, 0, 0); assert prune_entry.stat().st_size == 0
        cache.store(prune_root, components, result); assert cache.load(prune_root, components) == result
        sentinel.unlink(); outside.rmdir()
    print("test-case-cache: schema, corruption, stale/toolchain, failure, bounded cache, and descriptor-relative symlink/root races passed")


if __name__ == "__main__": main()

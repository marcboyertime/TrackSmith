#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json, tempfile
from pathlib import Path
from deterministic_case_cache import load, path_for, prune, store

def main() -> None:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory); h=lambda value: hashlib.sha256(value.encode()).hexdigest(); components = {"suite_id": "suite", "suite_version": "1", "source_hash": h("source"), "policy_hash": h("policy"), "index_hash": h("index"), "toolchain_hash": h("toolchain"), "case_id": "case/1", "semantic_input_hash": h("semantic")}; result = {"case_id": components["case_id"], "semantic_input_hash": components["semantic_input_hash"], "outcome": "passed", "result_hash": h(f"{components['case_id']}|passed|{components['semantic_input_hash']}")}
        assert load(root, components) is None
        store(root, components, result); assert load(root, components) == result
        assert load(root, {**components, "toolchain_hash": h("changed")}) is None
        corrupt = path_for(root, __import__("deterministic_case_cache").key(components)); corrupt.write_text("{")
        assert load(root, components) is None
        store(root, components, result); payload = json.loads(corrupt.read_text()); payload["components"]["source_hash"] = h("stale"); corrupt.write_text(json.dumps(payload)); assert load(root, components) is None
        try: store(root, components, {"outcome": "failed"}); raise AssertionError("failure was cached")
        except ValueError: pass
        try: store(root, components, {"outcome": "passed", "value": "x" * 300_000}); raise AssertionError("oversized result was cached")
        except ValueError: pass
        try: store(root, {**components, "provider_response": h("no")}, result); raise AssertionError("unknown/provider-shaped component accepted")
        except ValueError: pass
        for forbidden_key in ("credential", "audio_blob", "prose", "provider_response"):
            try: store(root, components, {**result, forbidden_key: {"text": "arbitrary private content"}}); raise AssertionError(f"{forbidden_key} result accepted")
            except ValueError: pass
        symlink_root = root / "cache-link"; symlink_root.symlink_to(root, target_is_directory=True)
        try: store(symlink_root, components, result); raise AssertionError("symlink cache root accepted")
        except ValueError: pass
        symlink_root.unlink()
        store(root, components, result); cache_entry = path_for(root, __import__("deterministic_case_cache").key(components)); cache_entry.unlink(); cache_entry.symlink_to(root / "missing-target")
        assert load(root, components) is None
        try: prune(root, 1, 1024); raise AssertionError("symlink cache entry accepted")
        except ValueError: pass
        cache_entry.unlink()
        store(root, components, result); prune(root, 0, 0); assert not list(root.iterdir())
    print("test-case-cache: schema, corruption, stale/toolchain, failure, oversized, and byte/count pruning passed")
if __name__ == "__main__": main()

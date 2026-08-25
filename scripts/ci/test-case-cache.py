#!/usr/bin/env python3
from __future__ import annotations
import json, tempfile
from pathlib import Path
from deterministic_case_cache import load, path_for, prune, store

def main() -> None:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory); components = {"suite": "s", "source": "h", "toolchain": "t"}; result = {"outcome": "passed", "value": "42"}
        assert load(root, components) is None
        store(root, components, result); assert load(root, components) == result
        assert load(root, {**components, "toolchain": "changed"}) is None
        corrupt = path_for(root, __import__("deterministic_case_cache").key(components)); corrupt.write_text("{")
        assert load(root, components) is None
        store(root, components, result); payload = json.loads(corrupt.read_text()); payload["components"]["source"] = "stale"; corrupt.write_text(json.dumps(payload)); assert load(root, components) is None
        try: store(root, components, {"outcome": "failed"}); raise AssertionError("failure was cached")
        except ValueError: pass
        try: store(root, components, {"outcome": "passed", "value": "x" * 300_000}); raise AssertionError("oversized result was cached")
        except ValueError: pass
        store(root, components, result); prune(root, 0, 0); assert not list(root.iterdir())
    print("test-case-cache: schema, corruption, stale/toolchain, failure, oversized, and byte/count pruning passed")
if __name__ == "__main__": main()

#!/usr/bin/env python3
"""Hash-ledger every retained artifact in one Logic-native empirical run."""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib


def digest(path: pathlib.Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()


def role(path: pathlib.Path) -> str:
    name = path.name.lower()
    if path.suffix.lower() == ".zip" and ".logicx" in name:
        return "closed disposable Logic project archive"
    if path.suffix.lower() == ".png":
        return "direct Logic UI state evidence"
    if name.startswith("source-") and path.suffix.lower() == ".wav":
        return "immutable deterministic source fixture"
    if "manifest" in name and path.suffix.lower() == ".json":
        return "deterministic fixture identity manifest"
    if name.endswith("analysis.json") or name.endswith(".analysis.json"):
        return "objective signal-analysis artifact"
    if path.suffix.lower() == ".wav":
        return "retained direct Logic render, including accepted and rejected attempts"
    return "retained empirical-run artifact"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("run_directory", type=pathlib.Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = args.run_directory.resolve()
    run_path = root / "run.json"
    record = json.loads(run_path.read_text(encoding="utf-8"))
    artifacts = []
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path == run_path or path.name == ".DS_Store":
            continue
        artifacts.append(
            {
                "path": str(path.relative_to(root)),
                "sha256": digest(path),
                "role": role(path),
            }
        )
    if not artifacts:
        raise SystemExit(f"no retained artifacts under {root}")
    record["artifactFiles"] = artifacts
    run_path.write_text(
        json.dumps(record, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"ledgered {len(artifacts)} artifacts in {run_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

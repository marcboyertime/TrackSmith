#!/usr/bin/env python3
"""Fail-closed local lane planner; required remote jobs intentionally still run."""
from __future__ import annotations
import argparse, json, os, subprocess, sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]

def changed(base: str, head: str) -> list[str]:
    result = subprocess.run(["git", "diff", "--name-status", "-M", f"{base}...{head}"], cwd=ROOT, capture_output=True, text=True)
    if result.returncode: raise ValueError("git diff failed")
    paths: list[str] = []
    for line in result.stdout.splitlines():
        fields = line.split("\t")
        if not fields or not fields[0] or fields[0][0] not in "ACDMR": raise ValueError("unknown diff status")
        paths.extend(fields[1:])
    return paths

def plan(paths: list[str], manifest: dict[str, Any], force_full: bool = False) -> dict[str, Any]:
    all_lanes = sorted(manifest["lanes"])
    if force_full or not paths: return {"mode": "full", "reason": "protected-context-or-empty-change-set", "required_lanes": all_lanes}
    shared = manifest["shared_prefixes"]
    if any(any(path.startswith(prefix) or path == prefix for prefix in shared) for path in paths):
        return {"mode": "full", "reason": "shared-or-ci-change", "required_lanes": all_lanes}
    matched = {lane for lane, prefixes in manifest["lanes"].items() if any(path.startswith(prefix) or path == prefix for path in paths for prefix in prefixes)}
    if not matched: return {"mode": "full", "reason": "unknown-change-path", "required_lanes": all_lanes}
    return {"mode": "targeted-local", "reason": "known-semantic-paths", "required_lanes": sorted(matched), "skipped_lanes": "local planner-authorized only; remote required jobs remain always-run"}

def local_commands(lane_ids: list[str]) -> list[str]:
    compute = json.loads((ROOT / "ci/tracksmith_compute_lanes.json").read_text())
    commands = {item["id"]: item["command"] for item in compute["lanes"] if item["id"] != "manual_heavy"}
    selected = list(dict.fromkeys(commands[lane] for lane in lane_ids))
    if any(not isinstance(command, str) or not command.startswith("bash scripts/ci/") or "<choice>" in command for command in selected):
        raise ValueError("planner lane command is not a bounded local entrypoint")
    return selected

def main() -> int:
    parser = argparse.ArgumentParser(); parser.add_argument("--base"); parser.add_argument("--head", default="HEAD"); parser.add_argument("--paths", nargs="*"); parser.add_argument("--context", choices=("local", "main", "manual", "merge"), default="local"); parser.add_argument("--emit-local-commands", action="store_true"); args = parser.parse_args()
    try:
        dependencies = json.loads((ROOT / "ci/semantic_dependencies.json").read_text())
        paths = args.paths if args.paths is not None else changed(args.base, args.head) if args.base else (_ for _ in ()).throw(ValueError("base is required"))
        result = plan(paths, dependencies, args.context != "local")
    except (OSError, ValueError, json.JSONDecodeError) as error:
        result = {"mode": "full", "reason": f"planner-error:{error}", "required_lanes": sorted(json.loads((ROOT / "ci/semantic_dependencies.json").read_text())["lanes"])}
    rendered = json.dumps(result, sort_keys=True)
    if args.emit_local_commands:
        try:
            print("\n".join(local_commands(result["required_lanes"])))
        except (OSError, ValueError, KeyError, TypeError) as error:
            print(f"planner command emission failed: {error}", file=sys.stderr); return 1
    else: print(rendered)
    if output := os.environ.get("GITHUB_OUTPUT"):
        with Path(output).open("a", encoding="utf-8") as handle:
            handle.write(f"mode={result['mode']}\nplan={rendered}\n")
    if summary := os.environ.get("GITHUB_STEP_SUMMARY"):
        Path(summary).open("a").write("## Advisory TrackSmith lane plan\n\n`" + rendered + "`\n")
    return 0

if __name__ == "__main__": raise SystemExit(main())

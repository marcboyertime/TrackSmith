#!/usr/bin/env python3
"""Fail-closed exhaustive aggregation of Tutor deterministic shard reports."""
from __future__ import annotations

import argparse
import json
import math
import sys
from collections.abc import Sequence
from pathlib import Path
from typing import Any

from shard_protocol import ALGORITHM, SCHEMA, digest, partition_hash, read_json

REQUIRED = {"schema_version", "suite_id", "suite_version", "suite_source_hash", "shard_index", "shard_count", "assignment_algorithm", "assignment_version", "partition_hash", "expected_ids", "executed_ids", "cases", "toolchain_identity", "toolchain_hash", "policy_hash", "index_hash"}


def aggregate(paths: list[Path], expected_ids: list[str] | None = None) -> dict[str, Any]:
    if not paths:
        raise ValueError("no shard reports supplied")
    if expected_ids is not None and (isinstance(expected_ids, (str, bytes)) or not isinstance(expected_ids, Sequence) or any(not isinstance(item, str) or not item for item in expected_ids) or len(expected_ids) != len(set(expected_ids))):
        raise ValueError("expected IDs must be a unique nonempty string sequence")
    reports = [read_json(path) for path in paths]
    for report in reports:
        missing = REQUIRED - set(report)
        if missing or report.get("schema_version") != SCHEMA:
            raise ValueError(f"corrupt shard report: missing {sorted(missing)} or unsupported schema")
        if report["assignment_algorithm"] != ALGORITHM:
            raise ValueError("changed or unsupported assignment algorithm")
        if type(report["shard_index"]) is not int or type(report["shard_count"]) is not int or report["shard_count"] < 1 or not 0 <= report["shard_index"] < report["shard_count"]:
            raise ValueError("invalid shard coordinates")
        if not all(isinstance(report[key], list) and len(report[key]) == len(set(report[key])) and all(isinstance(item, str) and item for item in report[key]) for key in ("expected_ids", "executed_ids")) or not isinstance(report["cases"], list):
            raise ValueError("corrupt shard report collection fields")
        case_ids = []
        for case in report["cases"]:
            if not isinstance(case, dict) or not isinstance(case.get("id"), str) or not case["id"]: raise ValueError("corrupt case object")
            case_ids.append(case["id"])
        if len(case_ids) != len(set(case_ids)) or set(case_ids) != set(report["expected_ids"]) or set(case_ids) != set(report["executed_ids"]):
            raise ValueError("per-report cases do not exactly match expected/executed IDs")
    first = reports[0]
    invariant = ("suite_id", "suite_version", "suite_source_hash", "shard_count", "assignment_algorithm", "assignment_version", "toolchain_identity", "toolchain_hash", "policy_hash", "index_hash")
    for report in reports[1:]:
        if any(report[key] != first[key] for key in invariant):
            raise ValueError("schema, suite, toolchain, policy, or index mismatch")
    count = first["shard_count"]
    indices = [report["shard_index"] for report in reports]
    if sorted(indices) != list(range(count)):
        raise ValueError("missing, duplicate, or unexpected shard coordinates")
    advertised = [item for report in reports for item in report["expected_ids"]]
    if len(advertised) != len(set(advertised)):
        raise ValueError("overlapping expected shard assignments")
    universe = sorted(expected_ids) if expected_ids is not None else sorted(advertised)
    if expected_ids is None and not universe:
        raise ValueError("empty inferred universe requires an explicit expected case list")
    if sorted(advertised) != universe:
        raise ValueError("missing or unexpected expected case IDs")
    by_id: dict[str, dict[str, Any]] = {}
    for report in reports:
        if report["partition_hash"] != partition_hash(sorted(report["expected_ids"])):
            raise ValueError("wrong partition hash")
        if sorted(report["executed_ids"]) != sorted(report["expected_ids"]):
            raise ValueError("missing, cancelled, or unexpected executed case")
        for case in report["cases"]:
            if not isinstance(case, dict) or not isinstance(case.get("id"), str) or case["id"] in by_id:
                raise ValueError("corrupt or duplicate case result")
            semantic, outcome, result_hash = case.get("semantic_input_hash"), case.get("outcome"), case.get("result_hash")
            duration = case.get("duration_seconds")
            if type(duration) not in (int, float) or not math.isfinite(duration) or duration < 0 or not isinstance(semantic, str) or outcome != "passed" or result_hash != digest(f"{case['id']}|passed|{semantic}"):
                raise ValueError("failed, cancelled, or corrupt case result")
            by_id[case["id"]] = case
    if sorted(by_id) != universe:
        raise ValueError("missing, duplicate, overlapping, or unexpected completed case")
    case_results = [{key: value for key, value in by_id[item].items() if key != "duration_seconds"} for item in universe]
    durations = {item: by_id[item]["duration_seconds"] for item in universe}
    merged = {"schema_version": "tracksmith-shard-aggregate/1", "suite_id": first["suite_id"], "suite_version": first["suite_version"], "suite_source_hash": first["suite_source_hash"], "assignment_algorithm": first["assignment_algorithm"], "assignment_version": first["assignment_version"], "case_ids": universe, "case_results": case_results, "policy_hash": first["policy_hash"], "index_hash": first["index_hash"], "toolchain_identity": first["toolchain_identity"], "toolchain_hash": first["toolchain_hash"], "partition_hash": partition_hash(universe), "observation": {"timings_are_observational": True, "case_durations_seconds": durations}}
    return merged


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("reports", nargs="+", type=Path)
    parser.add_argument("--expected", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    expected = json.loads(args.expected.read_text()) if args.expected else None
    try:
        result = aggregate(args.reports, expected)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"shard aggregation failed: {error}", file=sys.stderr); return 1
    rendered = json.dumps(result, sort_keys=True, separators=(",", ":")) + "\n"
    if args.output: args.output.write_text(rendered, encoding="utf-8")
    else: sys.stdout.write(rendered)
    return 0


if __name__ == "__main__": raise SystemExit(main())

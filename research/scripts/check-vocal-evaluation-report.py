#!/usr/bin/env python3
"""Fail closed on the stable Vocal v1 evaluator contract.

The historical report is a release record.  Current evaluator runs write a
temporary report whose execution provenance is intentionally volatile; all
semantic fields must still exactly match the historical report and current
corpus/failure-map bytes.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import pathlib
import re
import tempfile


def sha256(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path: pathlib.Path) -> dict:
    try:
        value = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"invalid JSON report: {path}") from error
    if not isinstance(value, dict):
        raise ValueError("report must be an object")
    return value


def validate_execution(execution: object) -> None:
    if not isinstance(execution, dict) or set(execution) != {
        "architecture", "claimBoundary", "command", "executableSHA256",
        "operatingSystem", "sourceRevision", "sourceTreeState", "toolchain",
    }:
        raise ValueError("volatile execution provenance schema mismatch")
    if not re.fullmatch(r"[0-9a-f]{40}|[0-9a-f]{64}", str(execution["sourceRevision"])):
        raise ValueError("volatile source revision is invalid")
    if execution["sourceTreeState"] not in {"clean", "dirty"}:
        raise ValueError("volatile source-tree state is invalid")
    if not re.fullmatch(r"[0-9a-f]{64}", str(execution["executableSHA256"])):
        raise ValueError("volatile executable hash is invalid")
    if not isinstance(execution["command"], list) or not execution["command"] or execution["command"][0] != "VocalProductionEvaluation":
        raise ValueError("volatile command provenance is invalid")
    for key in ("architecture", "claimBoundary", "operatingSystem", "toolchain"):
        if not isinstance(execution[key], str) or not execution[key].strip() or len(execution[key].encode()) > 512:
            raise ValueError(f"volatile execution field is invalid: {key}")


def validate_contract(report: dict, corpus: pathlib.Path, failure_map: pathlib.Path) -> None:
    required = {
        "schemaVersion", "corpusID", "corpusSHA256", "execution", "failed",
        "failureMapSHA256", "fixture", "passed", "schemaVersion", "statusDate",
        "total", "claimBoundary", "cases",
    }
    if set(report) != required or report["schemaVersion"] != "1.1":
        raise ValueError("report schema contract mismatch")
    if report["corpusSHA256"] != sha256(corpus) or report["failureMapSHA256"] != sha256(failure_map):
        raise ValueError("report corpus/failure-map hash mismatch")
    if (report["passed"], report["failed"], report["total"]) != (89, 0, 89):
        raise ValueError("report aggregate must remain 89/89")
    cases = report["cases"]
    if not isinstance(cases, list) or len(cases) != 89 or len({item.get("id") for item in cases if isinstance(item, dict)}) != 89:
        raise ValueError("report case contract mismatch")
    if not all(isinstance(item, dict) and item.get("passed") is True for item in cases):
        raise ValueError("report contains a failed or malformed case")
    validate_execution(report["execution"])


def semantic_projection(report: dict) -> dict:
    value = copy.deepcopy(report)
    value.pop("execution", None)
    return value


def check(actual_path: pathlib.Path, expected_path: pathlib.Path, corpus: pathlib.Path, failure_map: pathlib.Path) -> dict:
    actual = load(actual_path)
    expected = load(expected_path)
    validate_contract(actual, corpus, failure_map)
    validate_contract(expected, corpus, failure_map)
    if semantic_projection(actual) != semantic_projection(expected):
        raise ValueError("current evaluator semantic report drifted from the historical release record")
    return {"status": "pass", "aggregate": "89/89", "semantic_projection": "exact", "execution_provenance": "validated_separately"}


def self_test(expected_path: pathlib.Path, corpus: pathlib.Path, failure_map: pathlib.Path) -> dict:
    expected = load(expected_path)
    with tempfile.TemporaryDirectory(prefix="tracksmith-vocal-report-") as directory:
        actual_path = pathlib.Path(directory) / "actual.json"
        actual = copy.deepcopy(expected)
        actual["execution"]["sourceRevision"] = "a" * 40
        actual["execution"]["sourceTreeState"] = "dirty"
        actual["execution"]["executableSHA256"] = "b" * 64
        actual["execution"]["claimBoundary"] = "The evaluator ran from a dirty working tree."
        actual_path.write_text(json.dumps(actual, sort_keys=True))
        check(actual_path, expected_path, corpus, failure_map)
        actual["passed"] = 88
        actual_path.write_text(json.dumps(actual, sort_keys=True))
        try:
            check(actual_path, expected_path, corpus, failure_map)
        except ValueError:
            pass
        else:
            raise AssertionError("aggregate drift was accepted")
        actual = copy.deepcopy(expected)
        actual["cases"][0]["passed"] = False
        actual_path.write_text(json.dumps(actual, sort_keys=True))
        try:
            check(actual_path, expected_path, corpus, failure_map)
        except ValueError:
            pass
        else:
            raise AssertionError("semantic drift was accepted")
    return {"status": "pass", "cases": ["volatile_execution_ignored", "aggregate_drift_rejected", "semantic_drift_rejected"]}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--actual", type=pathlib.Path)
    parser.add_argument("--expected", type=pathlib.Path, required=True)
    parser.add_argument("--corpus", type=pathlib.Path, required=True)
    parser.add_argument("--failure-map", type=pathlib.Path, required=True)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        if args.actual:
            parser.error("--self-test does not accept --actual")
        result = self_test(args.expected, args.corpus, args.failure_map)
    else:
        if not args.actual:
            parser.error("--actual is required unless --self-test is used")
        result = check(args.actual, args.expected, args.corpus, args.failure_map)
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()

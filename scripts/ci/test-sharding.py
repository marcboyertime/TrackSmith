#!/usr/bin/env python3
from __future__ import annotations
import copy, json, tempfile
from pathlib import Path
from aggregate_shards import aggregate
from shard_protocol import ALGORITHM, FALLBACK, SCHEMA, assign, digest, partition_hash

def report(index: int, count: int, cases: list[str]) -> dict:
    values = [{"id": item, "semantic_input_hash": digest(item), "outcome": "passed", "duration_seconds": 1, "result_hash": digest(f"{item}|passed|{digest(item)}")} for item in cases]
    return {"schema_version": SCHEMA, "suite_id": "suite", "suite_version": "1", "suite_source_hash": "source", "shard_index": index, "shard_count": count, "assignment_algorithm": ALGORITHM, "assignment_version": "1", "partition_hash": partition_hash(cases), "expected_ids": cases, "executed_ids": cases, "cases": values, "toolchain_identity": "test-toolchain", "toolchain_hash": "tool", "policy_hash": "policy", "index_hash": "index"}

def rejects(values: list[dict], label: str) -> None:
    with tempfile.TemporaryDirectory() as directory:
        paths = []
        for index, value in enumerate(values):
            path = Path(directory) / f"{index}.json"; path.write_text(json.dumps(value)); paths.append(path)
        try: aggregate(paths)
        except ValueError: return
    raise AssertionError(label)

def main() -> None:
    case_ids = ["a", "b", "c", "d", "e"]
    bins, algorithm = assign(case_ids, 3, {item: index + 1 for index, item in enumerate(case_ids)})
    assert algorithm == ALGORITHM and sorted(item for bucket in bins for item in bucket) == case_ids
    equal_bins, _ = assign(["case-b", "case-a", "case-c"], 2, {"case-a": 1, "case-b": 1, "case-c": 1})
    assert equal_bins == [["case-a", "case-c"], ["case-b"]]
    swift = (Path(__file__).resolve().parents[2] / "tools/TutorConversationTests/Sources/TutorConversationTests/TutorConversationTests.swift").read_text()
    assert "costs[$0.id]! == costs[$1.id]! ? $0.id < $1.id" in swift
    reports = [report(index, 3, cases) for index, cases in enumerate(bins)]
    assert aggregate([write_temp(item, index) for index, item in enumerate(reports)], case_ids)["case_ids"] == case_ids
    rejects(reports[:-1], "missing shard accepted")
    duplicate = copy.deepcopy(reports); duplicate[1]["shard_index"] = 0; rejects(duplicate, "duplicate shard accepted")
    overlap = copy.deepcopy(reports); overlap[1]["expected_ids"].append(overlap[0]["expected_ids"][0]); overlap[1]["executed_ids"].append(overlap[0]["expected_ids"][0]); rejects(overlap, "overlap accepted")
    corrupt = copy.deepcopy(reports); corrupt[0]["cases"][0]["result_hash"] = "bad"; rejects(corrupt, "corrupt accepted")
    failed = copy.deepcopy(reports); failed[0]["cases"][0]["outcome"] = "failed"; rejects(failed, "failure accepted")
    changed = copy.deepcopy(reports); changed[0]["assignment_algorithm"] = "future"; rejects(changed, "algorithm change accepted")
    rejects([report(0, 1, [])], "inferred empty universe accepted")
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "empty.json"; path.write_text(json.dumps(report(0, 1, [])))
        assert aggregate([path], [])["case_ids"] == []
    empty, fallback = assign([], 8); assert fallback == FALLBACK and len(empty) == 8
    print("test-sharding: cross-language LPT tie golden plus missing/duplicate/overlap/corrupt/empty/more-shards/failure/algorithm cases passed")

_TEMPS: list[tempfile.TemporaryDirectory] = []
def write_temp(value: dict, index: int) -> Path:
    temp = tempfile.TemporaryDirectory(); _TEMPS.append(temp); path = Path(temp.name) / f"{index}.json"; path.write_text(json.dumps(value)); return path
if __name__ == "__main__": main()
